#!/bin/bash
# macOS Perl Environment Security Check
# Usage: ./check-perl-env.sh

echo "=== macOS Perl Environment Security Assessment ==="
echo ""

# Check Perl version
echo "[1] Perl Version"
perl -v | head -2
echo ""

# Check dangerous environment variables
echo "[2] Dangerous Environment Variables"
echo "PERL5OPT: ${PERL5OPT:-<not set>}"
echo "PERL5LIB: ${PERL5LIB:-<not set>}"
echo "PERL5DB: ${PERL5DB:-<not set>}"
echo ""

# Check @INC paths
echo "[3] @INC Paths (module search paths)"
perl -e 'for $p (@INC) { print "  $p\n" }'
echo ""

# Check writability of @INC paths
echo "[4] Writable @INC Paths (potential injection points)"
perl -e '
  for $p (@INC) {
    if (-d $p) {
      my $writable = (-w $p) ? "[WRITABLE]" : "[read-only]";
      print "  $writable $p\n";
    }
  }
'
echo ""

# Check for taint mode
echo "[5] Taint Mode Status"
perl -e 'print "  Taint mode: " . ($^T ? "enabled" : "disabled") . "\n"'
echo ""

# Check macOS version
echo "[6] macOS Version (for CVE-2023-32369 assessment)"
sw_vers
echo ""

# Check for Perl in PATH
echo "[7] Perl Binary Location"
which perl
echo ""

# Check for suspicious Perl scripts in common locations
echo "[8] Perl Scripts in Common Locations"
for dir in /usr/local/bin /usr/bin /bin /Library/LaunchDaemons; do
  if [ -d "$dir" ]; then
    count=$(find "$dir" -name "*.pl" -o -name "*.pm" 2>/dev/null | wc -l)
    if [ "$count" -gt 0 ]; then
      echo "  $dir: $count Perl files"
    fi
  fi
done
echo ""

echo "=== Assessment Complete ==="
echo ""
echo "Security Notes:"
echo "- If PERL5OPT/PERL5LIB/PERL5DB are set, they may be exploitable"
echo "- Writable @INC paths before /System/Library are high-risk"
echo "- CVE-2023-32369 affects macOS before Ventura 13.4/Monterey 12.6.6/Big Sur 11.7.7"
