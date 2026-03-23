---
name: network-protocols-reference
description: Network protocol reference for security testing, network analysis, and troubleshooting. Use this skill whenever the user asks about network protocols, service discovery mechanisms, authentication protocols, or needs to understand how protocols like mDNS, DNS-SD, SSDP, WSD, OAuth 2.0, RADIUS, SMB, NetBIOS, LDAP, or Active Directory work. Trigger for protocol enumeration, network reconnaissance, service discovery analysis, or when explaining protocol behavior in security contexts.
---

# Network Protocols Reference

A comprehensive reference for network protocols commonly encountered in security testing, network analysis, and system administration.

## When to Use This Skill

Use this skill when you need to:
- Understand how a specific network protocol works
- Identify which protocols are running on a network during reconnaissance
- Analyze service discovery mechanisms (mDNS, DNS-SD, SSDP, WSD)
- Understand authentication and directory protocols (OAuth 2.0, RADIUS, LDAP, AD)
- Explain protocol behavior for security assessments
- Troubleshoot network connectivity issues related to specific protocols

## Service Discovery Protocols

### Multicast DNS (mDNS)

**Purpose**: IP address resolution within small, local networks without a dedicated name server.

**How it works**:
- Multicasts a query within the subnet
- Host with the specified name responds with its IP address
- All devices in the subnet update their mDNS caches

**Key characteristics**:
- **Domain suffix**: `.local` only
- **Port**: UDP 5353
- **IPv4 multicast**: `224.0.0.251`
- **IPv6 multicast**: `ff02::fb`
- **Ethernet MAC (IPv4)**: `01:00:5E:00:00:FB`
- **Ethernet MAC (IPv6)**: `33:33:00:00:00:FB`
- **Scope**: Confined to local network, does not cross routers

**Special behavior**:
- **Domain Name Relinquishment**: Host releases domain name by sending packet with TTL of zero
- **Conflict handling**: Conflicts with non-mDNS hosts in `.local` domain require network configuration adjustments

**Security testing considerations**:
- mDNS traffic is visible to all devices on the subnet
- Can reveal hostnames and IP addresses of devices
- Useful for network reconnaissance in local environments

### DNS-SD (DNS Service Discovery)

**Purpose**: Discovering services on a network by querying specific domain names.

**How it works**:
- Queries specific service type domains (e.g., `_printers._tcp.local`)
- Response includes all related domains and available services

**Common service types**:
- `_printers._tcp.local` - Printers
- `_http._tcp.local` - Web services
- `_ssh._tcp.local` - SSH services
- `_smb._tcp.local` - SMB file sharing

**Security testing considerations**:
- Reveals available services on the network
- Can enumerate service types without direct probing
- Often used in conjunction with mDNS

### SSDP (Simple Service Discovery Protocol)

**Purpose**: Discovery of network services, primarily used by UPnP.

**How it works**:
- Text-based protocol using UDP
- Uses multicast addressing
- Built on HTTPU (HTTP over UDP)

**Key characteristics**:
- **Port**: UDP 1900
- **IPv4 multicast**: `239.255.255.250`
- **Protocol foundation**: HTTPU (HTTP over UDP)

**Security testing considerations**:
- UPnP devices often have security vulnerabilities
- SSDP can reveal device types and capabilities
- Common target for network reconnaissance
- Can be used to discover IoT devices

### Web Service for Devices (WSD)

**Purpose**: Identify available services on a network (e.g., printers).

**How it works**:
- Devices broadcast UDP packets
- Service seekers send requests
- Service providers announce their offerings

**Security testing considerations**:
- Can enumerate network services
- Often used in enterprise environments
- May reveal sensitive service information

## Authentication and Authorization Protocols

### OAuth 2.0

**Purpose**: Secure, selective sharing of user information between services.

**How it works**:
1. User authenticates with authorization server
2. User grants authorization to the client service
3. Authorization server generates access token
4. Client service uses token to access specified user data

**Common use cases**:
- "Sign in with Google" / "Sign in with Facebook"
- API access delegation
- Third-party service integration

**Security testing considerations**:
- Token handling and storage
- Scope validation
- Authorization code flow security
- Token expiration and refresh mechanisms

### RADIUS (Remote Authentication Dial-In User Service)

**Purpose**: Network access protocol for authentication, authorization, and accounting.

**How it works**:
- User credentials verified by RADIUS server
- May include network address verification
- Post-authentication: network access granted
- Session details tracked for billing and statistics

**Key characteristics**:
- **Primary users**: ISPs, enterprise networks
- **Functions**: AAA (Authentication, Authorization, Accounting)
- **Common ports**: UDP 1812 (authentication), UDP 1813 (accounting)

**Security testing considerations**:
- Credential handling
- Shared secret security
- Accounting data integrity
- Replay attack prevention

## File Sharing and Session Protocols

### SMB (Server Message Block)

**Purpose**: Sharing files, printers, and ports.

**How it works**:
- Operates directly over TCP or via NetBIOS over TCP
- Dual compatibility enhances connectivity with various devices

**Key characteristics**:
- **Direct TCP**: Port 445
- **NetBIOS over TCP**: Ports 137, 138
- **Common in**: Windows environments, file servers

**Security testing considerations**:
- SMBv1 is deprecated and vulnerable
- Common target for lateral movement
- Check for SMB signing enforcement
- Enumerate shares and permissions

### NetBIOS (Network Basic Input/Output System)

**Purpose**: Manages network sessions and connections for resource sharing.

**How it works**:
- Supports unique names for devices
- Supports group names for multiple devices
- Enables targeted or broadcast messaging
- Communication modes: connectionless (no acknowledgment) or connection-oriented (session-based)

**Key characteristics**:
- **Traditional protocols**: IPC/IPX
- **Common usage**: TCP/IP
- **Associated protocol**: NetBEUI (fast but verbose due to broadcasting)

**Security testing considerations**:
- NetBIOS name enumeration
- Can reveal system names and user information
- Often disabled in modern security configurations

## Directory and Identity Protocols

### LDAP (Lightweight Directory Access Protocol)

**Purpose**: Management and access of directory information over TCP/IP.

**How it works**:
- Supports various operations for querying and modifying directory information
- Interacts with databases designed for LDAP communication

**Key characteristics**:
- **Primary use**: Distributed directory information services
- **Common ports**: TCP 389 (unencrypted), TCP 636 (LDAPS)
- **Operations**: Search, modify, add, delete directory entries

**Security testing considerations**:
- Anonymous bind vulnerabilities
- LDAP injection attacks
- Information disclosure through enumeration
- Certificate validation for LDAPS

### Active Directory (AD)

**Purpose**: Network-accessible database for centralized management of network entities.

**How it works**:
- Contains objects: users, groups, privileges, resources
- Hierarchical structure of domains
- Subdomains allow further segmentation
- Each subdomain may maintain its own server and user base

**Key characteristics**:
- **Centralized management**: User access to network resources
- **Query capabilities**: Retrieve contact details, locate resources
- **Structure**: Domains, subdomains, organizational units

**Security testing considerations**:
- Kerberos authentication security
- Group Policy Object (GPO) analysis
- Privilege escalation paths
- Lateral movement opportunities
- Password policy enforcement

## Protocol Quick Reference Table

| Protocol | Primary Port(s) | Transport | Purpose |
|----------|----------------|-----------|----------|
| mDNS | UDP 5353 | UDP | Local name resolution |
| DNS-SD | UDP 5353 | UDP | Service discovery |
| SSDP | UDP 1900 | UDP | UPnP service discovery |
| WSD | UDP (varies) | UDP | Device service discovery |
| RADIUS | UDP 1812/1813 | UDP | AAA for network access |
| SMB | TCP 445 | TCP | File/print sharing |
| NetBIOS | TCP 137-139 | TCP | Session management |
| LDAP | TCP 389/636 | TCP | Directory services |
| OAuth 2.0 | TCP 443 | TCP/HTTPS | Authorization |

## Common Security Testing Scenarios

### Network Reconnaissance
1. **mDNS enumeration**: Scan for `.local` hosts on the subnet
2. **SSDP discovery**: Query `239.255.255.250:1900` for UPnP devices
3. **SMB enumeration**: Check ports 445, 137-139 for file shares
4. **LDAP enumeration**: Query port 389 for directory information

### Service Discovery Analysis
1. **DNS-SD queries**: Request specific service types to enumerate services
2. **WSD monitoring**: Capture broadcast packets for service announcements
3. **Protocol fingerprinting**: Identify services by their protocol behavior

### Authentication Testing
1. **RADIUS testing**: Verify authentication flow and accounting
2. **OAuth 2.0 validation**: Test token handling and scope enforcement
3. **AD security**: Assess Kerberos and LDAP security configurations

## Troubleshooting Tips

- **mDNS not working**: Check firewall rules for UDP 5353, verify `.local` domain configuration
- **SSDP discovery failing**: Ensure UDP 1900 is open, check multicast routing
- **SMB connectivity issues**: Verify ports 445 or 137-139, check NetBIOS configuration
- **LDAP queries failing**: Check port 389/636, verify bind credentials and permissions
- **AD authentication problems**: Verify Kerberos configuration, check time synchronization

## Best Practices

1. **Disable unnecessary protocols**: Turn off NetBIOS, SMBv1, and other legacy protocols when not needed
2. **Use encrypted variants**: Prefer LDAPS over LDAP, SMB signing enabled
3. **Segment networks**: Isolate service discovery traffic to appropriate VLANs
4. **Monitor protocol traffic**: Watch for unusual mDNS, SSDP, or LDAP activity
5. **Keep services updated**: Regularly patch SMB, LDAP, and other protocol implementations
