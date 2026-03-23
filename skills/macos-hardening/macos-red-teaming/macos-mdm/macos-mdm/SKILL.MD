---
name: macos-mdm-research
description: Research and analyze macOS Mobile Device Management (MDM) and Device Enrollment Program (DEP) configurations, enrollment processes, and security implications. Use this skill whenever investigating MDM implementations, analyzing device enrollment flows, researching MDM attack vectors, or documenting MDM security findings. Trigger on any mention of MDM, DEP, mobile device management, configuration profiles, SCEP, or Apple device enrollment.
---

# macOS MDM Research

A skill for researching and analyzing macOS Mobile Device Management (MDM) and Device Enrollment Program (DEP) systems.

## What this skill does

This skill helps you:
- Understand MDM/DEP architecture and enrollment flows
- Analyze MDM configuration profiles and payloads
- Research potential security implications of MDM implementations
- Document MDM-related findings for security assessments

## When to use this skill

Use this skill when:
- Investigating MDM implementations in an organization
- Analyzing device enrollment processes
- Researching MDM attack vectors or security gaps
- Documenting MDM configurations and their security implications
- Working with configuration profiles (.mobileconfig files)
- Investigating SCEP certificate enrollment
- Analyzing APNs (Apple Push Notification service) integration

## MDM/DEP Architecture

### Core Components

**MDM (Mobile Device Management)**
- Centralized control over Apple devices (iOS, macOS, tvOS)
- Requires MDM server supporting Apple's MDM Protocol
- Communication via HTTPS with plist-encoded dictionaries
- Uses APNs certificates for authentication

**DEP (Device Enrollment Program)**
- Zero-touch device enrollment automation
- Devices auto-register with MDM on first boot
- Uses OAuth tokens for MDM vendor authentication
- JSON-based (vs. plist for MDM)

**SCEP (Simple Certificate Enrollment Protocol)**
- Legacy protocol for certificate signing requests
- Pre-dates widespread TLS/HTTPS
- Standardized CSR submission method

**Configuration Profiles (.mobileconfig)**
- Apple's system configuration enforcement mechanism
- XML-based property list format
- Can be signed and encrypted
- Contains multiple payloads (MDM, SCEP, certificates, etc.)

## Enrollment Process

### 7-Step Enrollment Flow

1. **Device Record Creation** - Reseller/Apple creates device record
2. **Device Record Assignment** - Customer assigns device to MDM server
3. **Device Record Sync** - MDM vendor syncs records, pushes DEP profiles to Apple
4. **DEP Check-in** - Device retrieves activation record (DEP profile)
5. **Profile Retrieval** - Device requests profile from MDM vendor URL
6. **Profile Installation** - Profile payloads installed (MDM, SCEP, CA certs)
7. **MDM Command Listening** - Device polls for MDM commands via APNs

### Step 4: DEP Check-in Details

Triggered by:
- First boot of Mac (Setup Assistant)
- `sudo profiles show -type enrollment` command

Process:
1. Retrieve certificate from `https://iprofiles.apple.com/resource/certificate.cer`
2. Initialize state using device data (Serial Number via IOKit)
3. Retrieve session key from `https://iprofiles.apple.com/session`
4. Establish session (NACKeyEstablishment)
5. Request profile: POST to `https://iprofiles.apple.com/macProfile`
   - Payload: `{"action": "RequestProfileConfiguration", "sn": "<serial>"}`
   - Encrypted using Absinthe (NACSign)

Response includes:
- `url`: MDM vendor host for activation profile
- `anchor-certs`: DER certificates for trust validation

### Step 5: Profile Retrieval

- Request sent to URL from DEP profile
- Anchor certificates validate trust
- Request is CMS-signed, DER-encoded plist
- Signed with device identity certificate (from APNS)
- Certificate chain includes Apple iPhone Device CA

### Step 6: Profile Installation

Activation profile typically contains:
- `com.apple.mdm` - MDM enrollment payload
- `com.apple.security.scep` - Client certificate enrollment
- `com.apple.security.pem` - Trusted CA certificates

MDM payload properties:
- `CheckInURL` - MDM check-in endpoint
- `ServerURL` - Command polling URL
- `CheckInURLPinningCertificateUUIDs` - Certificate pinning
- `ServerURLPinningCertificateUUIDs` - Certificate pinning
- `IdentityCertificateUUID` - Device identity certificate

### Step 7: MDM Command Listening

- Vendor sends push notifications via APNs
- `mdmclient` handles notifications
- Device polls ServerURL for commands
- Uses pinned certificates and identity certificate

## Security Considerations

### Enrollment Security

**Risk**: Unauthorized device enrollment
- Only requires valid Serial Number from organization
- Can install sensitive data: certificates, apps, WiFi passwords, VPN configs
- Attackers can masquerade as corporate devices

**Mitigation**:
- Protect serial number lists
- Implement enrollment verification
- Monitor enrollment logs
- Use additional authentication factors

### Certificate Pinning

MDM servers can pin certificates to prevent MITM:
- `CheckInURLPinningCertificateUUIDs`
- `ServerURLPinningCertificateUUIDs`
- Delivered via PEM payload

### Serial Number Format

Post-2010 Apple devices:
- 12-character alphanumeric
- First 3: Manufacturing location
- Next 2: Year of manufacture
- Next 2: Week of manufacture
- Next 3: Unique identifier
- Last 4: Model number

## Research Tasks

### Analyzing MDM Configurations

When examining MDM setups:
1. Document all MDM server URLs and endpoints
2. Identify certificate pinning configurations
3. Map enrollment flows and dependencies
4. Review SCEP certificate enrollment settings
5. Check for proper authentication mechanisms
6. Assess profile payload contents

### Testing Enrollment Security

Consider testing:
- Serial number validation mechanisms
- Enrollment rate limiting
- Certificate validation processes
- Profile installation restrictions
- MDM command authorization

### Documentation Template

```markdown
## MDM Assessment: [Organization/System]

### Overview
- MDM Vendor: [Name]
- Server URLs: [List]
- Enrollment Method: [DEP/Manual]

### Configuration
- Certificate Pinning: [Yes/No]
- SCEP Enabled: [Yes/No]
- Profile Payloads: [List]

### Security Findings
- [Finding 1]
- [Finding 2]

### Recommendations
- [Recommendation 1]
- [Recommendation 2]
```

## References

- [Apple MDM Protocol Reference](https://developer.apple.com/enterprise/documentation/MDM-Protocol-Reference.pdf)
- [Apple DEP Guide](https://www.apple.com/business/site/docs/DEP_Guide.pdf)
- [iOS Security Guide](https://developer.apple.com/documentation/security/ios_security_guide)
- [Configuration Profile Reference](https://developer.apple.com/enterprise/documentation/Configuration-Profile-Reference.pdf)

## Related Research

- [macOS Serial Number Analysis](macos-serial-number.md)
- [Enrolling Devices in Other Organizations](enrolling-devices-in-other-organisations.md)
- [macOS Red Teaming](macos-red-teaming.md)
