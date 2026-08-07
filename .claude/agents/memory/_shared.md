# _shared memory — everything-claude-code (Frank's fork)

## PR/merge mechanics on this fork (proven 2026-07-23/24, PR #23)
- Copilot review WORKS here but never appears in reviewRequests — request it,
  then poll `pulls/<n>/reviews` for user `copilot-pull-request-reviewer[bot]`
  (posted ~30+ min later). Branch protection requires ALL review threads
  resolved (GraphQL resolveReviewThread; a reply alone is not enough) and green
  checks; npm audit + windows hooks-test failures are PRE-EXISTING → merge
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

## ecc.js sync is not a mirror — it only adds and overwrites (proven 2026-08-07, PR #27)
- `sync()` never deletes a destination it no longer tracks, and `unpick()` only
  filters `manifest.upstream` — there is NO unpick equivalent for `custom[]`.
  Removing an entry from `manifest.custom` therefore leaves the installed copy at
  `~/.claude/` forever: the karpathy-guidelines skill stayed live for two months
  after `f3b9d139` de-registered it. Delete the install by hand after any removal.
- Custom entries also bypass `manifest.hashes` (only the upstream loop writes it),
  so `ecc.js diff` gives ZERO drift detection for custom files. A hand-edit of an
  installed custom rule will never be reported.

## ~/.claude can be ahead of main — check before trusting either (proven 2026-08-07)
- Rules that live only on an unmerged branch stay installed and look authoritative,
  then get silently REVERTED the next time `sync` runs from a main checkout.
  Two live cases: `production-safety.md` was installed since 2026-05-20 but its only
  commit sat on `feat/production-safety-guardrail` (never on main); the stronger
  delegation wording was installed until a sync from main overwrote it with the
  weaker text (PR #25 still open).
- Before concluding "this rule says X", check BOTH: `diff ~/.claude/rules/... <repo copy>`
  and `git log --all --oneline -S "<distinctive phrase>" -- fsun_config/`. The system
  context loaded at session start can be a third, different version again.

## sessions registry race
- ~/.claude/session-registry.json is read-modify-write with no locking;
  a concurrent session's sync clobbered a freshly created alias (2026-07-23).
  After creating aliases/assignments, re-verify them if another session is
  live; hardening tracked in fsun_config/requirements icebox.
