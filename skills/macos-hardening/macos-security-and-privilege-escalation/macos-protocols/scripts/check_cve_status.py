#!/usr/bin/env python3
"""
macOS CVE Status Checker
Checks current macOS version against known security vulnerabilities
"""

import subprocess
import sys
from packaging import version

def get_macos_version():
    """Get current macOS version"""
    try:
        result = subprocess.run(['sw_vers', '-productVersion'], 
                              capture_output=True, text=True)
        return result.stdout.strip()
    except Exception as e:
        print(f"Error getting macOS version: {e}")
        return None

def parse_version(ver_str):
    """Parse macOS version string to comparable format"""
    try:
        parts = ver_str.split('.')
        return version.parse(f"{parts[0]}.{parts[1]}.{parts[2] if len(parts) > 2 else '0'}")
    except:
        return version.parse("0.0.0")

def check_cve_status(current_version, cve_data):
    """Check if system is vulnerable to each CVE"""
    current = parse_version(current_version)
    results = []
    
    for cve in cve_data:
        fixed_version = parse_version(cve['fixed_in'])
        is_vulnerable = current < fixed_version
        status = "VULNERABLE" if is_vulnerable else "PATCHED"
        
        results.append({
            'cve': cve['cve'],
            'year': cve['year'],
            'component': cve['component'],
            'impact': cve['impact'],
            'fixed_in': cve['fixed_in'],
            'status': status,
            'vulnerable': is_vulnerable
        })
    
    return results

def main():
    # Known macOS network security CVEs
    cve_database = [
        {
            'cve': 'CVE-2023-42940',
            'year': 2023,
            'component': 'Screen Sharing',
            'impact': 'Session rendering leak - wrong desktop transmitted',
            'fixed_in': '14.2.1'
        },
        {
            'cve': 'CVE-2024-23296',
            'year': 2024,
            'component': 'launchservicesd / login',
            'impact': 'Kernel memory bypass after remote login',
            'fixed_in': '14.4.0'
        },
        {
            'cve': 'CVE-2024-44183',
            'year': 2024,
            'component': 'mDNSResponder',
            'impact': 'DoS via crafted mDNS packet',
            'fixed_in': '14.7.0'
        },
        {
            'cve': 'CVE-2025-31222',
            'year': 2025,
            'component': 'mDNSResponder',
            'impact': 'Local privilege escalation',
            'fixed_in': '14.7.6'
        }
    ]
    
    print("=" * 60)
    print("macOS CVE Status Check")
    print("=" * 60)
    print()
    
    current_version = get_macos_version()
    if not current_version:
        print("Could not determine macOS version")
        sys.exit(1)
    
    print(f"Current macOS Version: {current_version}")
    print()
    print("-" * 60)
    print(f"{'CVE':<18} {'Component':<25} {'Status':<12}")
    print("-" * 60)
    
    results = check_cve_status(current_version, cve_database)
    vulnerable_count = 0
    
    for r in results:
        if r['vulnerable']:
            vulnerable_count += 1
        print(f"{r['cve']:<18} {r['component']:<25} {r['status']:<12}")
    
    print("-" * 60)
    print()
    
    if vulnerable_count > 0:
        print(f"⚠️  WARNING: {vulnerable_count} vulnerability(ies) detected!")
        print()
        print("Vulnerable CVEs:")
        for r in results:
            if r['vulnerable']:
                print(f"  - {r['cve']}: {r['impact']}")
                print(f"    → Update to {r['fixed_in']} or later")
        print()
        print("Run: softwareupdate -i")
    else:
        print("✓ All checked CVEs are patched")
    
    print()
    print("=" * 60)
    print("Recommendations:")
    print("=" * 60)
    print("- Enable System Integrity Protection (SIP)")
    print("- Keep macOS updated for latest security patches")
    print("- Review network services and disable unnecessary ones")
    print("=" * 60)

if __name__ == '__main__':
    main()
