# Claude Code → GitHub Copilot

Use **GitHub Copilot's hosted Claude models** (Sonnet / Opus / Haiku) from the
`claude` CLI, billed against your **Copilot** seat instead of an Anthropic API key.

KISS. One script, one `myclaude` subcommand, one `settings.json`.

## How it works (the whole trick)

Claude Code talks to whatever `ANTHROPIC_BASE_URL` points at, using
`ANTHROPIC_AUTH_TOKEN` as the bearer. Point it at Copilot:

```
ANTHROPIC_BASE_URL = https://api.githubcopilot.com
ANTHROPIC_AUTH_TOKEN = <your GitHub Copilot token>
```

Copilot's gateway accepts your GitHub token **directly** and checks your Copilot
entitlement internally — there is **no token-exchange step**. Claude Code's
requests to `/v1/messages` are served by Copilot's Claude models.

Two extra requirements:

1. **Headers** — Copilot needs `Copilot-Integration-Id: vscode-chat` (+ editor
   headers). These go in `ANTHROPIC_CUSTOM_HEADERS`.
2. **Model ids** — Copilot's `/v1/messages` is picky and **not** consistent
   between dot and dash forms. e.g. `claude-sonnet-4-6` works but
   `claude-sonnet-4.6` returns 400. **Never guess — verify** (the script does).

## Get a token (long-lived)

```bash
myclaude copilot login
```

Runs the GitHub **device flow**: open the URL, type the code, sign in with the
personal account that has Copilot. The minted token is **non-expiring** (GitHub
returns no expiry for the Copilot app) — it lives until you revoke it. Saved to
`~/.config/copilot-claude/token`.

> Requirement: the account you log in with must have an active **Copilot**
> subscription (Pro/Pro+/Business). No subscription → the API returns 404 and no
> config can fake it. An account inside an **enterprise with an IP allow list**
> (e.g. a corporate org) will get **403** unless you're on an allow-listed network.

## See which models actually work

```bash
myclaude copilot models
```

Lists the Claude catalog and **probes each** against `/v1/messages`, printing the
exact id string to put in `settings.json`:

```
CATALOG ID             STATUS   USE THIS ID IN settings.json
claude-sonnet-4.6      OK       claude-sonnet-4-6
claude-opus-4.8        OK       claude-opus-4.8
claude-haiku-4.5       OK       claude-haiku-4.5
```

## Prove a model works

```bash
myclaude copilot verify claude-sonnet-4-6
# → REPLY: COPILOT_OK   ==> claude-sonnet-4-6 WORKS
```

## Generate the config

```bash
myclaude copilot config ./settings.json     # write a file you can inspect/copy
myclaude copilot install                     # write straight to ~/.claude/settings.json (backs up)
```

`config` bakes in your token + the **verified** model ids. Then:

```bash
cp ./settings.json ~/.claude/settings.json   # if you used `config`
claude -p "say hello"                         # now served by Copilot
```

## One-shot

```bash
myclaude copilot all      # login (if needed) → models → verify → config
```

## Model / cost notes

| Role | Recommended id | Notes |
|------|----------------|-------|
| Sonnet (main) | `claude-sonnet-4-6` | daily driver, best cost/quality |
| Opus (premium) | `claude-opus-4.8` | latest; **expensive** — drains Copilot credits fastest |
| Haiku (subagents) | `claude-haiku-4.5` | cheapest; good for `CLAUDE_CODE_SUBAGENT_MODEL` |

Keep Sonnet as `ANTHROPIC_MODEL`; reach for Opus only when needed.

## Files

- `copilot-claude.sh` — the implementation (bash + curl + python3; no deps to install)
- `README.md` — this file

`myclaude copilot …` just delegates to `copilot-claude.sh`, so everything stays
reachable from the one `myclaude` entrypoint.

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `400 model not available` | wrong id form (dot vs dash) | run `myclaude copilot models`, use the **USE THIS ID** column |
| `401 Bad credentials` | token invalid / revoked | `myclaude copilot login` again |
| `403 ... enterprise has an IP allow list` | account is in a corp enterprise | use the allow-listed network/VPN, or a personal Copilot account |
| `404 Not Found` on token exchange | account has no Copilot seat | subscribe to Copilot, or log in with the account that has it |
| malformed JSON / `invalid bearer token` | a value wrapped onto a second line in settings.json (a raw newline inside a `"..."` string) | keep every value on ONE line. The generated config omits `ANTHROPIC_CUSTOM_HEADERS` (the Node CLI ignores it anyway) precisely to avoid this footgun |
