#!/bin/bash
# github-dork-search.sh - Run GitHub dork searches for leaked secrets
# Usage: ./github-dork-search.sh <org-or-user> [--all-dorks]

set -e

TARGET="${1:-}"
USE_ALL_DORKS="${2:-}"

if [[ -z "$TARGET" ]]; then
    echo "Usage: $0 <org-or-user> [--all-dorks]"
    echo ""
    echo "Examples:"
    echo "  $0 mycompany              # Search for common patterns in org"
    echo "  $0 mycompany --all-dorks  # Run all dork queries"
    exit 1
fi

echo "=== GitHub Dork Search ==="
echo "Target: $TARGET"
echo ""

# Function to run a dork search and open in browser
run_dork() {
    local query="$1"
    local name="$2"
    
    # Build GitHub search URL
    local url="https://github.com/search?q=$query&type=code"
    
    echo "[$name]"
    echo "  Query: $query"
    echo "  URL: $url"
    echo ""
}

# Common credential patterns
echo "=== Token Patterns ==="
run_dork "org:$TARGET ghp_" "GitHub Personal Access Tokens"
run_dork "org:$TARGET gho_" "GitHub OAuth Tokens"
run_dork "org:$TARGET xoxb-" "Slack Bot Tokens"
run_dork "org:$TARGET xoxp-" "Slack User Tokens"

if [[ "$USE_ALL_DORKS" == "--all-dorks" ]]; then
    echo "=== AWS Credentials ==="
    run_dork "org:$TARGET AWS_ACCESS_KEY_ID" "AWS Access Key ID"
    run_dork "org:$TARGET aws_access_key" "AWS Access Key (lowercase)"
    run_dork "org:$TARGET aws_secret" "AWS Secret Key"
    run_dork "org:$TARGET AKIA" "AWS Access Key Pattern"
    
    echo "=== API Keys ==="
    run_dork "org:$TARGET api_key" "Generic API Key"
    run_dork "org:$TARGET api_secret" "Generic API Secret"
    run_dork "org:$TARGET GOOGLE_API_KEY" "Google API Key"
    run_dork "org:$Target OPENAI_API_KEY" "OpenAI API Key"
    
    echo "=== Database Credentials ==="
    run_dork "org:$TARGET database_password" "Database Password"
    run_dork "org:$TARGET db_password" "DB Password"
    run_dork "org:$TARGET mysql" "MySQL References"
    run_dork "org:$TARGET redis_password" "Redis Password"
    
    echo "=== Configuration Files ==="
    run_dork "org:$TARGET filename:.env" ".env Files"
    run_dork "org:$TARGET filename:.git-credentials" "Git Credentials"
    run_dork "org:$TARGET filename:secrets.yml" "Rails Secrets"
    run_dork "org:$TARGET filename:wp-config.php" "WordPress Config"
    run_dork "org:$TARGET filename:config.json" "Config JSON"
    
    echo "=== SSH Keys ==="
    run_dork "org:$TARGET filename:id_rsa" "SSH Private Keys"
    run_dork "org:$TARGET filename:id_dsa" "DSA Private Keys"
    run_dork "org:$TARGET \"private key\"" "Private Key Text"
    
    echo "=== Passwords ==="
    run_dork "org:$TARGET password" "Password References"
    run_dork "org:$TARGET passwd" "Passwd References"
    run_dork "org:$TARGET credentials" "Credentials References"
    
    echo "=== Cloud Services ==="
    run_dork "org:$Target amazonaws" "AWS References"
    run_dork "org:$Target firebase" "Firebase Config"
    run_dork "org:$Target herokuapp" "Heroku References"
    run_dork "org:$Target mailchimp" "Mailchimp API"
    run_dork "org:$Target stripe" "Stripe API"
    
    echo "=== Shell History ==="
    run_dork "org:$Target filename:.bash_history" "Bash History"
    run_dork "org:$Target filename:.bashrc" "Bash RC"
    run_dork "org:$Target filename:.zshrc" "ZSH RC"
fi

echo "=== Search Complete ==="
echo ""
echo "Note: GitHub's code search has limitations:"
echo "  - Only indexed files are searchable"
echo "  - Regex not supported in API (use Web UI)"
echo "  - Large files may not be indexed"
echo ""
echo "For thorough scanning, clone repos and use local tools:"
echo "  - gitleaks detect --source <repo>"
echo "  - trufflehog git file://<repo>"
