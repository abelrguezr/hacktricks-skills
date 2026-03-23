#!/bin/bash
# CVE-2023-32369 "Migraine" Vulnerability Check
# Usage: ./check-migraine-vuln.sh

echo "=== CVE-2023-32369 (Migraine) Vulnerability Assessment ==="
echo ""

# Get macOS version
MACOS_VERSION=$(sw_vers -productVersion)
MAJOR=$(echo "$MACOS_VERSION" | cut -d. -f1)
MINOR=$(echo "$MACOS_VERSION" | cut -d. -f2)
PATCH=$(echo "$MACOS_VERSION" | cut -d. -f3)

echo "Current macOS Version: $MACOS_VERSION"
echo ""

# Check for vulnerable versions
echo "[1] Version Check"

is_vulnerable=false

# Ventura 13.x - vulnerable before 13.4
if [ "$MAJOR" -eq 13 ]; then
  if [ "$MINOR" -lt 4 ]; then
    is_vulnerable=true
    echo "  [VULNERABLE] Ventura $MACOS_VERSION is before 13.4"
  else
    echo "  [PATCHED] Ventura $MACOS_VERSION is 13.4 or later"
  fi
# Monterey 12.x - vulnerable before 12.6.6
elif [ "$MAJOR" -eq 12 ]; then
  if [ "$MINOR" -lt 6 ]; then
    is_vulnerable=true
    echo "  [VULNERABLE] Monterey $MACOS_VERSION is before 12.6"
  elif [ "$MINOR" -eq 6 ] && [ "$PATCH" -lt 6 ]; then
    is_vulnerable=true
    echo "  [VULNERABLE] Monterey $MACOS_VERSION is before 12.6.6"
  else
    echo "  [PATCHED] Monterey $MACOS_VERSION is 12.6.6 or later"
  fi
# Big Sur 11.x - vulnerable before 11.7.7
elif [ "$MAJOR" -eq 11 ]; then
  if [ "$MINOR" -lt 7 ]; then
    is_vulnerable=true
    echo "  [VULNERABLE] Big Sur $MACOS_VERSION is before 11.7"
  elif [ "$MINOR" -eq 7 ] && [ "$PATCH" -lt 7 ]; then
    is_vulnerable=true
    echo "  [VULNERABLE] Big Sur $MACOS_VERSION is before 11.7.7"
  else
    echo "  [PATCHED] Big Sur $MACOS_VERSION is 11.7.7 or later"
  fi
else
  echo "  [UNKNOWN] macOS $MAJOR.x - check Apple security updates"
fi

echo ""

# Check for systemmigrationd
echo "[2] systemmigrationd Daemon Check"
if pgrep -x "systemmigrationd" > /dev/null 2>&1; then
  echo "  [ACTIVE] systemmigrationd is currently running"
  pid=$(pgrep -x "systemmigrationd")
  echo "  PID: $pid"
else
  echo "  [INACTIVE] systemmigrationd is not currently running"
fi
echo ""

# Check for Migration Assistant
echo "[3] Migration Assistant Check"
if [ -d "/Applications/Migration\ Assistant.app" ]; then
  echo "  [PRESENT] Migration Assistant.app exists"
else
  echo "  [ABSENT] Migration Assistant.app not found"
fi
echo ""

# Check for vulnerable Perl invocation
echo "[4] Perl in systemmigrationd Context"
echo "  Note: systemmigrationd spawns /usr/bin/perl with inherited entitlements"
echo "  If PERL5OPT is poisoned, code executes outside SIP restrictions"
echo ""

# Summary
echo "=== Vulnerability Summary ==="
if [ "$is_vulnerable" = true ]; then
  echo "[VULNERABLE] This system may be affected by CVE-2023-32369"
  echo ""
  echo "Recommendations:"
  echo "1. Update macOS to the latest version"
  echo "2. Clear PERL5OPT from launchd environment: launchctl unsetenv PERL5OPT"
  echo "3. Monitor systemmigrationd activity"
  echo "4. Review all Perl scripts run as root"
else
  echo "[PATCHED] This system appears to have the CVE-2023-32369 fix"
  echo ""
  echo "Continue monitoring for new vulnerabilities."
fi

echo ""
echo "=== Assessment Complete ==="
