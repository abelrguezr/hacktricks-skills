---
name: skills-locator-navigation
description: Locate, shortlist, and navigate the generated skills corpus quickly. Use this skill whenever the user asks to find a relevant skill, browse the 900+ skills, identify duplicates, map topic coverage, or open the correct SKILL.MD/scripts folder for a task.
---

# Skills Locator & Navigation

Use this skill to reliably find the right skill package inside a large skills corpus.

## When this skill should trigger

Trigger whenever the user asks to:
- find a skill by topic, tool, framework, OS, or attack technique
- browse or navigate the skills tree
- identify where a specific tutorial/README skill landed
- shortlist candidate skills for a request
- inspect missing coverage or duplicates across many skills

## Inputs

- A query, keyword list, or task description
- Optional scope path (subtree under the skills root)

## Outputs

- Ranked list of matching skill directories
- For each match: path to `SKILL.MD`, short reason, and confidence (`high|medium|low`)
- If ambiguous: ask one clarification question and provide best-effort shortlist anyway

## Workflow

1. Resolve skills root.
2. Run `scripts/find_skill.py` with the user query.
3. If needed, run `scripts/list_skills.py` for macro view (coverage by top-level area).
4. Return top 3-10 matches with exact paths.
5. If user picks one, open that skill and proceed with task execution.

## Commands

### Find by query

```bash
python3 scripts/find_skill.py --query "golden ticket kerberos" --top 8
```

### Limit to subtree

```bash
python3 scripts/find_skill.py --query "token escalation" --scope "windows-hardening" --top 10
```

### Show corpus overview

```bash
python3 scripts/list_skills.py --max-topics 40
```

## Ranking behavior

`find_skill.py` scores candidates using:
- exact/near token matches in path
- token matches in YAML `name` and `description`
- token matches in SKILL body

Path and metadata are weighted higher than generic body matches.

## Response format for users

Use this compact format:

1. `<path-to-skill-dir>` — why it matches
2. `<path-to-skill-dir>` — why it matches
3. `<path-to-skill-dir>` — why it matches

Then ask: “Do you want me to open #1 or compare #1 vs #2 first?”

## Notes

- Treat `SKILL.MD` and `SKILL.md` as equivalent.
- Prefer deterministic script output over ad-hoc grep when possible.
- If no strong match exists, return nearest matches and explicitly say coverage might be missing.
