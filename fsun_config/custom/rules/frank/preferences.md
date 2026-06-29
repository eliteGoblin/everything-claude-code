# Frank's Personal Preferences

> Custom always-on rule. Highest priority — overrides upstream rules on conflict.
> Lives in `fsun_config/custom/rules/frank/preferences.md`, installs to
> `~/.claude/rules/frank/preferences.md` via `ecc.js sync`.

## Communication

- Be concise. Lead with the answer, then the reasoning.
- State assumptions explicitly; if a request is ambiguous, ask before doing large or irreversible work.
- Surface tradeoffs instead of silently picking one option.

## Workflow

- Prefer the smallest change that satisfies the requirement; no speculative refactors.
- Sync model: cherry-pick from three sources via `node fsun_config/ecc.js` —
  `upstream` (ECC fork), `bible` (~/claude-bible skills), `custom` (this dir).
- Keep my fork rebased on `upstream/main`; my commits stay isolated in `fsun_config/`.

## Definition of Done (CRITICAL — overrides any optimistic phrasing)

A user-reported issue is **DONE only when its exact reproduction is re-run and
shown gone.** Designed / built / merged / deployed are **NOT done** — they are
intermediate states. Never round them up to "done."

- **Track every original issue I report to closure**, each with its verify
  command (e.g. issue "`ps aux | grep mesh` finds the daemon" → not done until
  `ps aux | grep mesh` returns nothing against the live mesh).
- **Status reports must list each of my original issues as `VERIFIED-GONE` vs
  `OPEN`** — and **lead with what's still OPEN**. No aggregate "everything's
  done" while any reported issue is unverified. If a fix is only designed/built,
  say "OPEN — designed, not built/verified", loudly.
- **Use the `e2e-verifier` agent to own VERIFY**: it re-runs my reproduction and
  reports verified-vs-NOT, never claims green it didn't exercise. A feature is
  not closeable until e2e-verifier confirms the symptom is gone with no orphans
  (e.g. exactly one version/generation running, the requested leak absent).
- When I say "do all of them," that means **all BUILT + DEPLOYED + VERIFIED**,
  not "some built, the rest designed."
- **Before I ever say "done," show an explicit per-item CHECKED / NOT-CHECKED
  list.** A feature is done only when the **e2e-verifier walks the ba-curator
  feature/acceptance list** (the contract) and marks each acceptance item
  checked against live behavior. I then surface that exact list — what was
  verified and what was NOT — and lead with the NOT-checked. No "done" without
  the list. ba-curator doc is the source of the checklist; e2e-verifier is the
  one that ticks the boxes against reality.

## Code

- Match the conventions of the surrounding code.
- No `console.log` or debug noise in committed code.

<!-- Add or edit guidelines above, then run: node fsun_config/ecc.js sync -->
