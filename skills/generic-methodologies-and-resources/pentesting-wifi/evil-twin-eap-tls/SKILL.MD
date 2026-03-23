---
name: evil-twin-eap-tls
description: How to assess EAP-TLS enterprise WiFi for Evil Twin vulnerabilities. Use this skill whenever the user mentions WiFi security assessments, EAP-TLS testing, WPA2/3-Enterprise pentesting, identity leakage, TLS downgrade attacks, or rogue AP testing. This skill covers unauthenticated identity harvesting, TLS 1.3 downgrade exploitation, and Windows supplicant misconfiguration analysis.
---

# Evil Twin EAP-TLS Assessment

This skill guides security professionals through assessing EAP-TLS enterprise WiFi deployments for Evil Twin vulnerabilities. EAP-TLS is the "secure" choice for WPA2/3-Enterprise, but two practical weaknesses regularly appear during assessments:

1. **Unauthenticated identity leakage**: The outer EAP-Response/Identity is sent in cleartext before any TLS tunnel is built, so real domain usernames often leak over the air.
2. **Broken client server-validation**: If the supplicant doesn't strictly verify the RADIUS server certificate (or allows users to click through warnings), a rogue AP with a self-signed cert can still onboard victims.

## Quick Start

```bash
# Harvest EAP identities from a target network
./scripts/harvest-eap-identities.sh $IFACE $CHAN $BSSID

# Probe client TLS version tolerance
./scripts/probe-tls-versions.sh $IFACE $SSID

# Generate hostapd-wpe config for TLS 1.2 downgrade
./scripts/generate-evil-twin-config.sh --tls-version 1.2 --force-authorized
```

## Attack Methodology

### 1. Passive Identity Harvesting

EAP drives an identity exchange *before* TLS starts. If the client uses the real domain username as its outer identity, anyone in RF range can harvest it without authenticating.

**Workflow:**

1. Park on the target channel/BSSID
2. Decode EAP frames and extract identities
3. Trigger a client connection to observe the leak

**Commands:**

```bash
# Monitor the target AP
airodump-ng -i $IFACE -c $CHAN --bssid $BSSID

# Extract EAP identities from captures
tshark -i "$IFACE" -Y eap -V | grep "Identity: *[a-z]\|*[A-Z]\|*[0-9]"
```

**Impact:** Fast, no-auth username collection fuels password spraying, phishing, and account correlation. Worse when usernames match email addresses.

### 2. TLS 1.3 Downgrade Exploitation

TLS 1.3 encrypts client certs and most handshake metadata. When a supplicant *actually* negotiates TLS 1.3, an Evil Twin cannot passively learn the client certificate/identity. However, many enterprise stacks still allow TLS 1.2 for compatibility.

**RFC 9190 Warning:** A rogue AP can offer only TLS 1.2 static-RSA suites to force a fallback and re-expose the outer identity (or even the client cert) in cleartext EAP-TLS.

**Offensive Playbook:**

1. Compile hostapd-wpe with only TLS 1.2 static RSA ciphers enabled
2. Advertise the corporate SSID
3. When the victim initiates TLS 1.3, respond with a TLS alert and restart the handshake
4. The peer retries with TLS 1.2, revealing its real identity before cert validation succeeds
5. Pair with `force_authorized=1` in hostapd-wpe so the 4-way handshake completes even if client-auth fails

**Configuration for TLS 1.2 Downgrade:**

```bash
# hostapd-wpe.conf
ssl_ctx_flags=0
openssl_ciphers=RSA+AES:@SECLEVEL=0   # requires OpenSSL 1.1.1
disable_tlsv1_3=1
force_authorized=1
```

**Probe Client TLS Intolerance:**

Run two rogues:
- One advertising TLS 1.3-only (`disable_tlsv1=1`, `disable_tlsv1_1=1`, `disable_tlsv1_2=1`)
- One TLS 1.2-only

Clients that only join the 1.2 BSS are downgradeable.

**Watch for Fallback in Captures:**

Filter in Wireshark for `tls.handshake.version==0x0303` after an initial `ClientHello` with `supported_versions` containing 0x0304. Victims that retry 0x0303 are leaking their outer ID again.

### 3. Evil Twin via Broken Server Validation

Rogue APs broadcasting the corporate SSID can present any certificate. If the client doesn't validate the server cert or prompts the user and allows override of untrusted CAs/self-signed certs, then EAP-TLS stops being mutual.

**Rogue Infrastructure Setup:**

On recent Kali, compile `hostapd-wpe` using hostapd-2.6 and install legacy OpenSSL headers:

```bash
apt-get install libssl1.0-dev
# patch hostapd-wpe to set verify_peer=0 in SSL_set_verify to accept any client cert
```

A modified hostapd/hostapd-wpe that skips client-cert validation (e.g., `SSL_set_verify(..., 0)`) is enough to stand up the Evil Twin.

## Windows Supplicant Assessment

### Key Configuration Knobs

From the Windows EAP-TLS profile:

| Setting | Impact |
|---------|--------|
| **Verify the server's identity by validating the certificate** | Checked → chain must be trusted; unchecked → any self-signed cert is accepted |
| **Connect to these servers** | Empty → any cert from a trusted CA is accepted; set CN/SAN list to pin expected RADIUS names |
| **Don't prompt user to authorise new servers or trusted certification authorities** | Checked → users cannot click through; unchecked → user can trust an untrusted CA/cert and join the rogue AP |

### Observed Outcomes

| Configuration | Result |
|---------------|--------|
| **Strict validation + no prompts** | Rogue cert rejected; Windows logs an event and TLS fails (good detection signal) |
| **Validation + user prompt** | User acceptance = successful Evil Twin association |
| **No validation** | Silent Evil Twin association with any cert |

## TLS 1.3 Realities (2024-2025)

- FreeRADIUS 3.0.23+ accepts EAP-TLS 1.3, but clients still break (Windows 11 has no EAP-TLS 1.3 session resumption, Android support varies), so many deployments pin `tls_max_version = "1.2"` for stability
- Windows 11 enables EAP-TLS 1.3 by default (22H2+), yet failed resumptions and flaky RADIUS stacks often force a fallback to TLS 1.2
- RSA key exchange for TLS 1.2 is being deprecated; OpenSSL 3.x drops static-RSA suites at security level ≥2, so a TLS 1.2 static-RSA rogue needs OpenSSL 1.1.1 with `@SECLEVEL=0` or older

## Defensive Assessment Checklist

- [ ] Check if `phase1="tls_disable_tlsv1_3=0"` is enabled on clients (removes downgrade window)
- [ ] Verify Windows profiles have "Verify the server's identity" checked
- [ ] Confirm "Connect to these servers" has specific CN/SAN pins, not empty
- [ ] Ensure "Don't prompt user" is checked to prevent click-through
- [ ] Review RADIUS server TLS version configuration
- [ ] Check for TLS 1.2 static-RSA cipher usage in the environment

## References

- [EAP-TLS: The most secure option? (NCC Group)](https://www.nccgroup.com/research-blog/eap-tls-the-most-secure-option/)
- [EAP-TLS wireless infrastructure (Versprite hostapd bypass)](https://versprite.com/blog/eap-tls-wireless-infrastructure/)
- [RFC 4282 - Network Access Identifier](https://datatracker.ietf.org/doc/html/rfc4282)
- [Microsoft ServerValidationParameters (WLAN profile)](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-gpwl/0765966e-a16a-4e75-aec6-0f5f7bfbf31c)
- [RFC 9190 – EAP-TLS 1.3](https://datatracker.ietf.org/doc/rfc9190/)
- [hostapd/wpa_supplicant 2.10 release notes (TLS 1.3 EAP-TLS support)](https://lists.infradead.org/pipermail/hostap/2022-February/040204.html)
- [FreeRADIUS TLS 1.3 support thread (Nov 2024)](https://lists.freeradius.org/pipermail/freeradius-users/2024-November/104969.html)
- [Windows 11 enabling TLS 1.3 for EAP (SecurityBoulevard, Jan 2024)](https://securityboulevard.com/2024/01/windows-11-changes-you-need-to-know/)
- [draft-ietf-tls-deprecate-obsolete-kex](https://datatracker.ietf.org/doc/html/draft-ietf-tls-deprecate-obsolete-kex)
