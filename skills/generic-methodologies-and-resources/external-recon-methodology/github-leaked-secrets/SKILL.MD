---
name: github-leaked-secrets
description: Find leaked credentials, API keys, and secrets in GitHub repositories using automated scanners and dork searches. Use this skill whenever the user needs to scan repos for exposed secrets, search for leaked credentials in GitHub, perform org-wide secret detection, or investigate potential credential exposure. Trigger for any request involving secret scanning, credential hunting, API key discovery, or GitHub security auditing.
---

# GitHub Leaked Secrets Detection

A skill for finding exposed credentials, API keys, and secrets in GitHub repositories using automated scanners and search techniques.

## When to Use This Skill

Use this skill when:
- Scanning a repository for leaked credentials or secrets
- Searching GitHub for exposed API keys, tokens, or passwords
- Performing org-wide secret detection across multiple repositories
- Investigating potential credential exposure in code
- Auditing repositories before making them public
- Looking for common secret patterns in codebases

## Available Tools

### Primary Scanners

| Tool | Best For | Command |
|------|----------|---------|
| **TruffleHog** | Verified credential scanning, GitHub orgs | `trufflehog github --org <ORG> --results=verified` |
| **Gitleaks** | Git history, directories, archives | `gitleaks detect -v --source .` |
| **Nosey Parker** | High-throughput scanning with UI | `noseyparker scan --datastore np.db <path>` |
| **ggshield** | Pre-commit hooks, CI integration | `ggshield secret scan repo <path>` |

### Secondary Tools

- **RExpository** - Repository enumeration and secret hunting
- **detect-secrets** - Yelp's secret detection tool
- **gitGraber** - Git history secret extraction
- **git-secrets** - AWS's pre-commit hook tool
- **gittyleaks** - Lightweight secret scanner
- **GitDorker** - GitHub dork automation

## Where Secrets Commonly Leak

1. **Repository files** - Default and non-default branches
2. **Full git history** - Removed secrets still in history
3. **Issues and PRs** - Comments, descriptions, code blocks
4. **Actions logs and artifacts** - Public repo CI/CD logs
5. **Wikis** - Documentation with embedded credentials
6. **Gists** - Shared code snippets
7. **Release assets** - Configuration files in releases

## Quick Start

### Scan a Local Repository

```bash
# Using Gitleaks (recommended for most cases)
gitleaks detect -v --source .

# Using TruffleHog
trufflehog git file://. --only-verified

# Using ggshield
ggshield secret scan path -r .
```

### Scan GitHub Organization

```bash
# TruffleHog with GitHub source
export GITHUB_TOKEN=<token>
trufflehog github --org Target --results=verified \
  --include-wikis --issue-comments --pr-comments --gist-comments

# Gitleaks over all org repos
gh repo list Target --limit 1000 --json nameWithOwner,url \
| jq -r '.[].url' | while read -r r; do
  tmp=$(mktemp -d)
  git clone --depth 1 "$r" "$tmp"
  gitleaks detect --source "$tmp" -v || true
  rm -rf "$tmp"
done
```

### Scan Git History

```bash
# Gitleaks with full history
gitleaks detect --source <repo> --log-opts="--all"

# TruffleHog with history
trufflehog git file://. --since-commit 0
```

## GitHub Dorks

### Token Patterns

```bash
# GitHub tokens
ghp_ gho_ ghu_ ghs_ ghr_ github_pat_

# Slack tokens
xoxb- xoxp- xoxa- xoxs- xoxc- xoxe-

# Cloud credentials
AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY aws_session_token
GOOGLE_API_KEY AZURE_TENANT_ID AZURE_CLIENT_SECRET
OPENAI_API_KEY ANTHROPIC_API_KEY
```

### Common Dork Queries

```bash
# General credential patterns
"access_key" "access_token" "api_key" "api_secret"
"aws_access_key_id" "aws_secret" "secret_key"
"password" "passwd" "credentials" "token"

# File-specific searches
filename:.env filename:.git-credentials filename:.npmrc
filename:config.json filename:secrets.yml filename:wp-config.php
filename:id_rsa filename:id_dsa filename:.bashrc

# Extension-based searches
extension:env extension:json extension:yaml extension:properties
extension:sql extension:sh extension:ini

# Org-specific searches
org:Target "AWS_ACCESS_KEY_ID"
org:Target "aws_access_key"
org:Target "bucket_name"
```

### Advanced Dorks

```bash
# Database credentials
"database_password" "db_password" "db_username" "mysql"
"rds.amazonaws.com password" "redis_password"

# Cloud services
"amazonaws" "appspot" "cloudfront" "firebase"
"herokuapp" "mailchimp" "mailgun" "stripe"

# Configuration files
"conn.login" "connectionstring" "config.php dbpasswd"
"settings.py SECRET_KEY" "deployment-config.json"

# SSH and keys
"pem private" "private_key" "ssh" "id_rsa"
```

## Best Practices

### Before Scanning

1. **Get authorization** - Only scan repositories you own or have permission to audit
2. **Use read-only tokens** - Don't use admin tokens for scanning
3. **Rate limit awareness** - GitHub API has rate limits; use pagination
4. **Local vs remote** - Clone repos locally for thorough history scanning

### During Scanning

1. **Use multiple tools** - Different scanners catch different patterns
2. **Verify findings** - Not all matches are real secrets (false positives common)
3. **Check history** - Secrets may have been removed but still in git history
4. **Include all branches** - Scan non-default branches and tags

### After Scanning

1. **Rotate exposed credentials** - Any found secrets should be immediately rotated
2. **Remove from history** - Use `git filter-branch` or BFG Repo-Cleaner
3. **Update CI/CD** - Add pre-commit hooks to prevent future leaks
4. **Document findings** - Track what was found and remediated

## Common Gotchas

- **GitHub search API limitations** - Legacy REST API doesn't support regex; use Web UI
- **File size limits** - Only files below certain size are indexed for search
- **Masking is best-effort** - CI/CD logs may still contain secrets despite masking
- **False positives** - Test strings and documentation may match patterns
- **Rate limiting** - GitHub API has strict rate limits for unauthenticated requests

## Integration Patterns

### Pre-commit Hook

```bash
# Install gitleaks as pre-commit hook
gitleaks protect --source . --verbose
```

### CI/CD Integration

```yaml
# GitHub Actions example
- name: Scan for secrets
  uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Automated Org Scanning

Use the bundled `scan-org.sh` script for automated organization-wide scanning:

```bash
./scan-org.sh --org TargetOrg --output results/
```

## Output Interpretation

### TruffleHog Output

```
[0] Found credential
     Type: AWS Access Key
     Location: config.py:42
     Value: AKIAIOSFODNN7EXAMPLE
     Verified: true
```

### Gitleaks Output

```
[0] Finding: AWS Access Key
     File: .env
     Line: 5
     Secret: AKIAIOSFODNN7EXAMPLE
     RuleID: aws-access-key
```

### Severity Levels

- **Critical** - Verified live credentials (TruffleHog `--results=verified`)
- **High** - High-confidence matches (AWS keys, private keys)
- **Medium** - Potential secrets (generic API keys, tokens)
- **Low** - Possible false positives (test strings, documentation)

## Next Steps After Finding Secrets

1. **Immediate rotation** - Change all exposed credentials
2. **History cleanup** - Remove secrets from git history
3. **Access audit** - Check if secrets were used maliciously
4. **Process improvement** - Add scanning to CI/CD pipeline
5. **Team training** - Educate developers on secret management

## References

- [TruffleHog Documentation](https://github.com/trufflesecurity/trufflehog)
- [Gitleaks Documentation](https://github.com/gitleaks/gitleaks)
- [GitHub: Keeping secrets out of public repositories](https://github.blog/news-insights/product-news/keeping-secrets-out-of-public-repositories/)
- [GitGuardian ggshield](https://github.com/GitGuardian/ggshield)
