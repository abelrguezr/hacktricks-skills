---
name: wide-source-code-search
description: Use this skill whenever you need to search for leaked credentials, secrets, API keys, or vulnerability patterns across code repositories. Trigger this when investigating potential data leaks, searching for exposed secrets in public repos, hunting for security vulnerabilities in code, or performing external reconnaissance on a target's codebase. Don't forget to use this even if you're just checking if a company's repos might contain sensitive information.
---

# Wide Source Code Search

This skill helps you enumerate and search across platforms that allow searching for code (literal strings or regex patterns) in thousands or millions of repositories. This is essential for finding leaked information, exposed secrets, and vulnerability patterns during security assessments.

## When to Use This Skill

- You're investigating a target and want to find exposed credentials or secrets
- You need to search for specific vulnerability patterns across multiple repos
- You're doing external reconnaissance on a company's codebase
- You want to check if sensitive information was accidentally committed
- You're hunting for API keys, passwords, tokens, or other secrets in public repos

## Available Code Search Platforms

### 1. SourceGraph
**URL**: https://sourcegraph.com/search

- Search across millions of repositories
- Free version available (enterprise has 15-day trial)
- **Supports regex patterns**
- Good for broad searches across many projects

**Example searches**:
```
repo:github.com/username/project "api_key"
repo:github.com/username/project "password"
lang:python "secret"
```

### 2. GitHub Search
**URL**: https://github.com/search

- Search across all GitHub repositories
- **Supports regex patterns**
- Most widely used platform for code search

**Example searches**:
```
"api_key" OR "API_KEY" OR "apikey"
"password" OR "passwd" OR "pwd"
"secret" OR "SECRET"
type:file language:python
```

**GitHub Code Search** (alternative interface):
- URL: https://cs.github.com/
- Sometimes provides different results

### 3. GitLab Advanced Search
**URL**: https://docs.gitlab.com/ee/user/search/advanced_search.html

- Search across GitLab projects
- **Supports regex patterns**
- Useful for organizations using GitLab

### 4. SearchCode
**URL**: https://searchcode.com/

- Search code in millions of projects
- Aggregates from multiple sources
- Good for broad discovery

### 5. Sourcebot
**URL**: https://www.sourcebot.dev/

- Open source code search tool
- Index and search across thousands of repos
- Modern web interface

## Common Search Patterns

### Credential Patterns
```
# API Keys
"api_key" | "apikey" | "API_KEY" | "api-key"
"api_secret" | "api_secret_key"
"access_key" | "secret_key"

# AWS Credentials
"AKIA[0-9A-Z]{16}"
"aws_access_key_id"
"aws_secret_access_key"

# Generic Passwords
"password" | "passwd" | "pwd" | "pass"
"passwords" | "passwd_file"

# Tokens
"token" | "TOKEN" | "auth_token" | "access_token"
"refresh_token" | "bearer_token"

# Private Keys
"-----BEGIN RSA PRIVATE KEY-----"
"-----BEGIN OPENSSH PRIVATE KEY-----"
"-----BEGIN EC PRIVATE KEY-----"

# Database Credentials
"mysql://" | "postgres://" | "mongodb://"
"database_url" | "db_password" | "db_pass"

# JWT Secrets
"jwt_secret" | "JWT_SECRET" | "jwt_key"
```

### Vulnerability Patterns
```
# Hardcoded URLs with credentials
"http://.*:.*@"

# Debug/Dev settings in production
"debug=True" | "DEBUG = True"
"debug: true" | "debug:True"

# SQL Injection indicators
"SELECT.*FROM.*WHERE.*=.*" | "UNION.*SELECT"

# Command injection
"system(" | "exec(" | "eval("

# Insecure random
"random()" | "Math.random()"
```

## Important Warnings

### ⚠️ Check All Branches
When you find a repo with potential leaks, **don't just check the main branch**. Secrets might be in:
- Other branches
- Old commits that were "removed" but still in history
- Deleted branches that still exist in git history

**Always run**:
```bash
git log -p --all | grep -i "password\|secret\|key\|token"
```

### ⚠️ Check Git History
Even if a file is deleted, the secrets remain in git history:
```bash
# Search entire git history for patterns
git log -p --all | grep -i "api_key"
git log -p --all | grep -i "password"

# Find all commits that touched files with "secret" in name
git log --all --name-only | grep -i secret
```

### ⚠️ Check for .git directories
Sometimes .git directories are accidentally exposed on web servers:
```
# Check if .git is accessible
wget http://target.com/.git/config
curl http://target.com/.git/HEAD
```

## Search Strategy

### 1. Start Broad
Begin with general searches across platforms to identify potential targets:
- Search for company name + "api_key"
- Search for known project names + "password"
- Search for technology stack + "secret"

### 2. Narrow Down
Once you find interesting repos:
- Clone the repository
- Search the entire git history
- Check all branches
- Look for configuration files

### 3. Document Findings
Keep track of:
- Which platform the leak was found on
- The specific commit/branch
- The type of credential exposed
- When it was exposed (commit date)

## Example Workflow

```
1. Identify target company/project
2. Search GitHub for company name + credential patterns
3. Search SourceGraph for broader coverage
4. For each interesting repo found:
   - Clone the repo
   - Run git log -p --all to search history
   - Check all branches
   - Document any findings
5. Cross-reference with other platforms
```

## Legal and Ethical Considerations

- Only search repositories you have permission to assess
- Report findings responsibly to the repository owners
- Don't exploit discovered credentials
- Follow responsible disclosure practices
- Respect terms of service of search platforms

## Tips for Better Results

1. **Use regex** when available - it's more powerful than literal search
2. **Search multiple platforms** - different platforms index different repos
3. **Check commit history** - deleted files still contain secrets in history
4. **Look for patterns** - companies often use similar naming conventions
5. **Search in multiple languages** - credentials might be in comments, config files, or code
6. **Use wildcards** - "*key*" or "*secret*" can catch variations
7. **Check environment files** - .env, .env.example, config files often contain secrets

## Related Reconnaissance

This skill works well with:
- Subdomain enumeration (find repos for discovered subdomains)
- Technology fingerprinting (search for specific framework vulnerabilities)
- Employee research (search for personal repos with company info)
- Asset discovery (find repos that reveal infrastructure details)
