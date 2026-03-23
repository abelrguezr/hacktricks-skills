#!/usr/bin/env python3
"""
Create detection rule templates for various security platforms.

Usage:
    python create-detection-template.py --platform <platform> --output <file>

Platforms: xql, sigma, yara, splunk, elastic
"""

import argparse
import json
from datetime import datetime


def generate_xql_template():
    """Generate Cortex XDR XQL template."""
    return {
        "template_name": "Windows IPC Exploitation Detection",
        "platform": "cortex_xdr",
        "generated": datetime.now().isoformat(),
        "rules": [
            {
                "name": "{{VENDOR}}_IPC_Enrollment_Hijack",
                "description": "Detects IPC enrollment hijacking attempts",
                "query": """config case_sensitive = false
| dataset = xdr_data
| filter event_type = ENUM.PROCESS and agent_os_type = ENUM.AGENT_OS_WINDOWS
| filter actor_process_image_name contains "{{VENDOR_LOWER}}"
| filter action_module_path contains "jwt" or action_module_path contains "token"
| filter actor_process_integrity_level = "MEDIUM"
| filter action_process_integrity_level = "SYSTEM"""",
                "variables": ["VENDOR", "VENDOR_LOWER"]
            },
            {
                "name": "{{VENDOR}}_DLL_Sideloading",
                "description": "Detects DLL sideloading via signed binary",
                "query": """config case_sensitive = false
| dataset = xdr_data
| filter event_type = ENUM.LOAD_IMAGE and agent_os_type = ENUM.AGENT_OS_WINDOWS
| filter actor_process_signature_vendor contains "{{VENDOR}}"
| filter actor_process_image_path not contains "Program Files\\{{VENDOR}}"
| filter action_module_path contains ".dll"
| filter action_module_path contains "Temp" or action_module_path contains "Downloads"""",
                "variables": ["VENDOR"]
            }
        ]
    }


def generate_sigma_template():
    """Generate Sigma rule template."""
    return {
        "template_name": "Windows IPC Exploitation Detection",
        "platform": "sigma",
        "generated": datetime.now().isoformat(),
        "rules": [
            {
                "name": "{{VENDOR}}_IPC_Caller_Bypass",
                "sigma": f"""title: {{VENDOR}} IPC Caller Bypass
status: experimental
description: Detects IPC caller verification bypass attempts
author: Security Researcher
date: {datetime.now().strftime('%Y/%m/%d')}
logsource:
    category: process_creation
    product: windows
    service: sysmon
detection:
    selection:
        Image|contains:
            - 'Program Files\\{{VENDOR}}'
        ImageLoaded|contains:
            - '.dll'
        ImageLoaded|contains:
            - 'Temp'
            - 'AppData'
    condition: selection
falsepositives:
    - Legitimate software updates
level: high
"""
            }
        ]
    }


def generate_yara_template():
    """Generate YARA rule template."""
    return {
        "template_name": "Windows IPC Exploitation Detection",
        "platform": "yara",
        "generated": datetime.now().isoformat(),
        "rules": [
            {
                "name": "{{VENDOR}}_Suspicious_Load",
                "yara": f"""rule {{VENDOR}}_Suspicious_Load {{
    meta:
        description = "Detects suspicious DLL loading by {{VENDOR}} binary"
        author = "Security Researcher"
        date = "{datetime.now().strftime('%Y/%m/%d')}"
    strings:
        $vendor_path = "C:\\\\Program Files\\\\{{VENDOR}}" fullword
        $temp_path = "%TEMP%" ascii
        $suspicious_dll = "log.dll" ascii
        $suspicious_dll2 = "helper.dll" ascii
    condition:
        ($suspicious_dll or $suspicious_dll2) and ($temp_path or not $vendor_path)
}}
"""
            }
        ]
    }


def main():
    parser = argparse.ArgumentParser(description='Create detection rule templates')
    parser.add_argument('--platform', required=True,
                       choices=['xql', 'sigma', 'yara', 'all'],
                       help='Target platform')
    parser.add_argument('--output', default='detection_templates.json',
                       help='Output file path')
    
    args = parser.parse_args()
    
    templates = {}
    
    if args.platform in ['xql', 'all']:
        templates['xql'] = generate_xql_template()
    
    if args.platform in ['sigma', 'all']:
        templates['sigma'] = generate_sigma_template()
    
    if args.platform in ['yara', 'all']:
        templates['yara'] = generate_yara_template()
    
    with open(args.output, 'w') as f:
        json.dump(templates, f, indent=2)
    
    print(f"Generated templates for: {list(templates.keys())}")
    print(f"Output: {args.output}")


if __name__ == '__main__':
    main()
