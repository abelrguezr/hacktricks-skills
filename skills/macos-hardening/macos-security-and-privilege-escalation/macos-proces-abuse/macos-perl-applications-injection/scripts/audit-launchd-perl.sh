#!/bin/bash
# Audit launchd Configurations for Perl Exposure
# Usage: ./audit-launchd-perl.sh

echo "=== launchd Perl Configuration Audit ==="
echo ""

# Check system-wide launchd
echo "[1] System LaunchDaemons"
echo ""

for plist in /Library/LaunchDaemons/*.plist; do
  if [ -f "$plist" ]; then
    # Check if plist contains Perl references
    if grep -qi "perl" "$plist" 2>/dev/null; then
      echo "Found Perl reference in: $plist"
      
      # Extract Program/ProgramArguments
      program=$(plutil -extract Program raw "$plist" 2>/dev/null)
      program_args=$(plutil -extract ProgramArguments raw "$plist" 2>/dev/null)
      
      if [ -n "$program" ]; then
        echo "  Program: $program"
      fi
      
      # Check for environment variables
      if grep -qi "PERL5OPT\|PERL5LIB\|PERL5DB" "$plist" 2>/dev/null; then
        echo "  [WARNING] Contains Perl environment variables!"
        grep -i "PERL5OPT\|PERL5LIB\|PERL5DB" "$plist"
      fi
      
      echo ""
    fi
  fi
done

# Check user launchd
echo "[2] User LaunchAgents"
echo ""

for plist in ~/Library/LaunchAgents/*.plist 2>/dev/null; do
  if [ -f "$plist" ]; then
    if grep -qi "perl" "$plist" 2>/dev/null; then
      echo "Found Perl reference in: $plist"
      
      if grep -qi "PERL5OPT\|PERL5LIB\|PERL5DB" "$plist" 2>/dev/null; then
        echo "  [WARNING] Contains Perl environment variables!"
      fi
      echo ""
    fi
  fi
done

# Check for Perl in PATH
echo "[3] Perl Binary in PATH"
perl_path=$(which perl 2>/dev/null)
echo "  Perl location: $perl_path"
echo ""

# Check for Perl scripts in launchd directories
echo "[4] Perl Scripts in Launchd Directories"
echo ""

for dir in /Library/LaunchDaemons /Library/LaunchAgents ~/Library/LaunchAgents; do
  if [ -d "$dir" ]; then
    perl_scripts=$(find "$dir" -name "*.pl" 2>/dev/null)
    if [ -n "$perl_scripts" ]; then
      echo "Perl scripts found in $dir:"
      echo "$perl_scripts" | while read -r script; do
        echo "  - $script"
      done
      echo ""
    fi
  fi
done

echo "=== Audit Complete ==="
echo ""
echo "Security Recommendations:"
echo "1. Remove PERL5OPT/PERL5LIB/PERL5DB from launchd configurations"
echo "2. Use 'env -i' to clear environment for privileged Perl processes"
echo "3. Add taint mode (-T) to all privileged Perl scripts"
echo "4. Review all Perl scripts for security issues"
