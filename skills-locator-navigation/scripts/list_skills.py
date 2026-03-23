#!/usr/bin/env python3
from __future__ import annotations

import argparse
from collections import Counter
from pathlib import Path


def detect_skills_root(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit).resolve()
    here = Path(__file__).resolve()
    for p in [here.parent] + list(here.parents):
        if p.name == "skills":
            return p
    return Path.cwd().resolve()


def main() -> None:
    ap = argparse.ArgumentParser(description="List skill corpus summary")
    ap.add_argument("--skills-root", default="")
    ap.add_argument("--max-topics", type=int, default=30)
    args = ap.parse_args()

    skills_root = detect_skills_root(args.skills_root or None)
    skill_files = list(skills_root.rglob("SKILL.MD")) + list(skills_root.rglob("SKILL.md"))

    dirs = sorted({p.parent.relative_to(skills_root).as_posix() for p in skill_files})
    top_counter = Counter((d.split("/", 1)[0] if "/" in d else d) for d in dirs)

    print(f"skills_root: {skills_root}")
    print(f"total_skills: {len(dirs)}")
    print("top_level_counts:")
    for k, v in top_counter.most_common(max(1, args.max_topics)):
        print(f"- {k}: {v}")


if __name__ == "__main__":
    main()
