---
name: expose-local-services
description: Expose local HTTP/TCP services to the internet using tunneling tools. Use this skill whenever you need to make a local service accessible from the internet - for testing, demos, red teaming, or development. Covers free options (Serveo, Localtunnel, Cloudflare Quick Tunnels), paid options (Ngrok TCP, LocalXpose Pro), and self-hosted solutions (FRP).
---

# Expose Local Services to the Internet

This skill helps you expose local HTTP and TCP services to the internet using various tunneling tools. Choose the right tool based on your needs.

## Quick Selection Guide

| Use Case | Recommended Tool |
|----------|------------------|
| Quick HTTP demo (free) | Serveo, Localtunnel, Cloudflare Quick Tunnel |
| Quick TCP demo (free) | Serveo, Pinggy |
| Persistent HTTP/TCP | Cloudflare Named Tunnel, Tailscale Funnel |
| Self-hosted control | FRP |
| Behind captive proxy | Pinggy (SSH over 443) |
| Within tailnet only | Tailscale Serve |

## Tool Commands

### Serveo (Free, SSH-based)

From https://serveo.net/

```bash
# Random HTTPS URL for local port 4444
ssh -R 0:localhost:4444 serveo.net

# Expose web on port 3000
ssh -R 80:localhost:3000 serveo.net
```

### Localtunnel (Free, HTTP only)

From https://github.com/localtunnel/localtunnel

```bash
# Expose web on port 8000
npx localtunnel --port 8000
```

### Cloudflare Tunnel (Free)

Cloudflare's `cloudflared` CLI supports both quick anonymous tunnels and named tunnels bound to your domain.

**Quick Tunnel (ephemeral, random subdomain):**
```bash
# Expose localhost:8080
cloudflared tunnel --url http://localhost:8080
```

**Named Tunnel (persistent, custom domain):**
```bash
# One-time device authentication
cloudflared tunnel login

# Create and configure tunnel
cloudflared tunnel create my-tunnel
cloudflared tunnel route dns my-tunnel app.example.com
cloudflared tunnel run my-tunnel --config tunnel.yml
```

Named tunnels support multiple ingress rules (HTTP, SSH, RDP), per-service access policies via Cloudflare Access, and can run as systemd containers for persistence.

### Tailscale Funnel / Serve (Free)

Tailscale v1.52+ provides `tailscale serve` (tailnet-only) and `tailscale funnel` (public internet).

```bash
# Share localhost:3000 within the tailnet
sudo tailscale serve 3000

# Publish publicly on port 443 with Funnel
sudo tailscale funnel --https=443 localhost:3000

# Forward raw TCP (expose local SSH)
sudo tailscale funnel --tcp=10000 tcp://localhost:22
```

Use `--bg` to persist configuration without keeping a foreground process. Check status with `tailscale funnel status`.

### FRP (Self-hosted)

`frp` is ideal when you control a VPS and want deterministic domains/ports.

**Server (frps):**
```bash
./frps -c frps.toml
```

**Client (frpc):**
```bash
./frpc -c <<'EOF'
serverAddr = "c2.example.com"
serverPort = 7000

[[proxies]]
name = "ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 6000

[[proxies]]
name = "panel"
type = "http"
localPort = 8080
customDomains = ["panel.example.com"]
EOF
```

Recent releases add QUIC transport, token/OIDC auth, bandwidth caps, and health checks.

### Pinggy (Free, SSH over 443)

Works behind captive proxies that only allow HTTPS. Sessions last 60 minutes on free tier.

```bash
# Random subdomain exposing localhost:3000
ssh -p 443 -R0:localhost:3000 a.pinggy.io
```

### Ngrok (Free/Paid)

From https://ngrok.com/

```bash
# Expose web on port 8000 (free)
ngrok http 8000

# Expose TCP port 9000 (requires credit card, but won't be charged)
ngrok tcp 9000
```

### LocalXpose (Free/Paid)

From https://localxpose.io/

```bash
# Expose web on port 8989 (free)
loclx tunnel http -t 8989

# Expose TCP port 4545 (requires Pro)
loclx tunnel tcp --port 4545
```

### Expose (Free/Paid)

From https://expose.dev/

```bash
# Expose web on port 3000 (free)
./expose share http://localhost:3000

# Expose TCP port 4444 (requires Premium)
./expose share-port 4444
```

### Telebit (Free/Paid)

From https://telebit.cloud/

```bash
# Expose web on port 3000
/Users/username/Applications/telebit/bin/telebit http 3000

# Expose TCP port 9000
/Users/username/Applications/telebit/bin/telebit tcp 9000
```

### SocketXP (Free/Paid)

From https://www.socketxp.com/download

```bash
# Expose TCP port 22
socketxp connect tcp://localhost:22

# Expose HTTP port 8080
socketxp connect http://localhost:8080
```

## OPSEC Considerations

Adversaries have increasingly abused ephemeral tunneling (especially Cloudflare's unauthenticated `trycloudflare.com` endpoints) to stage RAT payloads and hide C2 infrastructure. Since February 2024, campaigns have used these tunnels to deliver AsyncRAT, Xworm, VenomRAT, GuLoader, and Remcos.

**Best practices:**
- Rotate tunnels and domains proactively
- Monitor for external DNS lookups to your tunneler to detect blue-team blocking
- Use custom domains for persistent operations
- Be aware that free tiers may have rate limits or uptime restrictions
- Self-hosted solutions give you full control but require maintenance

## References

- [Cloudflare Docs - Create a locally-managed tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/do-more-with-tunnels/local-management/create-local-tunnel/)
- [Proofpoint - Threat Actor Abuses Cloudflare Tunnels to Deliver RATs](https://www.proofpoint.com/us/blog/threat-insight/threat-actor-abuses-cloudflare-tunnels-deliver-rats)
