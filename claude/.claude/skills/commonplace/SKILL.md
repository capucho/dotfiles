---
name: commonplace
description: Capture, query, and tend the commonplace — the user's Obsidian wiki at ~/Documents/commonplace. Use when the user wants something from the conversation saved, filed, or noted to the commonplace or vault; asks what the commonplace or their notes say about a topic; or wants the vault tidied, linted, or reorganized.
---

# Commonplace

The commonplace is an LLM-maintained wiki: small typed pages joined by `[[wikilinks]]`. Vault: `~/Documents/commonplace`. You are its **librarian** — every run leaves it more linked, never more scattered.

**First, every run:** read `~/Documents/commonplace/SCHEMA.md`. It is the single source of truth for types, frontmatter, naming, and layout. If it is absent, the vault has not been restructured yet — follow [RESTRUCTURE.md](RESTRUCTURE.md) instead of the branches below.

## Capture

Turn the conversation (or a named slice of it) into pages.

1. **Extract** candidates: concepts, ideas, entities worth keeping beyond this session. Done when you hold a list, each tagged with a type from `SCHEMA.md`.
2. **Find** each candidate in the vault — basename match, then content grep for its key terms. Done when every candidate is marked _update `<path>`_ or _new_. Prefer update: a second page for an existing concept is the failure this step exists to stop.
3. **Write** one `source` page for this conversation (`sources/YYYY-MM-DD-conversation-<topic>.md`), then create or update each page. Every concept/idea lists the source in `sources:`; the source page links every page it fed under `## Related`. New pages get `domains:` from existing `domains/` pages — create a domain only when no existing one fits, and say so.
4. **Drain the inbox** when the user asks: file the entries under `working-memory.md` → `Links / Quick captures` the same way, then remove each filed entry.
5. **Log**: append one line to `log.md` — `YYYY-MM-DD capture <source> — new: [[a]], [[b]]; updated: [[c]]`.
6. **Commit**: run `python3 ~/.claude/skills/commonplace/lint.py`; fix anything you introduced. Then secret-scan the diff (`gitleaks git --staged` if `gitleaks` exists, else grep the staged diff for `password|secret|token|AKIA|PRIVATE KEY`) — any hit: unstage it and report. Then `git commit -m "capture: <topic>"` and `git push`. A failed push is reported; the local commit stands.

Done when the report lists every candidate as _new_, _updated_, or _dropped (why)_, lint shows nothing new, and the commit exists.

## Query

1. Read `home.md` → the relevant `domains/` page → its member pages; grep for terms the hubs miss.
2. Answer from the pages, citing each claim as `[[page]]`. Mark anything you add from outside the vault as such.
3. When the answer synthesized something new, offer to file it as an `idea` or `concept` — answers that go back in make the wiki compound.

## Lint

1. Run `python3 ~/.claude/skills/commonplace/lint.py`. It reports broken links, orphans, missing or invalid `type`, missing `domains`, and oversized pages.
2. Add what the script cannot see: near-duplicate concepts, pages covering several concepts (split candidates), stale domains.
3. Report grouped by check; fix only what the user approves, then log and commit as in Capture steps 5–6.
