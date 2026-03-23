#!/usr/bin/env python3
"""
ld.so Privilege Escalation Vulnerability Checker

This script checks for ld.so library path vulnerabilities that could
allow privilege escalation through malicious library injection.
"""

import os
import sys
import subprocess
import stat
from pathlib import Path
from typing import List, Tuple, Optional


def check_path_writable(path: str) -> Tuple[bool, str]:
    """Check if a path is writable by the current user."""
    if not os.path.exists(path):
        return False, "Path does not exist"
    
    try:
        st = os.stat(path)
        is_writable = os.access(path, os.W_OK)
        owner = st.st_uid
        mode = stat.filemode(st.st_mode)
        
        if is_writable:
            return True, f"Writable (mode: {mode}, owner: {owner})"
        else:
            return False, f"Not writable (mode: {mode}, owner: {owner})"
    except Exception as e:
        return False, f"Error checking: {e}"


def parse_ldso_conf(filepath: str) -> List[str]:
    """Parse an ld.so configuration file and return library paths."""
    paths = []
    
    if not os.path.exists(filepath):
        return paths
    
    try:
        with open(filepath, 'r') as f:
            for line in f:
                line = line.strip()
                # Skip comments and empty lines
                if not line or line.startswith('#'):
                    continue
                # Skip 'include' directives (handle separately)
                if line.startswith('include '):
                    include_path = line[8:].strip()
                    # Expand wildcards
                    if '*' in include_path:
                        for included in Path(include_path).parent.glob(include_path.replace('/*', '*')):
                            paths.extend(parse_ldso_conf(str(included)))
                    else:
                        paths.extend(parse_ldso_conf(include_path))
                else:
                    # Regular path entry
                    paths.append(line)
    except Exception as e:
        print(f"Warning: Could not read {filepath}: {e}")
    
    return paths


def check_ldso_config() -> List[dict]:
    """Check /etc/ld.so.conf and /etc/ld.so.conf.d/ for vulnerabilities."""
    results = []
    
    # Check main config file
    main_conf = '/etc/ld.so.conf'
    if os.path.exists(main_conf):
        paths = parse_ldso_conf(main_conf)
        for path in paths:
            writable, status = check_path_writable(path)
            results.append({
                'source': main_conf,
                'path': path,
                'writable': writable,
                'status': status,
                'risk': 'HIGH' if writable else 'LOW'
            })
    
    # Check config.d directory
    conf_d = '/etc/ld.so.conf.d/'
    if os.path.exists(conf_d):
        for filename in os.listdir(conf_d):
            filepath = os.path.join(conf_d, filename)
            if os.path.isfile(filepath):
                paths = parse_ldso_conf(filepath)
                for path in paths:
                    writable, status = check_path_writable(path)
                    results.append({
                        'source': filepath,
                        'path': path,
                        'writable': writable,
                        'status': status,
                        'risk': 'HIGH' if writable else 'LOW'
                    })
    
    return results


def check_binary_libraries(binary_path: str) -> List[dict]:
    """Check which libraries a binary loads and where from."""
    results = []
    
    if not os.path.exists(binary_path):
        print(f"Error: Binary not found: {binary_path}")
        return results
    
    try:
        # Run ldd to get library dependencies
        result = subprocess.run(['ldd', binary_path], capture_output=True, text=True)
        lines = result.stdout.strip().split('\n')
        
        for line in lines:
            line = line.strip()
            if '=>' in line:
                parts = line.split('=>')
                lib_name = parts[0].strip()
                lib_path = parts[1].split()[0] if len(parts[1].split()) > 0 else 'not found'
                
                # Check if path is in a potentially dangerous location
                risk = 'LOW'
                if lib_path in ['not found']:
                    risk = 'MEDIUM'
                elif any(dangerous in lib_path for dangerous in ['/tmp/', '/home/', '/var/tmp/', '/opt/']):
                    risk = 'HIGH'
                
                results.append({
                    'library': lib_name,
                    'path': lib_path,
                    'risk': risk
                })
    except Exception as e:
        print(f"Error running ldd: {e}")
    
    return results


def check_ldconfig_sudo() -> dict:
    """Check if ldconfig can be run with sudo privileges."""
    result = {
        'can_run_sudo': False,
        'has_suid': False,
        'risk': 'LOW',
        'details': []
    }
    
    # Check sudo privileges
    try:
        sudo_result = subprocess.run(['sudo', '-l'], capture_output=True, text=True)
        if 'ldconfig' in sudo_result.stdout:
            result['can_run_sudo'] = True
            result['risk'] = 'MEDIUM'
            result['details'].append('ldconfig found in sudoers')
    except Exception as e:
        result['details'].append(f'Could not check sudo: {e}')
    
    # Check for SUID bit
    ldconfig_path = '/sbin/ldconfig'
    if os.path.exists(ldconfig_path):
        try:
            st = os.stat(ldconfig_path)
            if st.st_mode & stat.S_ISUID:
                result['has_suid'] = True
                result['risk'] = 'HIGH'
                result['details'].append('ldconfig has SUID bit set')
        except Exception as e:
            result['details'].append(f'Could not check SUID: {e}')
    
    return result


def print_results(title: str, results: List[dict], risk_filter: str = None):
    """Print results in a formatted table."""
    print(f"\n{'='*60}")
    print(f"{title}")
    print(f"{'='*60}")
    
    if not results:
        print("No results found.")
        return
    
    # Filter by risk if specified
    if risk_filter:
        results = [r for r in results if r.get('risk') == risk_filter]
    
    # Print table header
    if 'source' in results[0]:
        print(f"{'Source':<40} {'Path':<30} {'Risk':<10} {'Status'}")
        print("-" * 100)
        for r in results:
            print(f"{r['source']:<40} {r['path']:<30} {r['risk']:<10} {r['status']}")
    elif 'library' in results[0]:
        print(f"{'Library':<30} {'Path':<40} {'Risk':<10}")
        print("-" * 80)
        for r in results:
            print(f"{r['library']:<30} {r['path']:<40} {r['risk']:<10}")
    
    # Summary
    high_risk = sum(1 for r in results if r.get('risk') == 'HIGH')
    medium_risk = sum(1 for r in results if r.get('risk') == 'MEDIUM')
    print(f"\nSummary: {high_risk} HIGH, {medium_risk} MEDIUM risk findings")


def main():
    """Main entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(
        description='Check for ld.so privilege escalation vulnerabilities'
    )
    parser.add_argument(
        '--binary', '-b',
        help='Analyze library dependencies for a specific binary'
    )
    parser.add_argument(
        '--check-ldconfig-sudo',
        action='store_true',
        help='Check if ldconfig can be exploited via sudo'
    )
    parser.add_argument(
        '--show-all',
        action='store_true',
        help='Show all findings, not just high risk'
    )
    parser.add_argument(
        '--json',
        action='store_true',
        help='Output results as JSON'
    )
    
    args = parser.parse_args()
    
    all_results = []
    
    # Check ld.so configuration (always run this)
    config_results = check_ldso_config()
    all_results.append({
        'check': 'ldso_configuration',
        'results': config_results
    })
    
    # Check specific binary if requested
    if args.binary:
        binary_results = check_binary_libraries(args.binary)
        all_results.append({
            'check': f'binary_{args.binary}',
            'results': binary_results
        })
    
    # Check ldconfig sudo if requested
    if args.check_ldconfig_sudo:
        ldconfig_result = check_ldconfig_sudo()
        all_results.append({
            'check': 'ldconfig_sudo',
            'results': [ldconfig_result]
        })
    
    # Output results
    if args.json:
        import json
        print(json.dumps(all_results, indent=2))
    else:
        for check in all_results:
            if check['check'] == 'ldso_configuration':
                print_results(
                    'ld.so Configuration Vulnerability Check',
                    check['results'],
                    risk_filter='HIGH' if not args.show_all else None
                )
            elif check['check'] == 'ldconfig_sudo':
                result = check['results'][0]
                print(f"\n{'='*60}")
                print(f"ldconfig Sudo Privilege Check")
                print(f"{'='*60}")
                print(f"Can run with sudo: {result['can_run_sudo']}")
                print(f"Has SUID bit: {result['has_suid']}")
                print(f"Risk level: {result['risk']}")
                print(f"Details: {'; '.join(result['details'])}")
            elif check['check'].startswith('binary_'):
                binary_name = check['check'].replace('binary_', '')
                print_results(
                    f'Library Dependencies for {binary_name}',
                    check['results'],
                    risk_filter='HIGH' if not args.show_all else None
                )
    
    # Return exit code based on findings
    high_risk_count = sum(
        1 for check in all_results 
        for r in check['results'] 
        if r.get('risk') == 'HIGH'
    )
    
    if high_risk_count > 0:
        print(f"\n⚠️  WARNING: Found {high_risk_count} HIGH risk vulnerability(ies)!")
        return 1
    else:
        print("\n✓ No high-risk vulnerabilities found.")
        return 0


if __name__ == '__main__':
    sys.exit(main())
