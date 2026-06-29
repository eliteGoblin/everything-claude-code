# PR Review Workflow — Copilot + CI

> Custom always-on rule. Applies to **every GitHub PR I create**.
> Maintained in `fsun_config/custom/rules/frank/pr-workflow.md`,
> installs to `~/.claude/rules/frank/pr-workflow.md` via `ecc.js sync`.

## On every PR I open

1. **Request a GitHub Copilot code review** on the PR. The REST
   `POST /pulls/{n}/requested_reviewers` with `copilot-pull-request-reviewer[bot]`
   returns 200 but is a **no-op** for Copilot — do NOT trust it. The working
   method is GraphQL:
   ```bash
   # a) get the Copilot bot id (only present if Copilot review is enabled for the repo)
   gh api graphql -f query='query($o:String!,$n:String!){repository(owner:$o,name:$n){
     suggestedActors(capabilities:[CAN_BE_ASSIGNED],first:100){nodes{login __typename ... on Bot{id}}}}}' \
     -f o=OWNER -f n=REPO   # look for login "copilot-pull-request-reviewer"
   # b) request the review
   gh api graphql -f query='mutation($p:ID!,$b:ID!){requestReviews(input:{pullRequestId:$p,botIds:[$b],union:true}){pullRequest{id}}}' \
     -f p=PR_NODE_ID -f b=COPILOT_BOT_ID
   ```
   **Confirm it registered** — do not assume.
2. **If Copilot is unavailable for the repo** (bot absent from `suggestedActors`
   AND not offered in the web UI → Copilot code review isn't enabled for that
   account/repo), do NOT block on it. Substitute a **thorough local review**
   (language `*-reviewer` agent on the diff, e.g. go-reviewer/security-reviewer)
   and proceed once CI is green. Note in the PR that Copilot was unavailable.
3. **Wait** for Copilot's review to post, then fetch **all** of its comments.

## Address every Copilot comment

For each comment, do exactly one of:

- **Agree** → fix it in code, push the fix, then reply on that comment
  thread: `Fixed`.
- **Disagree** → reply on that thread with a clear, specific reason. Never
  silently ignore or dismiss without explanation.

No Copilot comment may be left unaddressed. Every single one ends in either
a fix + `Fixed` reply, or a reasoned rebuttal reply.

## CI must be green

- Before treating the PR as done, **all CI checks for that PR must pass**.
- If any check is failing, diagnose and fix the cause, push, and re-check
  until every check is green.
- Never hand off or call a PR complete while its CI is red or pending-failed.

## Peer-reviewed testing (for live/e2e validation)

When I validate behavior with live or e2e tests, **have a second agent
independently audit the test** — was the test actually valid (did the
destructive step hit the real target?), and is the result genuine or a
false-pass? Catch the false-pass class explicitly:

- **Gate every destructive step on a positive existence check of the EXACT
  target** before acting (e.g. `test -d "$path"` must succeed before `rm -rf
  "$path"`). A path-extraction bug (e.g. split-on-space truncating a path)
  otherwise "passes" by deleting nothing — the system never broke, so it
  trivially "recovered". This actually happened; the existence gate caught it.

## Definition of done (for a PR I created)

- [ ] Copilot review requested via GraphQL (or local `*-reviewer` substituted if Copilot unavailable)
- [ ] Every Copilot comment resolved — fixed (`Fixed`) or rebutted (reason)
- [ ] All CI checks green (a billing-locked account fails jobs at startup with empty steps — fix billing, that's not a code failure)

<!-- Edit this rule, then run: node fsun_config/ecc.js sync -->
