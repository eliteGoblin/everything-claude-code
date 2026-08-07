# _shared memory — everything-claude-code (Frank's fork)

## PR/merge mechanics on this fork (proven 2026-07-23/24, PR #23)
- Copilot review WORKS here but never appears in reviewRequests — request it,
  then poll `pulls/<n>/reviews` for user `copilot-pull-request-reviewer[bot]`
  (latency varies: ~3 min on PR #25, ~30+ min on PR #23 — poll, don't assume
  either). Branch protection requires ALL review threads
  resolved (GraphQL resolveReviewThread; a reply alone is not enough) and green
  checks; npm audit + windows hooks-test failures are PRE-EXISTING → merge
  needs `--admin` (get Frank's explicit ok).
- Branch protection on main (verified 2026-08-07 via `branches/main/protection`):
  the ONLY required check is **`fsun-ci`**. `Security Scan` and the ~34-job
  `Test (os, node, pm)` matrix are NOT required — a red Security Scan is
  pre-existing (fails on `main` itself, e.g. `fecab0b0`) and must not be treated
  as a blocker. `strict: true` → every PR must be up to date with main, so a
  queue of PRs needs a merge/rebase of main into each one in turn.
- gh has two accounts: corp ZSun1_CCgroup (active default, **read-only** on the
  fork) and eliteGoblin (owner). Prefer per-command
  `export GH_TOKEN=$(gh auth token -h github.com -u eliteGoblin)` over
  `gh auth switch` — same access, no global state to forget to switch back.
  Symptoms of using the wrong one: `404` on PATCH/merge, and
  `Unauthorized: As an Enterprise Managed User` on addComment.
- `gh pr list/view` with no `--repo` resolves to **upstream** (affaan-m), not the
  fork — PR numbers come back in the thousands. Always pass
  `--repo eliteGoblin/everything-claude-code`.
- Pushing a detached HEAD to a NEW branch needs the full refspec
  (`HEAD:refs/heads/<name>`); `HEAD:<name>` fails with "Head ref must be a branch".
- The shared checkout at ~/devel/everything-claude-code accumulates UNPUSHED
  main commits from other sessions. A branch cut from local main then PRed
  against origin/main carries those commits into the PR diff (and a squash
  merge misattributes them). Before branching: check `git log origin/main..main`
  and cut from origin/main (worktree) unless you intend to ship the backlog.
- `node fsun_config/ecc.js sync` works fine from a worktree of origin/main —
  use that to deploy to ~/.claude without touching the dirty shared checkout.

## commands/sessions.md is double-tracked — its "drift" is by design (2026-08-07)
- It sits in BOTH `manifest.upstream` and `manifest.custom`. Every `sync` therefore
  reports it twice (`UPDATE:` then `UPDATE (custom):`) and a byte-compare of the
  UPSTREAM source against the install will ALWAYS differ — the custom override wins
  and is written last. This is correct. Do not "fix" it; compare against the custom
  copy. Consequence: `sync` can never report 0 copied.

## Cherry-picking one upstream commit can need an unlisted prerequisite (2026-08-07, PR #28)
- Upstream `ab373716` (#2609) is a one-line addition to `KNOWN_MODEL_WINDOW_TOKENS`
  — a table this fork did not have. It conflicted until `cd39df15` (#2468), which
  introduced the table, was picked first; then both applied clean.
- Rule: when an upstream cherry-pick conflicts, check whether the hunk's CONTEXT
  exists on the fork before hand-resolving. If it does not, pick the commit that
  introduced it — hand-writing the missing mechanism forks the file from upstream
  and guarantees a conflict at every future sync.
- Upstream code comments cite the ISSUE number while the commit cites the PR
  (#2461 = issue, #2468 = PR). Copilot reads that as a mismatch; it is not.

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
