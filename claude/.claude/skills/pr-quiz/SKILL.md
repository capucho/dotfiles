---
name: pr-quiz
description: Debrief on a PR — open-ended questions to verify you understood the changes, with emphasis on dangerous ones.
disable-model-invocation: true
---

Debrief on a PR: open-ended questions one at a time, immediate evaluation after each answer, gap report at the end.

## Process

### 1. Pin the PR

User supplies a reference — URL, PR number, branch, or commit range. Fetch the diff and PR description via `gh pr view` / `git diff`.

Completion: full diff and description in hand.

### 2. Analyze

Read every hunk. Classify each change as routine or **dangerous** (see taxonomy below). Draft 5–10 open-ended questions, weighted toward dangerous changes — every dangerous change gets at least one question.

Questions must be clean: no hints, no framing that reveals the answer, no multiple-choice options.

Completion: question bank set; every dangerous change covered by at least one question.

### 3. Debrief

Ask questions one at a time. Wait for the answer. If the answer is vague or incomplete, probe further — ask a follow-up and wait again. Keep probing until the answer is specific enough to evaluate. Then evaluate immediately: confirm what was right, correct what was wrong or incomplete, explain what was missed. Then ask the next question.

Completion: all questions asked, every answer probed to specificity, all evaluated.

### 4. Gap report

List every dangerous change. Mark each _surfaced_ (answered correctly) or _missed_. For anything missed, give the full explanation now.

Completion: every dangerous change accounted for, nothing omitted.

## Dangerous change taxonomy

- **DB migrations** — schema changes, data migrations, irreversible transforms
- **Breaking API changes** — removed/renamed fields, changed types, altered contracts
- **Auth/security** — permission checks, token handling, scope changes
- **Config/env changes** — new required vars, changed defaults
- **Background jobs** — idempotency broken, ordering assumptions changed
- **Dependency upgrades** — major version bumps
- **Concurrency/locking** — new locks, removed guards, race-prone paths
- **Data mutation** — writes that can't be rolled back
