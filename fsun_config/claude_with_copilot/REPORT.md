# Report: Claude Code CLI → GitHub Copilot (verified working)

Date: 2026-06-17 · Verified in an Ubuntu 24.04 (aarch64) VM against a personal
GitHub Copilot Pro+ account (`eliteGoblin`).

## TL;DR — the working combination

| Piece | Value |
|------|-------|
| Claude CLI | **npm `@anthropic-ai/claude-code@2.1.112`** — the **last Node/JS** version |
| Why 2.1.112 | `2.1.113+` ship a **native glibc binary** (`bin/claude.exe`), not JS. If you can't run native binaries, 2.1.112 is the ceiling. |
| Endpoint | `ANTHROPIC_BASE_URL = https://api.githubcopilot.com` |
| Auth | `ANTHROPIC_AUTH_TOKEN = <GitHub Copilot token>` (device-login, long-lived) |
| Sonnet (main) | `claude-sonnet-4.5` — verified (`Paris`) |
| Opus | `claude-opus-4.7` — verified (`42`) — **requires thinking OFF** |
| Thinking | set `alwaysThinkingEnabled: false` (or `/config` → thinking off) — else opus 400s on `thinking.type.enabled` |

## Root cause of "it broke today, config unchanged"

Nothing in the config changed. **Two independent, external things did:**

1. **GitHub changed the per-integrator model allow-list.** Claude Code talks to
   Copilot under a fixed `Copilot-Integration-Id` (`copilot-language-server` for
   the CLI). Copilot gates *which models that integrator may call*, and the list
   **changes server-side**. The pinned `claude-sonnet-4-6` dropped out → `400
   model_not_available_for_integrator`. (It has since reappeared — the list is
   volatile, so pinning one exact id is fragile. `claude-sonnet-4.5` has been the
   stable choice across all tests.)
2. **(If using a corporate token) enterprise IP allow list.** A token tied to an
   enterprise (e.g. `macquarie`) returns `403 ... IP allow list` from any
   non-allow-listed IP. The fix here was to use the **personal** Copilot token,
   not the corporate one.

## Key facts established (all empirical)

- **Token works directly** — Copilot accepts the GitHub token as the bearer; no
  `copilot_internal/v1/token` exchange is needed (that endpoint 404s and is
  irrelevant to Claude Code).
- **`Copilot-Integration-Id` matters but is NOT settable from config** — Claude
  Code hardcodes it per version and ignores `ANTHROPIC_CUSTOM_HEADERS` for it.
  So **model choice is the only lever**, and working ids differ by CLI version.
- **Model availability is version-specific AND time-varying** — the only
  reliable way to know what works is to **probe the actual `claude` binary**
  (`claude --model X -p ...`), not curl with assumed headers (which lied:
  it reported ids "OK" that the real CLI rejected).
- **npm switched to a native binary at exactly 2.1.113** (confirmed via the npm
  `bin` field: `2.1.112 = cli.js`, `2.1.113 = bin/claude.exe`, and the ELF file
  type of the installed artifact). Corroborated by GitHub issue #50974.

## Verified model matrix (snapshot — re-probe, it drifts)

`claude 2.1.112` (Node) on integrator `copilot-language-server`:

| Model id | Result |
|----------|--------|
| `claude-sonnet-4.5` | WORKS (recommended main) |
| `claude-sonnet-4-5` | WORKS |
| `claude-sonnet-4-6` | now (was failing — volatile, don't rely on it) |
| `claude-opus-4.7` | WORKS with thinking OFF |
| `claude-opus-4.5`, `claude-opus-4.8`, `claude-sonnet-4.6` | not available |

## The settings.json (drop into `~/.claude/settings.json`)

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.githubcopilot.com",
    "ANTHROPIC_AUTH_TOKEN": "<your gho_/ghu_ Copilot token>",
    "ANTHROPIC_MODEL": "claude-sonnet-4.5",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4.5",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4.7",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4-5",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "64000"
  },
  "model": "claude-sonnet-4.5",
  "alwaysThinkingEnabled": false
}
```

## Install the Node CLI

```bash
npm install -g @anthropic-ai/claude-code@2.1.112   # last JS/Node version
claude --version    # 2.1.112 (Claude Code)
```

Get the token: `myclaude copilot login` (device flow → long-lived token).

## Caveat from the test environment

The VM clock was ~18 days behind, which made TLS certs read "not yet valid"; I
used a transient `NODE_TLS_REJECT_UNAUTHORIZED=0` **only** to work around that —
it is **not** in the settings.json and is **not** needed on a correctly-clocked
machine. Fix the VM clock (`sudo timedatectl set-ntp true`) for a clean setup.

## Is Claude Code open source? (No.)

Being on npm ≠ open source. The `2.1.112` `cli.js` was a **minified/bundled**
artifact, not readable source; `2.1.113+` ship a closed **native binary**. There
is no published source to build, and no supported way to get newer versions as a
runnable Node package. **2.1.112 is the ceiling for the Node-package requirement.**
