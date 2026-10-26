# First run: restructure the commonplace

One-time. Turns the topic-folder vault into the typed wiki. Each step ends in a commit, so any batch reverts cleanly.

## 0. Preconditions — hard stop if any fails

- No secrets in the vault: run the scan from step 1 first. Any hit → stop, show the file and line (mask the value), let the user remove it.
- The telegram-vault-bot is stopped (it writes via `ob sync` and would race the moves). Ask the user to confirm.
- The vault is not yet a git repo, or the user confirms reusing the existing one.

## 1. Baseline

```sh
cd ~/Documents/commonplace
git init -b main
git remote add origin git@github.com:capucho/commonplace.git
printf '.obsidian/workspace*.json\n.DS_Store\n.trash/\n' > .gitignore
```

Secret scan: `gitleaks dir .` if `gitleaks` exists, else `grep -rniE 'password|secret|token|AKIA[0-9A-Z]{16}|BEGIN .*PRIVATE KEY' --include='*.md' .`. Review each hit; a false positive (prose about tokens) is fine, a real value stops the run.

Commit `chore: baseline`, then `git push -u origin main`.

## 2. Scaffold

Write `SCHEMA.md` from the seed below, an empty `log.md` (`# Log`), and the folders `concepts/ ideas/ entities/ sources/ domains/`. Create one `domains/<field>.md` per section of the current `home.md`, splitting Engineering into `backend`, `cloud`, `ai`. Commit `chore: scaffold wiki`.

## 3. Inventory — user approves before anything moves

In scope: root loose notes, `studies/`, `references/`, `projects/`, `career-management/`, `hobbies/`, `lifestyle/`. Out of scope as listed in `SCHEMA.md` → _Outside the wiki_.

Produce one table row per in-scope file: `path | type (or "stays") | target path | split into | domains`. Done when every in-scope file has a row. Show the table; wait for approval and edits.

## 4. Execute — one batch and commit per domain

- Move with `git mv`. Basenames stay unique, so Obsidian `[[links]]` keep resolving.
- Renames (spaces, `Untitled.md`, duplicate basenames such as `roadmap.md`): rename, then rewrite every `[[old]]`, `[[old|`, `[[old#` vault-wide. Re-run lint after each rename batch.
- Add frontmatter per `SCHEMA.md`. Move inline `#tag` lines into `tags:`.
- Split a note covering several concepts: one page per concept, and the original becomes a `source` (`kind: notes` or `course`) linking to its splits.

Commit `refactor(<domain>): restructure into wiki`.

## 5. Close

Rewrite `home.md` as the index of `domains/` pages. Run `lint.py` until it reports zero broken links and zero in-scope pages missing `type`/`domains`. Append `YYYY-MM-DD restructure — <n> pages typed, <m> split` to `log.md`, commit, push. Tell the user the bot can restart.

## SCHEMA.md seed

````markdown
# Commonplace schema

Single source of truth for how this vault is organized. Agents and humans read this first.

## Types

Every wiki page has `type:` in frontmatter — exactly one of:

| type | is | name as | folder |
|---|---|---|---|
| concept | what something is or how it works — one per page | noun, `event-loop` | `concepts/` |
| idea | my own claim, insight, or opinion | the claim, `estimates-are-commitments` | `ideas/` |
| entity | a named thing; `kind: person \| org \| tool \| project \| place` | proper name, `wolt` | `entities/` |
| source | where knowledge came from; `kind: book \| article \| course \| meeting \| conversation \| notes` | `YYYY-MM-DD-topic` when dated | `sources/` |
| domain | hub for a field: short overview + its members | field, `ai` | `domains/` |

Concept vs idea: a concept would read the same in a textbook; an idea is mine and could be wrong.

## Frontmatter

```yaml
---
type: concept
domains: ["[[ai]]"]          # every type except domain
sources: ["[[some-source]]"] # concept and idea
kind: tool                   # entity and source
tags: []                     # optional
---
```

## Page shape

1. First line after frontmatter: one-sentence summary.
2. Body. Small pages; split when a page covers more than one concept.
3. `## Related` — `[[wikilinks]]` to neighbours. Links are the only relation syntax.

## Naming

kebab-case basenames, unique across the vault (Obsidian resolves `[[name]]` by basename). Dated pages: `YYYY-MM-DD-topic`.

## Domain pages

Membership lives in each page's `domains:`. A domain page lists its members with a Bases view:

```base
filters:
  and:
    - file.hasLink(this.file)
views:
  - type: table
    name: Members
    order: [file.name, type]
```

## Files with a fixed role

- `home.md` — index of domains.
- `log.md` — append-only, one line per capture / lint / restructure.
- `working-memory.md` — inbox. The telegram bot appends under `Links / Quick captures`; capture drains it.

## Outside the wiki

Kept as-is, no `type` required: `self-organization/` (daily notes), `templates/`, `swedish/` (own agent, own `CLAUDE.md`), `zz_archives/`, `assets/`, and personal lists or logs (recipes, workout routine, brag-doc, expenses, gift lists, pending tasks).
````
