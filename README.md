# Red Team Skills Corpus

A collection of **reusable red teaming agent skills** derived from [HackTricks](https://hacktricks.wiki/en/index.html) and organized in Anthropic-compatible format. Each skill encapsulates attack techniques, enumeration methods, exploitation workflows, and defensive evasion tactics for security research and authorized penetration testing. Skills were generated from the source tutorials using Qwen3.5-27B-FP8.

## Structure

- `skills/` — skill packages organized by domain (pentesting-web, windows-hardening, etc.)

## Skill locator (start here)

Use this skill to quickly find relevant skills across the full corpus:

- `skills/skills-locator-navigation/SKILL.MD`
- `skills/skills-locator-navigation/scripts/find_skill.py`
- `skills/skills-locator-navigation/scripts/list_skills.py`

Example:

```bash
python3 skills/skills-locator-navigation/scripts/find_skill.py \
	--skills-root skills \
	--query "golden ticket kerberos" \
	--top 10
```

Each skill is a folder under `skills/<domain>/<topic>/` containing:
- `SKILL.MD` — the reusable technique, with YAML frontmatter and markdown instructions
- `scripts/` — executable code (PowerShell, Python, Bash) for automation
