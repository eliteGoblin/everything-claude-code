# Further Thoughts (backlog)

Parked ideas. Not committed work.

## Post-sync agent-model patch

**Problem:** upstream hardcodes `model:` in agent frontmatter (reviewers → `sonnet`,
`doc-updater` → `haiku`, only architect/planner/etc → `opus`). `myclaude sync`
copies these over `~/.claude/agents/`, so any local Opus upgrade reverts.

**Idea:** a patch step that re-applies preferred models *after* sync.
- Sequence: `sync` first → confirm clean (no conflict) → then apply patch.
- Scope: all-Opus (or a named selective set) over the synced defaults.
- Wire as a post-sync step in `fsun_config` so it survives upstream merges.
- Built-in `myclaude agents --opus` already does all-Opus manually; the patch
  just makes it automatic + (optionally) selective.

**Status:** deferred. Apply when ready, not now.

## Multi-angle review recipe

One-trigger parallel review: `architect` + `code-reviewer` + `security-reviewer`
(all Opus) on a PR. Different *roles* > different *models* for diverse angles;
cross-vendor (GPT/Gemini adapters) only if a truly independent second opinion is
wanted. Status: idea only.
