---
name: burp-mcp-integration
description: Set up and use Burp Suite's MCP Server extension to enable LLM-assisted passive vulnerability discovery. Use this skill whenever the user wants to integrate Burp with MCP-capable AI tools (Codex, Gemini, Ollama, Claude), configure the MCP proxy, troubleshoot handshake issues, or analyze intercepted HTTP traffic for security findings. Trigger on mentions of Burp MCP, Burp AI Agent, MCP proxy setup, or LLM-assisted traffic review.
---

# Burp MCP Integration

This skill helps you set up and use Burp Suite's MCP Server extension to enable LLM-assisted passive vulnerability discovery and report drafting. The MCP Server exposes intercepted HTTP(S) traffic to MCP-capable LLM clients for evidence-driven review.

## Quick Start

1. **Install Burp MCP Server** from the BApp Store
2. **Extract the proxy JAR** from the MCP Server tab
3. **Configure your MCP client** (Codex, Gemini, Ollama, or Claude)
4. **Start intercepting traffic** and let the LLM analyze it

## Architecture Overview

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  MCP Client     │────▶│  MCP Proxy JAR   │────▶│  Burp MCP Server│
│  (Codex/Gemini/ │     │  (stdio→SSE)     │     │  (127.0.0.1:9876)│
│   Ollama/Claude)│     │                  │     │                 │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                              │
                              ▼
                    ┌──────────────────┐
                    │  Caddy Proxy     │ (optional, for strict headers)
                    │  (127.0.0.1:19876)│
                    └──────────────────┘
```

## Setup Steps

### Step 1: Install Burp MCP Server

1. Open Burp Suite → **Extensions** → **BApp Store**
2. Search for **"MCP Server"** and install it
3. Verify it's listening on `127.0.0.1:9876` (check the MCP Server tab)

### Step 2: Extract the Proxy JAR

1. In the **MCP Server** tab, click **"Extract server proxy jar"**
2. Save `mcp-proxy.jar` to a known location (e.g., `~/burp-mcp/`)

### Step 3: Configure Your MCP Client

Choose your client and follow the appropriate configuration:

#### Codex CLI

```toml
# ~/.codex/config.toml
[mcp_servers.burp]
command = "java"
args = ["-jar", "/absolute/path/to/mcp-proxy.jar", "--sse-url", "http://127.0.0.1:19876"]
```

Then verify:
```bash
codex
# Inside Codex: /mcp
```

#### Gemini CLI

Use the launcher helper from the burp-mcp-agents repo:
```bash
source /path/to/burp-mcp-agents/gemini-cli/burpgemini.sh
burpgemini
```

#### Ollama (Local Models)

```bash
source /path/to/burp-mcp-agents/ollama/burpollama.sh
burpollama deepseek-r1:14b
```

**Model VRAM requirements:**
- `deepseek-r1:14b` → ~16GB VRAM
- `gpt-oss:20b` → ~20GB VRAM
- `llama3.1:70b` → 48GB+ VRAM

#### Claude Desktop

Edit your config file:
- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "burp": {
      "command": "java",
      "args": ["-jar", "/path/to/mcp-proxy.jar", "--sse-url", "http://127.0.0.1:19876"]
    }
  }
}
```

### Step 4: Fix Handshake Issues (If Needed)

If you get 403 errors or strict Origin/header validation failures, use Caddy as a reverse proxy:

```bash
# Install Caddy
brew install caddy

# Create config directory
mkdir -p ~/burp-mcp

# Generate Caddyfile (or use the script)
./scripts/setup-caddy-proxy.sh

# Start the proxy
caddy run --config ~/burp-mcp/Caddyfile &
```

Then point your MCP client to `http://127.0.0.1:19876` instead of `127.0.0.1:9876`.

## Passive Vulnerability Hunting

The burp-mcp-agents repo includes prompt templates for evidence-driven analysis. Use these as starting points:

### Available Prompt Templates

| Template | Purpose |
|----------|--------|
| `passive_hunter.md` | Broad passive vulnerability surfacing |
| `idor_hunter.md` | IDOR/BOLA, object/tenant drift, auth mismatches |
| `auth_flow_mapper.md` | Compare authenticated vs unauthenticated paths |
| `ssrf_redirect_hunter.md` | SSRF/open-redirect candidates from URL params |
| `logic_flaw_hunter.md` | Multi-step logic flaws |
| `session_scope_hunter.md` | Token audience/scope misuse |
| `rate_limit_abuse_hunter.md` | Throttling/abuse gaps |
| `report_writer.md` | Evidence-focused reporting |

### Example Analysis Prompts

**IDOR Hunting:**
```
Analyze the intercepted traffic for IDOR vulnerabilities. Look for:
- Requests with user IDs, order IDs, or resource identifiers
- Missing authorization checks between different user contexts
- Inconsistent access control patterns
- Tenant isolation failures in multi-tenant apps
```

**Auth Flow Mapping:**
```
Compare authenticated vs unauthenticated request patterns. Identify:
- Endpoints accessible without authentication that shouldn't be
- Session token handling inconsistencies
- Privilege escalation opportunities
- Missing CSRF protections
```

**SSRF Detection:**
```
Search for SSRF candidates in:
- URL parameters that fetch external resources
- Redirect chains to internal addresses
- Image upload/preview endpoints
- Webhook/callback URL fields
```

## Burp AI Agent Extension

For more advanced AI-assisted triage, consider the **Burp AI Agent** extension:

### Features
- **Context-menu triage**: Right-click any request → Extensions → Burp AI Agent → Analyze
- **62 vulnerability classes** with passive/active analysis
- **53+ MCP tools** for external orchestration
- **Multiple backends**: Ollama, LM Studio, OpenAI-compatible, cloud CLIs
- **Privacy controls**: STRICT/BALANCED/OFF modes for sensitive data
- **Audit logging**: JSONL with SHA-256 integrity hashing

### Installation

```bash
git clone https://github.com/six2dez/burp-ai-agent.git
cd burp-ai-agent
JAVA_HOME=/path/to/jdk-21 ./gradlew clean shadowJar
# Load build/libs/Burp-AI-Agent-<version>.jar via Burp Extensions > Add (Java)
```

### Custom Agent Profiles

Drop custom `*.md` prompt templates into `~/.burp-ai-agent/AGENTS/` to add custom analysis behaviors.

## Safety Best Practices

1. **Prefer local models** when traffic contains sensitive data (PII, session cookies, credentials)
2. **Share minimum evidence** needed for findings - redact unnecessary sensitive data
3. **Keep Burp as source of truth** - use LLMs for analysis and reporting, not automated scanning
4. **Enable privacy mode** (STRICT/BALANCED) when using cloud backends
5. **Monitor audit logs** for tamper-evident traceability of AI/MCP actions
6. **Restrict MCP access** to trusted agents only

## Attribution Tagging

To tag Burp/LLM traffic in logs for attribution:

```text
# Add via Burp Match/Replace or proxy header rewrite
Match:   ^User-Agent: (.*)$
Replace: User-Agent: $1 BugBounty-Username
```

## Troubleshooting

### MCP Handshake Fails with 403

**Cause**: Burp's strict Origin/header validation

**Fix**: Use Caddy reverse proxy (see Step 4 above)

### Tools Not Appearing in Client

1. Verify Burp MCP Server is running on `127.0.0.1:9876`
2. Check proxy JAR path is absolute and correct
3. Run `./scripts/verify-mcp-setup.sh` to diagnose
4. Check client logs for connection errors

### Local Model Out of Memory

- Use smaller models (7B instead of 70B)
- Reduce context window if possible
- Consider cloud backends for large traffic analysis

## Scripts

Use the bundled scripts to automate common tasks:

- `scripts/setup-caddy-proxy.sh` - Generate Caddy config for handshake fixes
- `scripts/configure-codex.sh` - Set up Codex CLI with Burp MCP
- `scripts/verify-mcp-setup.sh` - Diagnose MCP connection issues

## References

- [Burp MCP + Codex CLI integration](https://pentestbook.six2dez.com/others/burp)
- [Burp MCP Agents (workflows, launchers, prompt pack)](https://github.com/six2dez/burp-mcp-agents)
- [Burp MCP Server BApp](https://portswigger.net/bappstore/9952290f04ed4f628e624d0aa9dccebc)
- [Burp AI Agent](https://github.com/six2dez/burp-ai-agent)
- [PortSwigger MCP strict Origin issue](https://github.com/PortSwigger/mcp-server/issues/34)
