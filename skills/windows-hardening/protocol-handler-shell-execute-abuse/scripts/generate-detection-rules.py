#!/usr/bin/env python3
"""Generate detection rules for Windows Protocol Handler abuse.

Usage:
    python generate-detection-rules.py --format sigma --output detection-rules.yaml
    python generate-detection-rules.py --format regex --output detection-rules.txt
"""

import argparse
import sys
from pathlib import Path


def generate_sigma_rules() -> str:
    """Generate Sigma detection rules for protocol handler abuse."""
    
    rules = """# Sigma Rules for Windows Protocol Handler Abuse Detection
# CVE-2026-20841 and similar vulnerabilities

---
title: Windows Notepad Markdown Protocol Handler Abuse - File Scheme
description: Detects Markdown files containing file:// protocol handler abuse attempts
status: experimental
author: Security Research
logsource:
  category: file_monitoring
  product: generic
  service: file_content
  category: network
  product: generic
  service: file_transfer
detection:
  selection:
    filename|contains: '.md'
    file_content|contains:
      - 'file://\\\\'
      - 'file://\\\\\\\\'
      - '<file://'
      - '[file://'
  filter:
    - file_content|contains: 'http://'
    - file_content|contains: 'https://'
falsepositives:
  - Legitimate documentation with file paths
  - Internal wiki documentation
level: high

---
title: Windows Notepad Markdown Protocol Handler Abuse - MS-AppInstaller
description: Detects Markdown files containing ms-appinstaller:// protocol handler abuse attempts
status: experimental
author: Security Research
logsource:
  category: file_monitoring
  product: generic
  service: file_content
detection:
  selection:
    filename|contains: '.md'
    file_content|contains:
      - 'ms-appinstaller://'
      - '<ms-appinstaller://'
      - '[ms-appinstaller://'
falsepositives:
  - Legitimate app installer documentation
level: high

---
title: Suspicious Markdown File Transfer
description: Detects transfer of Markdown files over common document delivery protocols
status: experimental
author: Security Research
logsource:
  category: network
  product: firewall
  service: traffic
detection:
  selection:
    destination_port:
      - 20
      - 21
      - 80
      - 443
      - 110
      - 143
      - 25
      - 587
      - 139
      - 445
      - 2049
      - 111
    filename|contains: '.md'
  filter:
    - user|in_list: 'trusted_admins'
falsepositives:
  - Legitimate documentation sharing
  - Internal wiki synchronization
level: medium

---
title: ShellExecuteExW with Non-HTTP Protocol
description: Detects ShellExecuteExW calls with non-HTTP(S) protocols from Markdown rendering context
status: experimental
author: Security Research
logsource:
  category: process
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 1
    Image|endswith: 'notepad.exe'
    CommandLine|contains:
      - 'file://'
      - 'ms-appinstaller://'
  filter:
    - CommandLine|contains: 'http://'
    - CommandLine|contains: 'https://'
falsepositives:
  - Legitimate file operations
level: high
"""
    
    return rules


def generate_regex_rules() -> str:
    """Generate regex patterns for protocol handler abuse detection."""
    
    rules = """# Regex Patterns for Windows Protocol Handler Abuse Detection
# Use these patterns in SIEM, EDR, or content inspection systems

## File scheme detection (case-insensitive)
# Matches: [text](file://\\\\path) or <file://\\\\path>
(\x3C|\[[^\x5d]+\]\()file:(\x2f|\x5c\x5c){4}

## MS-AppInstaller scheme detection (case-insensitive)
# Matches: [text](ms-appinstaller://path) or <ms-appinstaller://path>
(\x3C|\[[^\x5d]+\]\()ms-appinstaller:(\x2f|\x5c\x5c){2}

## Generic non-HTTP scheme detection
# Matches any scheme that is not http:// or https://
(\x3C|\[[^\x5d]+\]\()(?!https?://)[a-z]+://

## Markdown file with dangerous content
# Combined pattern for .md files with protocol handler abuse
(?i)\.md.*?(\x3C|\[[^\x5d]+\]\()(file|ms-appinstaller|ftp|gopher|javascript)://

## Network transfer detection
# File extensions commonly used for document delivery
(?i)\.(md|markdown|txt|doc|docx|pdf|html|htm)

## Usage examples:

# Python
import re
pattern = re.compile(r'(\x3C|\[[^\x5d]+\]\()file:(\x2f|\x5c\x5c){4}', re.IGNORECASE)
if pattern.search(content):
    print("Suspicious file:// link detected")

# grep
# grep -iE '(\x3C|\[[^\x5d]+\]\()file:(\x2f|\x5c\x5c){4}' file.md

# PowerShell
# Select-String -Path "*.md" -Pattern '(\x3C|\[[^\x5d]+\]\()file:(\x2f|\x5c\x5c){4}' -CaseSensitive:$false
"""
    
    return rules


def main():
    parser = argparse.ArgumentParser(
        description="Generate detection rules for Windows Protocol Handler abuse"
    )
    parser.add_argument(
        "--format",
        required=True,
        choices=["sigma", "regex"],
        help="Output format (sigma for SIEM rules, regex for pattern matching)"
    )
    parser.add_argument(
        "--output",
        required=True,
        help="Output file path"
    )
    
    args = parser.parse_args()
    
    # Generate rules based on format
    if args.format == "sigma":
        rules = generate_sigma_rules()
        output_path = Path(args.output)
        if output_path.suffix.lower() not in [".yaml", ".yml"]:
            output_path = output_path.with_suffix(".yaml")
    else:
        rules = generate_regex_rules()
        output_path = Path(args.output)
        if output_path.suffix.lower() != ".txt":
            output_path = output_path.with_suffix(".txt")
    
    # Write rules
    output_path.write_text(rules)
    print(f"Detection rules written to: {output_path}")
    print(f"\nGenerated {args.format} rules for:")
    print("  - file:// protocol handler abuse")
    print("  - ms-appinstaller:// protocol handler abuse")
    print("  - Suspicious Markdown file transfers")
    print("  - ShellExecuteExW with non-HTTP protocols")
    print("\n⚠️  Note: Customize these rules for your environment's protocol handlers.")


if __name__ == "__main__":
    main()
