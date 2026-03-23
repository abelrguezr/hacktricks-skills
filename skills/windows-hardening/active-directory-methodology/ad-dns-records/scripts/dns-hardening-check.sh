#!/bin/bash
# AD DNS Hardening Assessment Script
# Usage: ./dns-hardening-check.sh -d domain -u user -p password -t dc-ip

set -e

# Default values
DOMAIN=""
USERNAME=""
PASSWORD=""
TARGET_IP=""
OUTPUT_FILE="dns-hardening-report.md"

# Parse arguments
while getopts "d:u:p:t:o:" opt; do
  case $opt in
    d) DOMAIN="$OPTARG" ;;
    u) USERNAME="$OPTARG" ;;
    p) PASSWORD="$OPTARG" ;;
    t) TARGET_IP="$OPTARG" ;;
    o) OUTPUT_FILE="$OPTARG" ;;
    *) echo "Usage: $0 -d domain -u user -p password -t dc-ip [-o output_file]"; exit 1 ;;
  esac
done

# Validate required arguments
if [[ -z "$DOMAIN" || -z "$USERNAME" || -z "$PASSWORD" || -z "$TARGET_IP" ]]; then
  echo "Error: Missing required arguments"
  echo "Usage: $0 -d domain -u user -p password -t dc-ip [-o output_file]"
  exit 1
fi

# Start report
cat > "$OUTPUT_FILE" << 'EOF'
# AD DNS Hardening Assessment Report

**Generated:** $(date)
**Assessor:** Automated DNS Hardening Check

## Executive Summary

This report assesses the security posture of Active Directory DNS infrastructure.

## Findings

EOF

echo "[*] Starting DNS hardening assessment..."
echo "[*] Target: $TARGET_IP"
echo "[*] Domain: $DOMAIN"

# Check 1: DNS Server Version
echo ""
echo "## 1. DNS Server Version"
echo ""
echo "[*] Checking DNS server version..."
if command -v nslookup &> /dev/null; then
  VERSION_OUTPUT=$(nslookup -version $TARGET_IP 2>&1 || echo "Version query not supported")
  echo "DNS Server Response: $VERSION_OUTPUT" >> "$OUTPUT_FILE"
else
  echo "[!] nslookup not available, skipping version check" >> "$OUTPUT_FILE"
fi

# Check 2: Zone Transfer Test
echo ""
echo "## 2. Zone Transfer Test"
echo ""
echo "[*] Testing for unauthorized zone transfers..."
if command -v dig &> /dev/null; then
  ZT_OUTPUT=$(dig @${TARGET_IP} axfr ${DOMAIN} 2>&1 || echo "Zone transfer denied or failed")
  if echo "$ZT_OUTPUT" | grep -q "transfer failed"; then
    echo "✅ Zone transfer properly restricted" >> "$OUTPUT_FILE"
  else
    echo "⚠️ WARNING: Zone transfer may be allowed" >> "$OUTPUT_FILE"
    echo "$ZT_OUTPUT" >> "$OUTPUT_FILE"
  fi
else
  echo "[!] dig not available, skipping zone transfer test" >> "$OUTPUT_FILE"
fi

# Check 3: Common Attack Vectors
echo ""
echo "## 3. Common Attack Vector Checks"
echo ""

# Check for WPAD
echo "[*] Checking for WPAD record..."
if command -v dig &> /dev/null; then
  WPAD_OUTPUT=$(dig @${TARGET_IP} wpad.${DOMAIN} 2>&1 || echo "No WPAD record")
  if echo "$WPAD_OUTPUT" | grep -q "status: NOERROR"; then
    echo "⚠️ WARNING: WPAD record exists - potential credential harvesting risk" >> "$OUTPUT_FILE"
  else
    echo "✅ No WPAD record found" >> "$OUTPUT_FILE"
  fi
fi

# Check for ISATAP
echo "[*] Checking for ISATAP record..."
if command -v dig &> /dev/null; then
  ISATAP_OUTPUT=$(dig @${TARGET_IP} isatap.${DOMAIN} 2>&1 || echo "No ISATAP record")
  if echo "$ISATAP_OUTPUT" | grep -q "status: NOERROR"; then
    echo "⚠️ WARNING: ISATAP record exists - potential tunneling risk" >> "$OUTPUT_FILE"
  else
    echo "✅ No ISATAP record found" >> "$OUTPUT_FILE"
  fi
fi

# Check 4: DNSSEC Status
echo ""
echo "## 4. DNSSEC Status"
echo ""
echo "[*] Checking DNSSEC signing..."
if command -v dig &> /dev/null; then
  DNSSEC_OUTPUT=$(dig @${TARGET_IP} ${DOMAIN} dnskey 2>&1 || echo "DNSKEY query failed")
  if echo "$DNSSEC_OUTPUT" | grep -q "DNSKEY"; then
    echo "✅ DNSSEC appears to be configured" >> "$OUTPUT_FILE"
  else
    echo "⚠️ DNSSEC not configured (optional for internal AD)" >> "$OUTPUT_FILE"
  fi
fi

# Check 5: Known Vulnerabilities
echo ""
echo "## 5. Known Vulnerability Status"
echo ""
cat >> "$OUTPUT_FILE" << 'EOF'
### Critical CVEs to Check

| CVE | Description | CVSS | Status |
|-----|-------------|------|--------|
| CVE-2024-26224 | DNS Server RCE | 9.8 | ⚠️ Check patch level |
| CVE-2024-26231 | DNS Server RCE | 9.8 | ⚠️ Check patch level |
| CVE-2022-26923 | Certifried | 8.1 | ⚠️ Check patch level |
| CVE-2018-8320 | WPAD Bypass | 7.5 | ⚠️ Check patch level |

**Action Required:** Verify DNS server patch level against these CVEs.

EOF

# Recommendations
echo ""
echo "## 6. Hardening Recommendations"
echo ""
cat >> "$OUTPUT_FILE" << 'EOF'
### Immediate Actions

1. **Set zones to Secure-only dynamic updates**
   - Prevents unauthenticated DNS record creation
   - Requires proper DHCP integration

2. **Enable Name Protection in DHCP**
   - Only owner can update their own records
   - Prevents record hijacking

3. **Block dangerous names**
   - wpad, isatap, *, ms-wpad
   - Use Global Query Block List

4. **Monitor DNS events**
   - Event IDs: 257, 252, 770
   - LDAP writes to CN=MicrosoftDNS

5. **Keep DNS servers patched**
   - Critical RCE vulnerabilities exist
   - Establish regular patching schedule

### Long-term Improvements

- Implement DNS query logging
- Consider DNSSEC for critical zones
- Audit DNS zone permissions quarterly
- Deploy DNS monitoring/solution

EOF

echo ""
echo "=== Assessment Complete ==="
echo "Report saved to: $OUTPUT_FILE"
echo ""
echo "Review the report and address any findings marked with ⚠️"
