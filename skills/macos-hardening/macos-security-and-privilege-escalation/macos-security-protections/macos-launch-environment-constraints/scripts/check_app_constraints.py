#!/usr/bin/env python3
"""
Check environment constraints on macOS applications.

Usage:
    python3 check_app_constraints.py /path/to/app.app

This script uses codesign to extract and display launch constraints
configured for third-party applications.
"""

import subprocess
import sys
import json
from pathlib import Path


def run_codesign(app_path: str) -> str:
    """
    Run codesign to get app information including launch constraints.
    """
    try:
        result = subprocess.run(
            ['codesign', '-d', '-vvvv', app_path],
            capture_output=True,
            text=True,
            timeout=30
        )
        return result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        print(f"Error: codesign timed out for {app_path}")
        return ""
    except FileNotFoundError:
        print("Error: codesign not found. Is this running on macOS?")
        return ""
    except Exception as e:
        print(f"Error running codesign: {e}")
        return ""


def parse_launch_constraints(output: str) -> dict:
    """
    Parse launch constraints from codesign output.
    """
    constraints = {
        'found': False,
        'self_constraint': None,
        'parent_constraint': None,
        'responsible_constraint': None,
        'library_constraint': None,
        'raw_output': None
    }
    
    # Look for launch constraints section
    lines = output.split('\n')
    in_constraints = False
    current_section = None
    
    for line in lines:
        line = line.strip()
        
        if 'Launch Constraints' in line:
            in_constraints = True
            constraints['found'] = True
            continue
        
        if in_constraints:
            if line.startswith('Self Constraint:'):
                current_section = 'self'
                constraints['self_constraint'] = line.replace('Self Constraint:', '').strip()
            elif line.startswith('Parent Constraint:'):
                current_section = 'parent'
                constraints['parent_constraint'] = line.replace('Parent Constraint:', '').strip()
            elif line.startswith('Responsible Constraint:'):
                current_section = 'responsible'
                constraints['responsible_constraint'] = line.replace('Responsible Constraint:', '').strip()
            elif line.startswith('Library Constraint:'):
                current_section = 'library'
                constraints['library_constraint'] = line.replace('Library Constraint:', '').strip()
            elif line and not line.startswith(('Self', 'Parent', 'Responsible', 'Library')):
                # Continuation of current section
                if current_section == 'self' and constraints['self_constraint']:
                    constraints['self_constraint'] += ' ' + line
                elif current_section == 'parent' and constraints['parent_constraint']:
                    constraints['parent_constraint'] += ' ' + line
                elif current_section == 'responsible' and constraints['responsible_constraint']:
                    constraints['responsible_constraint'] += ' ' + line
                elif current_section == 'library' and constraints['library_constraint']:
                    constraints['library_constraint'] += ' ' + line
    
    constraints['raw_output'] = output
    return constraints


def analyze_constraint(constraint_str: str) -> dict:
    """
    Analyze a constraint string and extract key information.
    """
    if not constraint_str:
        return {'facts': [], 'operators': []}
    
    analysis = {
        'facts': [],
        'operators': [],
        'complexity': 'simple'
    }
    
    # Common facts
    known_facts = [
        'is-init-proc',
        'is-sip-protected',
        'on-authorized-authapfs-volume',
        'on-system-volume',
        'launch-type',
        'validation-category',
        'team-id',
        'identifier',
        'path',
        'is-responsible',
        'is-parent'
    ]
    
    for fact in known_facts:
        if fact in constraint_str:
            analysis['facts'].append(fact)
    
    # Operators
    if '&&' in constraint_str:
        analysis['operators'].append('AND')
    if '||' in constraint_str:
        analysis['operators'].append('OR')
    if '!' in constraint_str:
        analysis['operators'].append('NOT')
    
    # Complexity assessment
    if len(analysis['operators']) > 1 or len(analysis['facts']) > 3:
        analysis['complexity'] = 'complex'
    elif len(analysis['operators']) == 1:
        analysis['complexity'] = 'moderate'
    
    return analysis


def print_report(app_path: str, constraints: dict):
    """
    Print analysis report.
    """
    print("\n" + "="*70)
    print(f"LAUNCH CONSTRAINTS ANALYSIS: {app_path}")
    print("="*70)
    
    if not constraints['found']:
        print("\n⚠️  No launch constraints found for this application.")
        print("\nThis means the application can be launched without restrictions.")
        print("Consider adding environment constraints for enhanced security.")
        return
    
    print("\n✅ Launch constraints are configured for this application.")
    print("-"*70)
    
    # Self Constraint
    if constraints['self_constraint']:
        print("\n📋 SELF CONSTRAINT:")
        print(f"   {constraints['self_constraint']}")
        analysis = analyze_constraint(constraints['self_constraint'])
        print(f"   Facts used: {', '.join(analysis['facts']) if analysis['facts'] else 'None'}")
        print(f"   Complexity: {analysis['complexity']}")
    else:
        print("\n📋 SELF CONSTRAINT: Not set")
    
    # Parent Constraint
    if constraints['parent_constraint']:
        print("\n👨‍👩‍👧‍👦 PARENT CONSTRAINT:")
        print(f"   {constraints['parent_constraint']}")
        analysis = analyze_constraint(constraints['parent_constraint'])
        print(f"   Facts used: {', '.join(analysis['facts']) if analysis['facts'] else 'None'}")
        print(f"   Complexity: {analysis['complexity']}")
    else:
        print("\n👨‍👩‍👧‍👦 PARENT CONSTRAINT: Not set")
    
    # Responsible Constraint
    if constraints['responsible_constraint']:
        print("\n📞 RESPONSIBLE CONSTRAINT:")
        print(f"   {constraints['responsible_constraint']}")
        analysis = analyze_constraint(constraints['responsible_constraint'])
        print(f"   Facts used: {', '.join(analysis['facts']) if analysis['facts'] else 'None'}")
        print(f"   Complexity: {analysis['complexity']}")
    else:
        print("\n📞 RESPONSIBLE CONSTRAINT: Not set")
    
    # Library Constraint
    if constraints['library_constraint']:
        print("\n📚 LIBRARY CONSTRAINT:")
        print(f"   {constraints['library_constraint']}")
        analysis = analyze_constraint(constraints['library_constraint'])
        print(f"   Facts used: {', '.join(analysis['facts']) if analysis['facts'] else 'None'}")
        print(f"   Complexity: {analysis['complexity']}")
    else:
        print("\n📚 LIBRARY CONSTRAINT: Not set")
    
    # Security assessment
    print("\n" + "="*70)
    print("SECURITY ASSESSMENT")
    print("="*70)
    
    score = 0
    max_score = 4
    
    if constraints['self_constraint']:
        score += 1
        print("✅ Self constraint configured")
    else:
        print("⚠️  No self constraint - binary can run in any context")
    
    if constraints['parent_constraint']:
        score += 1
        print("✅ Parent constraint configured")
    else:
        print("⚠️  No parent constraint - any process can launch this")
    
    if constraints['responsible_constraint']:
        score += 1
        print("✅ Responsible constraint configured")
    else:
        print("⚠️  No responsible constraint - XPC callers not restricted")
    
    if constraints['library_constraint']:
        score += 1
        print("✅ Library constraint configured")
    else:
        print("⚠️  No library constraint - any library can be loaded")
    
    print(f"\nSecurity Score: {score}/{max_score}")
    
    if score >= 3:
        print("🟢 Good security posture")
    elif score >= 2:
        print("🟡 Moderate security - consider adding more constraints")
    else:
        print("🔴 Low security - strongly recommend adding constraints")
    
    print("\n" + "="*70)
    print("RECOMMENDATIONS")
    print("="*70)
    print("""
For enhanced security, consider:

1. Self Constraints: Restrict where the binary can run from
   - Use on-system-volume for system apps
   - Use is-sip-protected for critical binaries

2. Parent Constraints: Restrict who can launch the app
   - Use is-init-proc for system services
   - Specify team-id for controlled launchers

3. Responsible Constraints: Restrict XPC callers
   - Validate client identity
   - Use team-id or identifier facts

4. Library Constraints: Restrict loadable code
   - Specify allowed team IDs
   - Use validation-category for system libraries

For more information:
https://developer.apple.com/documentation/security/defining_launch_environment_and_library_constraints
""")


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 check_app_constraints.py <path/to/app.app>")
        print("\nExample:")
        print("  python3 check_app_constraints.py /Applications/YourApp.app")
        sys.exit(1)
    
    app_path = sys.argv[1]
    
    if not Path(app_path).exists():
        print(f"Error: Application not found: {app_path}")
        sys.exit(1)
    
    print(f"Checking launch constraints for: {app_path}")
    
    # Run codesign
    output = run_codesign(app_path)
    
    if not output:
        sys.exit(1)
    
    # Parse constraints
    constraints = parse_launch_constraints(output)
    
    # Print report
    print_report(app_path, constraints)


if __name__ == '__main__':
    main()
