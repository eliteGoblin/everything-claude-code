# research / citation-verifier memory — everything-claude-code (Frank's fork)

Repo-specific lessons for research and verification work in this repo. Cross-project research
method lessons go to `fsun_config/custom/skills/deep-research/LESSONS.md` instead.

## Repo-state claims: check HEAD, not the evidence note (2026-08-23, config-base verification)
- Branch reports measured "untracked / drifted / exists" against an older checkout or the
  upstream merge-base (4130457d). On HEAD, `rules/frank/production-safety.md`,
  `agents/citation-verifier.md` and `skills/deep-research/*` were already in `manifest.custom`
  (PRs #26/#27), `custom/skills/karpathy-guidelines` was already deleted (3c1ca7a9), and the
  installed `transcript-context.js` was byte-identical to HEAD and origin/main.
- Rule: for any "is tracked / is installed / has drifted" claim run `grep <path>
  fsun_config/manifest.json`, `cmp ~/.claude/<path> <(git show HEAD:<path>)`, and
  `git merge-base --is-ancestor <commit> HEAD` before accepting it.

## Transcript usage counts need two markers (2026-08-23)
- Slash-command use appears as `<command-name>/x</command-name>` AND as the `Skill` tool
  (`"name":"Skill","input":{"skill":"x"`). `/sessions` = 37 + 11 = 48; counting one marker
  under-reports. Subagent use = `"subagent_type":"<name>"`. Corpus lives in
  `~/.claude/projects/**/*.jsonl`; counts grow daily, so stamp them with the date.
- `file_path` extension counts over the JSONL double-count (tool_use + echo); de-duplicate per
  tool call before quoting magnitudes. Direction (py ≫ ts/js, no go/tsx) is stable either way.

## Measuring the always-on set (2026-08-23)
- Programme-start set = `~/.claude/rules/{common,frank}/*.md` + `~/.claude/CLAUDE.md` + project
  `CLAUDE.md` + `.claude/rules/*.md` (60,273 B / 1,374 lines reproduce exactly). The removed
  `rules/common/session-log.md` is not in `rules/common/` of the repo; it lives in
  `fsun_config/custom/rules/common/` (a worktree copy survives under `.claude/worktrees/`).
- Emphasis-word counts only reproduce case-insensitively (72–74); upper-case-only gives 14–20.
  State the regex with the number.
- zsh does not word-split `$VAR` file lists: `cat $F` with a space-separated string fails with
  "No such file". Use an array (`F=( ... ); cat "${F[@]}"`).
