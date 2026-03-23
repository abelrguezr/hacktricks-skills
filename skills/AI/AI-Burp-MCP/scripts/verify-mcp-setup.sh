#!/bin/bash
# Verify Burp MCP setup and diagnose common issues

set -e

echo "🔍 Verifying Burp MCP Setup..."
echo ""

# Check 1: Is Burp MCP Server running?
echo "📌 Check 1: Burp MCP Server"
if command -v curl &> /dev/null; then
    if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9876 | grep -q "200\|404\|405"; then
        echo "   ✅ Burp MCP Server appears to be responding on 127.0.0.1:9876"
    else
        echo "   ❌ Burp MCP Server not responding on 127.0.0.1:9876"
        echo "      → Make sure Burp Suite is running with MCP Server extension enabled"
    fi
else
    echo "   ⚠️  curl not installed, skipping HTTP check"
fi
echo ""

# Check 2: Is Caddy proxy running (if configured)?
echo "📌 Check 2: Caddy Reverse Proxy"
if command -v curl &> /dev/null; then
    if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:19876 2>/dev/null | grep -q "200\|404\|405"; then
        echo "   ✅ Caddy proxy is responding on 127.0.0.1:19876"
    else
        echo "   ⚠️  Caddy proxy not responding on 127.0.0.1:19876"
        echo "      → Start it with: caddy run --config ~/burp-mcp/Caddyfile &"
    fi
else
    echo "   ⚠️  curl not installed, skipping HTTP check"
fi
echo ""

# Check 3: Is proxy JAR present?
echo "📌 Check 3: MCP Proxy JAR"
PROXY_JAR="${HOME}/burp-mcp/mcp-proxy.jar"
if [[ -f "$PROXY_JAR" ]]; then
    echo "   ✅ Proxy JAR found at: $PROXY_JAR"
else
    echo "   ❌ Proxy JAR not found at: $PROXY_JAR"
    echo "      → Extract it from Burp MCP Server tab"
fi
echo ""

# Check 4: Is Java installed?
echo "📌 Check 4: Java Runtime"
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -n1)
    echo "   ✅ Java installed: $JAVA_VERSION"
else
    echo "   ❌ Java not found in PATH"
    echo "      → Install Java 11+ (JDK 21 recommended for Burp AI Agent)"
fi
echo ""

# Check 5: MCP client configs
echo "📌 Check 5: MCP Client Configurations"

if [[ -f "${HOME}/.codex/config.toml" ]]; then
    if grep -q "mcp_servers.burp" "${HOME}/.codex/config.toml"; then
        echo "   ✅ Codex CLI configured for Burp MCP"
    else
        echo "   ⚠️  Codex config exists but no Burp MCP section"
    fi
else
    echo "   ℹ️  Codex CLI not configured"
fi

if [[ -f "${HOME}/Library/Application Support/Claude/claude_desktop_config.json" ]]; then
    if grep -q "burp" "${HOME}/Library/Application Support/Claude/claude_desktop_config.json"; then
        echo "   ✅ Claude Desktop configured for Burp MCP"
    else
        echo "   ⚠️  Claude config exists but no Burp MCP section"
    fi
else
    echo "   ℹ️  Claude Desktop not configured (or not on macOS)"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "If all checks pass, you should be able to:"
echo "   1. Start your MCP client (codex, gemini, ollama, or claude)"
echo "   2. Intercept traffic in Burp Proxy"
echo "   3. Ask the LLM to analyze the traffic"
echo ""
echo "💡 Common issues:"
echo "   - 403 errors → Use Caddy proxy (./scripts/setup-caddy-proxy.sh)"
echo "   - Tools not appearing → Verify proxy JAR path is absolute"
echo "   - Connection refused → Ensure Burp MCP Server extension is enabled"
echo ""
echo "📚 For prompt templates, see: https://github.com/six2dez/burp-mcp-agents"
