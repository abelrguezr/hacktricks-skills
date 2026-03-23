#!/bin/bash
# Setup Caddy reverse proxy for Burp MCP handshake fix
# This normalizes headers to bypass Burp's strict Origin validation

set -e

CADDY_DIR="${HOME}/burp-mcp"
CADDYFILE="$CADDY_DIR/Caddyfile"

echo "🔧 Setting up Caddy reverse proxy for Burp MCP..."

# Create directory
mkdir -p "$CADDY_DIR"

# Generate Caddyfile
cat > "$CADDYFILE" <<'EOF'
:19876

reverse_proxy 127.0.0.1:9876 {
  # Lock Host/Origin to the Burp listener
  header_up Host "127.0.0.1:9876"
  header_up Origin "http://127.0.0.1:9876"

  # Strip client headers that trigger Burp's 403 during SSE init
  header_up -User-Agent
  header_up -Accept
  header_up -Accept-Encoding
  header_up -Connection
}
EOF

echo "✅ Caddyfile created at: $CADDYFILE"
echo ""
echo "📋 Next steps:"
echo "   1. Start Caddy: caddy run --config $CADDYFILE &"
echo "   2. Point your MCP client to: http://127.0.0.1:19876"
echo ""
echo "📝 Example Codex config (~/.codex/config.toml):"
echo '   [mcp_servers.burp]'
echo '   command = "java"'
echo '   args = ["-jar", "/path/to/mcp-proxy.jar", "--sse-url", "http://127.0.0.1:19876"]'
