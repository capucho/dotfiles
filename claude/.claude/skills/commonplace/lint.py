#!/usr/bin/env python3
"""Lint the commonplace vault: broken links, orphans, frontmatter, page size.

Usage: lint.py [vault]   (default ~/Documents/commonplace)
Exit 1 when broken links or frontmatter errors exist.
"""
import os
import re
import sys
from pathlib import Path

TYPES = {"concept", "idea", "entity", "source", "domain"}
TYPE_DIRS = {"concepts", "ideas", "entities", "sources", "domains"}
OUTSIDE = {"self-organization", "templates", "swedish", "zz_archives", "assets", ".obsidian", ".git", ".trash"}
FIXED = {"home.md", "log.md", "working-memory.md", "SCHEMA.md"}
MAX_LINES = 200

LINK = re.compile(r"!?\[\[([^\]|#^]+)(?:[#^][^\]|]*)?(?:\|[^\]]*)?\]\]")
FENCE = re.compile(r"^(```|~~~).*?^\1", re.S | re.M)
INLINE_CODE = re.compile(r"`[^`\n]*`")


def frontmatter(text):
    if not text.startswith("---\n"):
        return {}
    end = text.find("\n---", 4)
    if end == -1:
        return {}
    fm = {}
    for line in text[4:end].splitlines():
        m = re.match(r"^([A-Za-z_][\w-]*):\s*(.*)$", line)
        if m:
            fm[m.group(1)] = m.group(2).strip()
    return fm


def main():
    vault = Path(sys.argv[1] if len(sys.argv) > 1 else "~/Documents/commonplace").expanduser()
    files = [p for p in vault.rglob("*") if p.is_file() and not set(p.relative_to(vault).parts) & {".obsidian", ".git", ".trash"}]
    names = {}
    for p in files:
        names.setdefault(p.name.lower(), p)
        if p.suffix == ".md":
            names.setdefault(p.stem.lower(), p)
            names.setdefault(str(p.relative_to(vault).with_suffix("")).lower(), p)

    broken, errors, big = [], [], []
    inbound = {p: 0 for p in files if p.suffix == ".md"}

    for p in inbound:
        rel = p.relative_to(vault)
        text = p.read_text(encoding="utf-8", errors="replace")
        body = INLINE_CODE.sub("", FENCE.sub("", text))
        for target in LINK.findall(body):
            t = target.strip().lower()
            hit = names.get(t) or names.get(t.removesuffix(".md"))
            if hit is None:
                broken.append(f"{rel}: [[{target.strip()}]]")
            elif hit != p and hit in inbound:
                inbound[hit] += 1

        if rel.parts[0] in TYPE_DIRS:
            fm = frontmatter(text)
            t = fm.get("type")
            if t not in TYPES:
                errors.append(f"{rel}: type is {t!r}")
            elif t != "domain" and not fm.get("domains", "").strip("[] "):
                errors.append(f"{rel}: missing domains")
            if text.count("\n") > MAX_LINES:
                big.append(f"{rel}: {text.count(chr(10))} lines")

    orphans = [
        str(p.relative_to(vault)) for p, n in inbound.items()
        if n == 0 and p.relative_to(vault).parts[0] not in OUTSIDE and p.name not in FIXED
    ]

    for title, items in (("Broken links", broken), ("Frontmatter", errors), ("Orphans", sorted(orphans)), (f"Over {MAX_LINES} lines", big)):
        print(f"## {title} ({len(items)})")
        for i in items:
            print(f"- {i}")
        print()

    sys.exit(1 if broken or errors else 0)


if __name__ == "__main__":
    main()
