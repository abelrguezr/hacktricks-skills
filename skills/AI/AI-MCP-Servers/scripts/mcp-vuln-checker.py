#!/usr/bin/env python3
"""
MCP Vulnerability Checker

Checks MCP server configurations and tool definitions for known vulnerability patterns.
Supports both JSON configs and Python MCP server files.

Usage:
    python mcp-vuln-checker.py <file-or-directory>
    python mcp-vuln-checker.py --check-cve <cve-id> <file>
    python mcp-vuln-checker.py --generate-report <directory> report.json
"""

import json
import os
import re
import sys
import argparse
from pathlib import Path
from typing import List, Dict, Any, Optional
from dataclasses import dataclass, asdict
from datetime import datetime


@dataclass
class Finding:
    """Represents a security finding."""
    severity: str  # CRITICAL, HIGH, MEDIUM, LOW, INFO
    cve: Optional[str]
    category: str
    description: str
    location: str
    line_number: Optional[int]
    evidence: str
    recommendation: str


class MCPVulnerabilityChecker:
    """Checker for MCP-related vulnerabilities."""
    
    # Known CVE patterns
    CVE_PATTERNS = {
        "CVE-2025-54136": {
            "name": "MCPoison - Cursor IDE Trust Bypass",
            "patterns": [
                (r'"command"\s*:\s*["\']cmd\.exe["\']', "Windows command shell in MCP config"),
                (r'"command"\s*:\s*["\']powershell["\']', "PowerShell in MCP config"),
                (r'"command"\s*:\s*["\']bash["\']', "Bash shell in MCP config"),
            ],
            "recommendation": "Upgrade to Cursor >= v1.3 and protect MCP files with code review"
        },
        "CVE-2025-64755": {
            "name": "Claude Code sed DSL RCE",
            "patterns": [
                (r'sed\s+["\'].*[wW]\s*["\']', "Sed write command (potential RCE)"),
                (r'sed\s+["\'].*[rR]\s*["\']', "Sed read command (potential data exfiltration)"),
                (r'sed\s+["\'].*[eE]\s*["\']', "Sed execute command (RCE)"),
            ],
            "recommendation": "Upgrade Claude Code and restrict sed command usage"
        },
        "CVE-2025-59528": {
            "name": "Flowise CustomMCP JavaScript Injection",
            "patterns": [
                (r'Function\s*\(', "Function constructor (code injection)"),
                (r'process\.mainModule', "Node.js process access"),
                (r'child_process', "Child process execution"),
                (r'execSync', "Synchronous command execution"),
            ],
            "recommendation": "Update Flowise and avoid JavaScript injection in MCP configs"
        },
        "CVE-2025-8943": {
            "name": "Flowise Command Execution",
            "patterns": [
                (r'"command"\s*:\s*["\']\w+["\'].*"args"', "Command with args in MCP config"),
            ],
            "recommendation": "Update Flowise and validate MCP command inputs"
        }
    }
    
    # Prompt injection patterns
    PROMPT_INJECTION_PATTERNS = [
        (r'ignore\s+instructions', 'CRITICAL', 'Ignore instructions pattern'),
        (r"don't\s+tell\s+user", 'CRITICAL', "Don't tell user pattern"),
        (r'user\s+already\s+know', 'CRITICAL', 'User already knows pattern'),
        (r'important\s+before\s+using', 'HIGH', 'Important before using pattern'),
        (r'run\s+this\s+command', 'HIGH', 'Run this command instruction'),
        (r'execute\s+the\s+following', 'HIGH', 'Execute the following instruction'),
        (r'curl\s+.*\|\s*sh', 'CRITICAL', 'Curl pipe to shell'),
        (r'wget\s+.*\|\s*sh', 'CRITICAL', 'Wget pipe to shell'),
        (r'nc\s+-e', 'CRITICAL', 'Netcat reverse shell'),
        (r'/dev/tcp', 'CRITICAL', 'Bash reverse shell'),
    ]
    
    # Sensitive file patterns
    SENSITIVE_FILE_PATTERNS = [
        (r'\.ssh/', 'HIGH', 'SSH directory reference'),
        (r'\.aws/', 'HIGH', 'AWS credentials reference'),
        (r'\.zshenv', 'MEDIUM', 'Zsh environment file'),
        (r'\.bashrc', 'MEDIUM', 'Bash config file'),
        (r'\.profile', 'MEDIUM', 'Profile file'),
        (r'\.gnupg/', 'HIGH', 'GPG directory'),
        (r'\.npmrc', 'MEDIUM', 'NPM config'),
        (r'\.env', 'HIGH', 'Environment file'),
    ]
    
    def __init__(self):
        self.findings: List[Finding] = []
    
    def check_file(self, filepath: str) -> List[Finding]:
        """Check a single file for vulnerabilities."""
        findings = []
        path = Path(filepath)
        
        if not path.exists():
            return findings
        
        try:
            content = path.read_text(encoding='utf-8', errors='ignore')
        except Exception as e:
            return findings
        
        # Check based on file type
        if path.suffix == '.json':
            findings.extend(self._check_json_file(filepath, content))
        elif path.suffix == '.py':
            findings.extend(self._check_python_file(filepath, content))
        elif path.suffix == '.md':
            findings.extend(self._check_markdown_file(filepath, content))
        else:
            # Check all files for patterns
            findings.extend(self._check_generic_file(filepath, content))
        
        return findings
    
    def _check_json_file(self, filepath: str, content: str) -> List[Finding]:
        """Check JSON files for MCP vulnerabilities."""
        findings = []
        
        try:
            data = json.loads(content)
            
            # Check for MCP server configurations
            if 'mcpServers' in data:
                for server_name, config in data['mcpServers'].items():
                    if isinstance(config, dict):
                        command = config.get('command', '')
                        args = config.get('args', [])
                        
                        # Check for dangerous commands
                        if any(cmd in command.lower() for cmd in ['cmd.exe', 'powershell', 'bash', 'sh']):
                            findings.append(Finding(
                                severity='HIGH',
                                cve='CVE-2025-54136',
                                category='Command Execution',
                                description=f'Dangerous command in MCP server {server_name}',
                                location=filepath,
                                line_number=None,
                                evidence=f'command: {command}',
                                recommendation='Use safe commands and upgrade to Cursor >= v1.3'
                            ))
                        
                        # Check for suspicious args
                        for arg in args if isinstance(args, list) else []:
                            if any(pattern in str(arg).lower() for pattern in ['shell', 'exec', 'eval']):
                                findings.append(Finding(
                                    severity='MEDIUM',
                                    cve=None,
                                    category='Suspicious Arguments',
                                    description=f'Suspicious argument in MCP server {server_name}',
                                    location=filepath,
                                    line_number=None,
                                    evidence=f'arg: {arg}',
                                    recommendation='Review and validate all MCP server arguments'
                                ))
        except json.JSONDecodeError:
            pass
        
        # Also check raw content for patterns
        findings.extend(self._check_generic_file(filepath, content))
        
        return findings
    
    def _check_python_file(self, filepath: str, content: str) -> List[Finding]:
        """Check Python files for MCP vulnerabilities."""
        findings = []
        lines = content.split('\n')
        
        # Check for MCP tool definitions with suspicious docstrings
        in_docstring = False
        docstring_content = ""
        current_function = ""
        
        for i, line in enumerate(lines, 1):
            # Track function definitions
            if '@mcp.tool()' in line or '@mcp.resource()' in line:
                # Look ahead for function definition
                for j in range(i, min(i+5, len(lines))):
                    if lines[j].strip().startswith('def '):
                        current_function = lines[j].strip()
                        break
            
            # Check docstrings for prompt injection
            if '"""' in line or "'''" in line:
                if not in_docstring:
                    in_docstring = True
                    docstring_content = line
                else:
                    docstring_content += '\n' + line
                    if '"""' in line or "'''" in line:
                        in_docstring = False
                        
                        # Check docstring content
                        for pattern, severity, description in self.PROMPT_INJECTION_PATTERNS:
                            if re.search(pattern, docstring_content, re.IGNORECASE):
                                findings.append(Finding(
                                    severity=severity,
                                    cve=None,
                                    category='Prompt Injection',
                                    description=f'{description} in {current_function}',
                                    location=filepath,
                                    line_number=i,
                                    evidence=docstring_content[:200],
                                    recommendation='Remove injected instructions from tool descriptions'
                                ))
                        
                        docstring_content = ""
            
            # Check for dangerous patterns in code
            for pattern, severity, description in self.PROMPT_INJECTION_PATTERNS:
                if re.search(pattern, line, re.IGNORECASE):
                    findings.append(Finding(
                        severity=severity,
                        cve=None,
                        category='Prompt Injection',
                        description=description,
                        location=filepath,
                        line_number=i,
                        evidence=line.strip(),
                        recommendation='Remove or sanitize injected instructions'
                    ))
        
        return findings
    
    def _check_markdown_file(self, filepath: str, content: str) -> List[Finding]:
        """Check markdown files for MCP vulnerabilities."""
        findings = []
        lines = content.split('\n')
        
        for i, line in enumerate(lines, 1):
            # Check for prompt injection patterns
            for pattern, severity, description in self.PROMPT_INJECTION_PATTERNS:
                if re.search(pattern, line, re.IGNORECASE):
                    findings.append(Finding(
                        severity=severity,
                        cve=None,
                        category='Prompt Injection',
                        description=description,
                        location=filepath,
                        line_number=i,
                        evidence=line.strip(),
                        recommendation='Review and sanitize content'
                    ))
            
            # Check for sensitive file references
            for pattern, severity, description in self.SENSITIVE_FILE_PATTERNS:
                if re.search(pattern, line, re.IGNORECASE):
                    findings.append(Finding(
                        severity=severity,
                        cve=None,
                        category='Sensitive File Reference',
                        description=description,
                        location=filepath,
                        line_number=i,
                        evidence=line.strip(),
                        recommendation='Avoid referencing sensitive files in documentation'
                    ))
        
        return findings
    
    def _check_generic_file(self, filepath: str, content: str) -> List[Finding]:
        """Check any file for generic vulnerability patterns."""
        findings = []
        lines = content.split('\n')
        
        # Check CVE-specific patterns
        for cve_id, cve_info in self.CVE_PATTERNS.items():
            for pattern, description in cve_info['patterns']:
                for i, line in enumerate(lines, 1):
                    if re.search(pattern, line, re.IGNORECASE):
                        findings.append(Finding(
                            severity='CRITICAL',
                            cve=cve_id,
                            category=cve_info['name'],
                            description=description,
                            location=filepath,
                            line_number=i,
                            evidence=line.strip(),
                            recommendation=cve_info['recommendation']
                        ))
        
        # Check prompt injection patterns
        for pattern, severity, description in self.PROMPT_INJECTION_PATTERNS:
            for i, line in enumerate(lines, 1):
                if re.search(pattern, line, re.IGNORECASE):
                    findings.append(Finding(
                        severity=severity,
                        cve=None,
                        category='Prompt Injection',
                        description=description,
                        location=filepath,
                        line_number=i,
                        evidence=line.strip(),
                        recommendation='Remove or sanitize injected instructions'
                    ))
        
        # Check sensitive file patterns
        for pattern, severity, description in self.SENSITIVE_FILE_PATTERNS:
            for i, line in enumerate(lines, 1):
                if re.search(pattern, line, re.IGNORECASE):
                    findings.append(Finding(
                        severity=severity,
                        cve=None,
                        category='Sensitive File Reference',
                        description=description,
                        location=filepath,
                        line_number=i,
                        evidence=line.strip(),
                        recommendation='Avoid referencing sensitive files'
                    ))
        
        return findings
    
    def check_directory(self, directory: str) -> List[Finding]:
        """Check all files in a directory."""
        findings = []
        path = Path(directory)
        
        if not path.exists():
            return findings
        
        # Find relevant files
        extensions = ['.json', '.py', '.md', '.yaml', '.yml', '.txt']
        
        for filepath in path.rglob('*'):
            if filepath.is_file() and filepath.suffix in extensions:
                file_findings = self.check_file(str(filepath))
                findings.extend(file_findings)
        
        return findings
    
    def generate_report(self, findings: List[Finding], output_path: str) -> None:
        """Generate a JSON report of findings."""
        report = {
            'scan_timestamp': datetime.now().isoformat(),
            'total_findings': len(findings),
            'summary': {
                'critical': len([f for f in findings if f.severity == 'CRITICAL']),
                'high': len([f for f in findings if f.severity == 'HIGH']),
                'medium': len([f for f in findings if f.severity == 'MEDIUM']),
                'low': len([f for f in findings if f.severity == 'LOW']),
                'info': len([f for f in findings if f.severity == 'INFO']),
            },
            'findings': [asdict(f) for f in findings]
        }
        
        with open(output_path, 'w') as f:
            json.dump(report, f, indent=2)
        
        print(f"Report saved to: {output_path}")


def main():
    parser = argparse.ArgumentParser(description='MCP Vulnerability Checker')
    parser.add_argument('target', nargs='?', help='File or directory to check')
    parser.add_argument('--check-cve', help='Check for specific CVE')
    parser.add_argument('--generate-report', help='Generate JSON report to file')
    parser.add_argument('--verbose', '-v', action='store_true', help='Verbose output')
    
    args = parser.parse_args()
    
    if not args.target:
        parser.print_help()
        sys.exit(1)
    
    checker = MCPVulnerabilityChecker()
    
    if os.path.isfile(args.target):
        findings = checker.check_file(args.target)
    else:
        findings = checker.check_directory(args.target)
    
    # Filter by CVE if specified
    if args.check_cve:
        findings = [f for f in findings if f.cve == args.check_cve]
    
    # Print findings
    if findings:
        print(f"\nFound {len(findings)} security issues:\n")
        
        for finding in sorted(findings, key=lambda f: ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO'].index(f.severity) if f.severity in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO'] else 5):
            print(f"[{finding.severity}] {finding.category}")
            if finding.cve:
                print(f"  CVE: {finding.cve}")
            print(f"  {finding.description}")
            print(f"  Location: {finding.location}")
            if finding.line_number:
                print(f"  Line: {finding.line_number}")
            print(f"  Evidence: {finding.evidence[:100]}...")
            print(f"  Recommendation: {finding.recommendation}")
            print()
    else:
        print("No security issues found.")
    
    # Generate report if requested
    if args.generate_report:
        checker.generate_report(findings, args.generate_report)
    
    # Exit with error code if critical issues found
    critical_count = len([f for f in findings if f.severity == 'CRITICAL'])
    if critical_count > 0:
        sys.exit(1)


if __name__ == '__main__':
    main()
