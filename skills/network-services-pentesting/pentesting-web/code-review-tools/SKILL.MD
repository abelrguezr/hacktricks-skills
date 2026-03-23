---
name: sast-code-review
description: Perform static application security testing (SAST) and source code security reviews. Use this skill whenever the user wants to scan code for vulnerabilities, review source code for security issues, run SAST tools, analyze dependencies for known vulnerabilities, deobfuscate JavaScript, or perform any kind of code security analysis. Trigger on mentions of: code review, security scan, SAST, vulnerability scan, dependency check, semgrep, sonarqube, codeql, snyk, bandit, audit, deobfuscate, minify, or any request to analyze code for security issues.
---

# SAST Code Review Skill

This skill helps you perform comprehensive static application security testing (SAST) and source code security reviews using industry-standard tools.

## When to Use This Skill

Use this skill when the user:
- Wants to scan code for security vulnerabilities
- Needs to review source code for security issues
- Asks to run SAST tools (semgrep, sonarqube, codeql, snyk, bandit, etc.)
- Wants to check dependencies for known vulnerabilities
- Needs to deobfuscate or analyze minified JavaScript
- Requests security analysis of any codebase

## Quick Tool Selection Guide

| Language/Context | Recommended Tool |
|-----------------|------------------|
| Multi-language | Semgrep, CodeQL, SonarQube |
| Node.js | npm audit, pnpm audit, nodejsscan, RetireJS |
| Python | Bandit, safety |
| JavaScript (deobfuscation) | JSNice, Wakaru, Humanify |
| Rust | cargo-audit |
| Go | gosec |
| PHP | Psalm, PHPStan |
| Java | JD-Gui, procyon |
| Electron | electronegativity |

## Tool Quick Reference

### Semgrep (Multi-language, Open Source)

**Best for:** Quick security scans across many languages

```bash
# Install
brew install semgrep

# Scan a repository
semgrep scan --config auto

# Scan with specific rules
semgrep scan --config p/security-audit

# Scan specific files
semgrep scan --include="*.py" --exclude="tests/"
```

**Supported Languages:** C#, Go, Java, JavaScript, JSX, JSON, PHP, Python, Ruby, Scala, Terraform, TypeScript, TSX, Kotlin, Rust, Bash, C, C++, and more.

### CodeQL (GitHub, Free for Open Source)

**Best for:** Deep code analysis with custom queries

```bash
# Create database (auto-detect language)
codeql database create ./codeql_db --source-root ./repo

# Create database (specify language)
codeql database create ./codeql_db --language javascript --source-root ./repo

# Analyze with default queries
codeql database analyze ./codeql_db --format=sarif-latest --output=results.sarif

# Analyze with specific pack
codeql database analyze ./codeql_db javascript-security-extended --format=sarif-latest --output=results.sarif
```

### SonarQube (Free Community Edition)

**Best for:** Continuous code quality and security monitoring

```bash
# Start SonarQube
docker run -d --name sonarqube -p 9000:9000 sonarqube:latest

# Install scanner
brew install sonar-scanner

# Scan project
sonar-scanner \
  -Dsonar.projectKey=my-project \
  -Dsonar.sources=. \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.token=your-token
```

### Snyk (Free Tier Available)

**Best for:** Dependency vulnerability scanning

```bash
# Install
npm install -g snyk

# Authenticate
snyk auth

# Test dependencies
snyk test

# Test code (requires Snyk Code enabled)
snyk code test

# Test containers
snyk container test <image>

# Test IaC
snyk iac test
```

### Language-Specific Tools

#### Python

```bash
# Bandit - Security issues in Python code
pip install bandit
bandit -r ./path/to/code

# Safety - Dependency vulnerabilities
pip install safety
safety check
```

#### Node.js

```bash
# npm audit
npm audit

# pnpm audit
pnpm audit

# yarn audit
yarn audit

# RetireJS - Known vulnerable JS libraries
npm install -g retire
retire --colors
```

#### Rust

```bash
# cargo-audit
cargo install cargo-audit
cargo audit
cargo audit fetch  # Update advisory database
```

#### Go

```bash
# gosec
go install github.com/securego/gosec/v2/cmd/gosec@latest
gosec ./...
```

#### Java

```bash
# Decompile JAR
procyon -jar app.jar -o ./output/

# Decompile class
procyon -o . path/to/Class.class

# Create JAR
jar -cmf META-INF/MANIFEST.MF output.jar *.class
```

### JavaScript Deobfuscation

**Best for:** Analyzing minified/obfuscated JavaScript

#### Method 1: Source Maps

```bash
# If .map files exist, use Maximize
npm install -g maximize
maximize app.js app.js.map
```

#### Method 2: JSNice

```bash
# Install
npm install -g jsnice

# Deobfuscate
jsnice app.js > deobfuscated.js
```

#### Method 3: Wakaru (Modern Alternative)

```bash
# Install
npm install -g wakaru

# Unpack and deobfuscate
wakaru app.js
```

#### Method 4: Humanify (LLM-powered)

```bash
# Uses LLMs to rename minified variables
npm install -g humanify
humanify app.js
```

#### Method 5: Console.log Trick

1. Find the return value at the end of the packed code
2. Change it to `console.log(<packerReturnVariable>);`
3. Run in [jsconsole.com](https://jsconsole.com/)
4. Beautify output with [prettier.io](https://prettier.io/playground/)

## Workflow Recommendations

### For Quick Scans
1. Start with **Semgrep** - fast, no setup, many languages
2. Check dependencies with language-specific audit tools
3. Review findings and prioritize by severity

### For Deep Analysis
1. Set up **CodeQL** database
2. Run with security-extended packs
3. Review SARIF output in VSCode or web viewer
4. Create custom queries for specific patterns

### For Continuous Integration
1. Use **SonarQube** for ongoing monitoring
2. Integrate **Snyk** for dependency tracking
3. Add **Semgrep** to CI pipeline for quick checks

### For JavaScript Applications
1. Check for source maps first
2. Try deobfuscation tools in order: Maximize → JSNice → Wakaru → Humanify
3. Use console.log trick for packed code
4. Beautify with Prettier for analysis

## Output Formats

- **SARIF** - Standard format, viewable in VSCode, GitHub, and web viewers
- **JSON** - Machine-readable, good for CI/CD
- **Console** - Human-readable, good for quick review

## Viewing Results

- **VSCode Extensions:**
  - Semgrep
  - CodeQL
  - SARIF Viewer
  - Snyk

- **Web Viewers:**
  - [SARIF Web Component](https://microsoft.github.io/sarif-web-component/)
  - SonarQube UI (localhost:9000)

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| CodeQL detects multiple languages | Use `--language` flag or `--db-cluster` |
| Semgrep too slow | Use `--exclude` to skip test/vendor directories |
| Deobfuscation fails | Try multiple tools, check for recursive packing |
| No findings reported | Verify tool is configured correctly, check for false negatives |

## Best Practices

1. **Always scan dependencies** - Most vulnerabilities are in third-party code
2. **Use multiple tools** - Different tools catch different issues
3. **Review false positives** - Tune rules to reduce noise
4. **Integrate in CI/CD** - Catch issues early
5. **Keep tools updated** - New vulnerabilities discovered regularly
6. **Document findings** - Track and remediate systematically

## References

- [OWASP Source Code Analysis Tools](https://owasp.org/www-community/Source_Code_Analysis_Tools)
- [Semgrep Documentation](https://semgrep.dev/docs/)
- [CodeQL Documentation](https://docs.github.com/en/code-security/codeql-cli)
- [Snyk Documentation](https://snyk.io/docs/)
- [Bandit Documentation](https://bandit.readthedocs.io/)
