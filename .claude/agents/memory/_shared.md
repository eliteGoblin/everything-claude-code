# _shared memory — everything-claude-code (Frank's fork)

## PR/merge mechanics on this fork (proven 2026-07-23/24, PR #23)
- Copilot review WORKS here but never appears in reviewRequests — request it,
  then poll `pulls/<n>/reviews` for user `copilot-pull-request-reviewer[bot]`
  (posted ~30+ min later). Branch protection requires ALL review threads
  resolved (GraphQL resolveReviewThread; a reply alone is not enough) and green
  checks; npm-audit + windows hooks-test failures are PRE-EXISTING → merge
  needs `--admin` (get Frank's explicit ok).
- gh has two accounts: corp ZSun1_CCgroup (active default) and eliteGoblin
  (fork owner). `gh auth switch --user eliteGoblin` before push/PR/merge on the
  fork; ALWAYS switch back to ZSun1_CCgroup immediately after.
- The shared checkout at ~/devel/everything-claude-code accumulates UNPUSHED
  main commits from other sessions. A branch cut from local main then PRed
  against origin/main carries those commits into the PR diff (and a squash
  merge misattributes them). Before branching: check `git log origin/main..main`
  and cut from origin/main (worktree) unless you intend to ship the backlog.
- `node fsun_config/ecc.js sync` works fine from a worktree of origin/main —
  use that to deploy to ~/.claude without touching the dirty shared checkout.

## sessions registry race
- ~/.claude/session-registry.json is read-modify-write with no locking;
  a concurrent session's sync clobbered a freshly created alias (2026-07-23).
  After creating aliases/assignments, re-verify them if another session is
  live; hardening tracked in fsun_config/requirements icebox.
