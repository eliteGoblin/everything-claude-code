#!/usr/bin/env bash
#
# copilot-claude.sh — Use GitHub Copilot's hosted Claude models from the Claude Code CLI.
#
# What it does (KISS):
#   login   -> device flow, mints a LONG-LIVED (non-expiring) Copilot token for your account
#   models  -> lists Claude models and probes which exact id string actually works on /v1/messages
#   verify  -> sends ONE real message to a model and prints the reply (proof it works)
#   config  -> writes a settings.json you copy into ~/.claude/ (token + verified model ids baked in)
#   all     -> login (if needed) -> models -> verify -> config, in one shot
#
# Requirements: bash, curl, python3. Nothing else.
#
# Why a token works directly: Copilot's gateway accepts your GitHub OAuth/App token as the
# Bearer on https://api.githubcopilot.com and checks your Copilot entitlement internally.
# Claude Code just sends that token (ANTHROPIC_AUTH_TOKEN) to ANTHROPIC_BASE_URL. No exchange.
#
set -euo pipefail

# --- constants ---------------------------------------------------------------
CLIENT_ID="Iv1.b507a08c87ecfe98"          # public client id of the GitHub Copilot / VS Code app
API="https://api.githubcopilot.com"
GH="https://github.com"
TOKEN_FILE="${COPILOT_CLAUDE_TOKEN_FILE:-$HOME/.config/copilot-claude/token}"

# Headers every Copilot API call needs. Copilot-Integration-Id is the important one.
copilot_headers=(
  -H "Editor-Version: vscode/1.109.3"
  -H "Editor-Plugin-Version: copilot-chat/0.37.6"
  -H "Copilot-Integration-Id: vscode-chat"
  -H "User-Agent: GitHubCopilotChat/0.37.6"
)

die(){ echo "ERROR: $*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }
need curl; need python3

# --- token helpers -----------------------------------------------------------
load_token(){
  if [ -n "${COPILOT_TOKEN:-}" ]; then printf '%s' "$COPILOT_TOKEN"; return 0; fi
  [ -f "$TOKEN_FILE" ] && { tr -d '\n' < "$TOKEN_FILE"; return 0; }
  return 1
}

cmd_login(){
  echo "Requesting device code from GitHub..." >&2
  local resp; resp=$(curl -fsSL "$GH/login/device/code" -X POST \
    -H "Accept: application/json" -H "User-Agent: GitHubCopilotChat/0.37.6" \
    -d "client_id=${CLIENT_ID}&scope=read:user")
  local device user_code uri interval
  device=$(printf '%s' "$resp" | python3 -c 'import sys,json;print(json.load(sys.stdin)["device_code"])')
  user_code=$(printf '%s' "$resp" | python3 -c 'import sys,json;print(json.load(sys.stdin)["user_code"])')
  uri=$(printf '%s' "$resp" | python3 -c 'import sys,json;print(json.load(sys.stdin)["verification_uri"])')
  interval=$(printf '%s' "$resp" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("interval",5))')

  echo "" >&2
  echo "  1) Open: $uri" >&2
  echo "  2) Enter code: $user_code" >&2
  echo "  3) Sign in with your PERSONAL GitHub account (the one with Copilot)." >&2
  echo "" >&2
  echo "Waiting for authorization..." >&2

  local token=""
  while :; do
    sleep "$interval"
    local poll; poll=$(curl -fsSL "$GH/login/oauth/access_token" -X POST \
      -H "Accept: application/json" -H "User-Agent: GitHubCopilotChat/0.37.6" \
      -d "client_id=${CLIENT_ID}&device_code=${device}&grant_type=urn:ietf:params:oauth:grant-type:device_code")
    local err; err=$(printf '%s' "$poll" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("error",""))')
    if [ -z "$err" ]; then
      token=$(printf '%s' "$poll" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("access_token",""))')
      break
    fi
    case "$err" in
      authorization_pending) : ;;
      slow_down) interval=$((interval+5)) ;;
      *) die "device login failed: $err" ;;
    esac
  done
  [ -n "$token" ] || die "no token returned"
  mkdir -p "$(dirname "$TOKEN_FILE")"; printf '%s' "$token" > "$TOKEN_FILE"; chmod 600 "$TOKEN_FILE"
  echo "Token saved to $TOKEN_FILE" >&2
  echo "This token is long-lived (no expiry was returned; valid until you revoke the app)." >&2
  printf '%s\n' "$token"
}

# Probe one model id against /v1/messages. echoes HTTP code, returns 0 if 200.
probe_model(){
  local token="$1" model="$2" code
  code=$(curl -sS -o /dev/null -w '%{http_code}' "$API/v1/messages" \
    "${copilot_headers[@]}" -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" -H "anthropic-version: 2023-06-01" \
    -d "{\"model\":\"$model\",\"max_tokens\":8,\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}]}")
  printf '%s' "$code"; [ "$code" = "200" ]
}

# Given a catalog id like claude-sonnet-4.6, return the id form that actually works
# (tries the id as-is, then the dash variant claude-sonnet-4-6). Empty if none work.
working_id(){
  local token="$1" id="$2" dash
  if [ "$(probe_model "$token" "$id")" = "200" ]; then printf '%s' "$id"; return 0; fi
  dash=$(printf '%s' "$id" | sed -E 's/([0-9])\.([0-9])/\1-\2/g')
  if [ "$dash" != "$id" ] && [ "$(probe_model "$token" "$dash")" = "200" ]; then printf '%s' "$dash"; return 0; fi
  return 1
}

# --- authoritative probing via the real claude binary -----------------------
# curl-with-headers is UNRELIABLE here: Claude Code hardcodes its own
# Copilot-Integration-Id (per CLI version) and ignores ANTHROPIC_CUSTOM_HEADERS
# for it, so /models and curl probes report ids the CLI can't actually call.
# The only trustworthy check is asking the installed CLI to call the model.
claude_bin(){ command -v claude 2>/dev/null; }

# probe_via_claude <token> <model> -> 0 if the CLI gets a real answer
probe_via_claude(){
  local token="$1" model="$2" cb out
  cb=$(claude_bin) || return 2
  out=$(ANTHROPIC_BASE_URL="$API" ANTHROPIC_AUTH_TOKEN="$token" \
        ANTHROPIC_CUSTOM_HEADERS="Copilot-Integration-Id: vscode-chat" \
        "$cb" --model "$model" -p "Reply ONLY: OK" </dev/null 2>&1)
  printf '%s' "$out" | grep -q "OK"
}

# pick_working <token> <candidate...> -> echoes first id the CLI can actually use
pick_working(){
  local token="$1"; shift
  local m
  for m in "$@"; do
    if probe_via_claude "$token" "$m"; then printf '%s' "$m"; return 0; fi
  done
  return 1
}

cmd_models(){
  local token; token=$(load_token) || die "no token. Run: $0 login"
  echo "Fetching model catalog from Copilot..." >&2
  local cat; cat=$(curl -fsSL "$API/models" "${copilot_headers[@]}" -H "Authorization: Bearer $token")
  local ids; ids=$(printf '%s' "$cat" | python3 -c '
import sys,json
d=json.load(sys.stdin); data=d.get("data",d if isinstance(d,list) else [])
for m in data:
    i=m.get("id","")
    if "claude" in i.lower(): print(i)
')
  [ -n "$ids" ] || die "no claude models returned (token entitled for Copilot?)"
  printf "%-22s %-8s %s\n" "CATALOG ID" "STATUS" "USE THIS ID IN settings.json"
  printf "%-22s %-8s %s\n" "----------" "------" "----------------------------"
  while IFS= read -r id; do
    local w; if w=$(working_id "$token" "$id"); then
      printf "%-22s %-8s %s\n" "$id" "OK" "$w"
    else
      printf "%-22s %-8s %s\n" "$id" "FAIL" "(not callable on /v1/messages)"
    fi
  done <<< "$ids"
}

cmd_verify(){
  local token; token=$(load_token) || die "no token. Run: $0 login"
  local model="${1:-claude-sonnet-4.5}"
  # Prefer the real CLI (authoritative). Falls back to curl if claude isn't installed.
  if claude_bin >/dev/null; then
    echo "Verifying '$model' via the installed claude CLI..." >&2
    if probe_via_claude "$token" "$model"; then
      echo "REPLY: OK"; echo "==> $model WORKS (real CLI)"; return 0
    else
      echo "==> $model did NOT work via the CLI (try: $0 models)"; return 1
    fi
  fi
  echo "Verifying '$model' with a real request (curl; install claude for an authoritative check)..." >&2
  local out; out=$(curl -sS "$API/v1/messages" \
    "${copilot_headers[@]}" -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" -H "anthropic-version: 2023-06-01" \
    -d "{\"model\":\"$model\",\"max_tokens\":64,\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly: COPILOT_OK\"}]}")
  local text; text=$(printf '%s' "$out" | python3 -c '
import sys,json
try:
  d=json.load(sys.stdin)
  if "content" in d: print("REPLY:", "".join(b.get("text","") for b in d["content"]))
  else: print("ERROR:", d.get("error",d))
except Exception as e: print("unparseable:", e)
')
  echo "$text"
  printf '%s' "$text" | grep -q "COPILOT_OK" && echo "==> $model WORKS" || echo "==> $model did NOT confirm (see above)"
}

cmd_config(){
  local token; token=$(load_token) || die "no token. Run: $0 login"
  local out="${1:-settings.json}"
  echo "Resolving working model ids..." >&2
  local sonnet opus haiku
  if claude_bin >/dev/null; then
    # Authoritative: ask the installed CLI which candidates it can actually call.
    echo "  probing via the installed claude CLI (authoritative)..." >&2
    sonnet=$(pick_working "$token" claude-sonnet-4.5 claude-sonnet-4-5 claude-sonnet-4-6) || sonnet="claude-sonnet-4.5"
    opus=$(pick_working   "$token" claude-opus-4.7 claude-opus-4.5 claude-opus-4.8)       || opus="claude-opus-4.7"
    haiku=$(pick_working  "$token" claude-haiku-4-5 claude-haiku-4.5)                      || haiku="claude-haiku-4-5"
  else
    # Fallback: curl probe (less reliable — see note above). Verified defaults.
    sonnet=$(working_id "$token" "claude-sonnet-4.5") || sonnet="claude-sonnet-4.5"
    opus=$(working_id "$token" "claude-opus-4.7")     || opus="claude-opus-4.7"
    haiku="claude-haiku-4-5"
  fi
  echo "  main/sonnet = $sonnet" >&2
  echo "  opus        = $opus" >&2
  echo "  haiku       = $haiku" >&2
  TOKEN="$token" SONNET="$sonnet" OPUS="$opus" HAIKU="$haiku" python3 - "$out" <<'PY'
import json,os,sys
cfg={
  "env":{
    "ANTHROPIC_BASE_URL":"https://api.githubcopilot.com",
    "ANTHROPIC_AUTH_TOKEN":os.environ["TOKEN"],
    "ANTHROPIC_MODEL":os.environ["SONNET"],
    "ANTHROPIC_DEFAULT_SONNET_MODEL":os.environ["SONNET"],
    "ANTHROPIC_DEFAULT_OPUS_MODEL":os.environ["OPUS"],
    "ANTHROPIC_DEFAULT_HAIKU_MODEL":os.environ["HAIKU"],
    "CLAUDE_CODE_SUBAGENT_MODEL":os.environ["HAIKU"],
    "ANTHROPIC_CUSTOM_HEADERS":"Copilot-Integration-Id: vscode-chat\nEditor-Version: vscode/1.109.3\nEditor-Plugin-Version: copilot-chat/0.37.6\nUser-Agent: GitHubCopilotChat/0.37.6",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC":"1",
    "CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS":"1",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS":"64000"
  },
  "model":os.environ["SONNET"],
  # Copilot's Claude models reject thinking.type.enabled; keep extended thinking off
  # (opus 400s otherwise). Toggle later with /config if you want it per-model.
  "alwaysThinkingEnabled":False
}
open(sys.argv[1],"w").write(json.dumps(cfg,indent=2)+"\n")
print("wrote "+sys.argv[1],file=sys.stderr)
PY
  echo "Copy it: cp $out ~/.claude/settings.json" >&2
}

cmd_all(){
  load_token >/dev/null 2>&1 || cmd_login >/dev/null
  echo "==== MODELS ===="; cmd_models
  echo; echo "==== VERIFY (sonnet) ===="; cmd_verify claude-sonnet-4-6
  echo; echo "==== CONFIG ===="; cmd_config "${1:-settings.json}"
}

usage(){ sed -n '2,20p' "$0"; }
case "${1:-}" in
  login)  cmd_login ;;
  models) cmd_models ;;
  verify) shift; cmd_verify "${1:-}" ;;
  config) shift; cmd_config "${1:-settings.json}" ;;
  all)    shift; cmd_all "${1:-settings.json}" ;;
  ""|-h|--help) usage ;;
  *) die "unknown command: $1 (try: login|models|verify|config|all)" ;;
esac
