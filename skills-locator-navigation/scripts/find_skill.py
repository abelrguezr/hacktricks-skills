#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path
from collections import defaultdict


def detect_skills_root(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit).resolve()
    here = Path(__file__).resolve()
    for p in [here.parent] + list(here.parents):
        if p.name == "skills":
            return p
    return Path.cwd().resolve()


def tokenize(text: str) -> list[str]:
    return re.findall(r"[a-z0-9][a-z0-9_\-\.]+", text.lower())


def read_skill_text(skill_md: Path) -> str:
    try:
        return skill_md.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def parse_frontmatter(text: str) -> tuple[str, str]:
    if not text.startswith("---\n"):
        return "", ""
    end = text.find("\n---\n", 4)
    if end < 0:
        return "", ""
    fm = text[4:end]
    name = ""
    desc = ""
    for line in fm.splitlines():
        if line.lower().startswith("name:"):
            name = line.split(":", 1)[1].strip()
        if line.lower().startswith("description:"):
            desc = line.split(":", 1)[1].strip()
    return name, desc


def score_skill(query_tokens: list[str], rel_dir: str, name: str, desc: str, body: str) -> tuple[int, dict[str, int]]:
    path_tokens = tokenize(rel_dir)
    meta_tokens = tokenize(f"{name} {desc}")
    body_tokens = tokenize(body)

    path_set = set(path_tokens)
    meta_set = set(meta_tokens)
    body_set = set(body_tokens)

    detail = defaultdict(int)
    score = 0

    for t in query_tokens:
        if t in path_set:
            score += 8
            detail["path_exact"] += 1
        elif any(t in p for p in path_set):
            score += 4
            detail["path_partial"] += 1

        if t in meta_set:
            score += 6
            detail["meta_exact"] += 1
        elif any(t in m for m in meta_set):
            score += 3
            detail["meta_partial"] += 1

        if t in body_set:
            score += 2
            detail["body_exact"] += 1

    if score > 0 and len(query_tokens) > 0:
        coverage = sum(1 for t in query_tokens if (t in path_set or t in meta_set or t in body_set))
        score += coverage
        detail["coverage"] = coverage

    return score, dict(detail)


def main() -> None:
    ap = argparse.ArgumentParser(description="Find best matching skills by query")
    ap.add_argument("--query", required=True)
    ap.add_argument("--skills-root", default="")
    ap.add_argument("--scope", default="", help="Relative subtree under skills root")
    ap.add_argument("--top", type=int, default=10)
    args = ap.parse_args()

    skills_root = detect_skills_root(args.skills_root or None)
    scope_root = (skills_root / args.scope).resolve() if args.scope else skills_root

    query_tokens = tokenize(args.query)
    if not query_tokens:
        print("No valid query tokens.")
        return

    results = []
    for md in scope_root.rglob("SKILL.MD"):
        skill_dir = md.parent
        rel_dir = skill_dir.relative_to(skills_root).as_posix()
        text = read_skill_text(md)
        name, desc = parse_frontmatter(text)
        score, detail = score_skill(query_tokens, rel_dir, name, desc, text)
        if score <= 0:
            continue
        results.append((score, rel_dir, name, desc, detail))

    # Also accept lowercase file name variants
    for md in scope_root.rglob("SKILL.md"):
        skill_dir = md.parent
        rel_dir = skill_dir.relative_to(skills_root).as_posix()
        if any(r[1] == rel_dir for r in results):
            continue
        text = read_skill_text(md)
        name, desc = parse_frontmatter(text)
        score, detail = score_skill(query_tokens, rel_dir, name, desc, text)
        if score <= 0:
            continue
        results.append((score, rel_dir, name, desc, detail))

    if not results:
        print("No matching skills found.")
        return

    results.sort(key=lambda x: (-x[0], x[1]))
    top = results[: max(1, args.top)]

    for rank, (score, rel_dir, name, desc, detail) in enumerate(top, start=1):
        print(f"{rank}. {rel_dir}")
        print(f"   score={score} name={name or '-'}")
        if desc:
            print(f"   description={desc[:220]}")
        print(f"   evidence={detail}")


if __name__ == "__main__":
    main()
