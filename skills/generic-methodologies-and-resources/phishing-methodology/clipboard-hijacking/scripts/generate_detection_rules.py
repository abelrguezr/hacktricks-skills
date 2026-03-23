#!/usr/bin/env python3
"""
Generate Detection Rules for Clipboard Hijacking Attacks

Generates detection rules for various SIEM/EDR platforms to detect
pastejacking and ClickFix attack patterns.

Usage:
    python generate_detection_rules.py --platform splunk
    python generate_detection_rules.py --platform sentinel --output rules.json
    python generate_detection_rules.py --platform yara --output clipboard_hijacking.yar
"""

import argparse
import json
from pathlib import Path
from typing import Dict, List, Any


class DetectionRuleGenerator:
    """Generates detection rules for clipboard hijacking attacks."""
    
    def __init__(self):
        self.rules: Dict[str, List[Dict[str, Any]]] = {}
        
    def generate_splunk(self) -> List[str]:
        """Generate Splunk SPL queries."""
        queries = [
            # PowerShell encoded command detection
            """index=windows_logs EventCode=4688 
| where ParentImage="explorer.exe" AND NewProcessName="powershell.exe"
| where CommandLine LIKE "%-enc%" OR CommandLine LIKE "%-nop%"
| stats count by NewProcessName, CommandLine
| where count > 0""",
            
            # WScript with suspicious VBScript
            """index=windows_logs EventCode=4688
| where NewProcessName="wscript.exe"
| where CommandLine LIKE "%SyncAppvPublishingServer.vbs%"
| table _time, ComputerName, CommandLine, AccountName""",
            
            # RunMRU suspicious entries
            """index=registry EventCode=4657
| where RegistryKey LIKE "%RunMRU%"
| where NewValue LIKE "%powershell%" OR NewValue LIKE "%wscript%"
| table _time, ComputerName, RegistryKey, NewValue""",
            
            # Clipboard API abuse (if EDR provides this)
            """index=edr EventCode=clipboard_write
| where ProcessName IN ("chrome.exe", "msedge.exe", "firefox.exe")
| join type=left (select ProcessName, _time as clipboard_time from index=edr EventCode=process_create where ProcessName IN ("powershell.exe", "cmd.exe"))
| where abs(_time - clipboard_time) < 30
| table _time, ComputerName, ProcessName""",
            
            # MSHTA with URL
            """index=windows_logs EventCode=4688
| where NewProcessName="mshta.exe"
| where CommandLine LIKE "%http%" OR CommandLine LIKE "%https%"
| table _time, ComputerName, CommandLine""",
        ]
        return queries
    
    def generate_sentinel(self) -> List[Dict[str, Any]]:
        """Generate Microsoft Sentinel detection rules."""
        rules = [
            {
                "name": "ClipboardHijacking_PowerShell_Encoded",
                "displayName": "Clipboard Hijacking - Encoded PowerShell from Explorer",
                "description": "Detects encoded PowerShell commands spawned from explorer.exe, indicative of pastejacking attacks.",
                "query": """DeviceProcessEvents
| where ParentProcessName == "explorer.exe"
| where ProcessName == "powershell.exe"
| where CommandLine has_any("-enc", "-nop -w hidden", "-NoProfile -NonInteractive")
| project TimeGenerated, DeviceName, ProcessName, ParentProcessName, CommandLine, AccountName""",
                "severity": "High",
                "tactics": ["Execution", "Defense Evasion"],
                "techniques": ["T1059.001", "T1055", "T1204.004"]
            },
            {
                "name": "ClipboardHijacking_WScript_LOLBAS",
                "displayName": "Clipboard Hijacking - WScript with LOLBAS",
                "description": "Detects WScript.exe executing suspicious VBScript files like SyncAppvPublishingServer.vbs.",
                "query": """DeviceProcessEvents
| where ProcessName == "wscript.exe"
| where CommandLine has "SyncAppvPublishingServer.vbs"
| project TimeGenerated, DeviceName, ProcessName, CommandLine, AccountName""",
                "severity": "High",
                "tactics": ["Execution"],
                "techniques": ["T1218.010", "T1204.004"]
            },
            {
                "name": "ClipboardHijacking_RunMRU_Suspicious",
                "displayName": "Clipboard Hijacking - Suspicious RunMRU Entries",
                "description": "Detects suspicious entries in RunMRU registry key containing PowerShell or script host commands.",
                "query": """DeviceRegistryEvents
| where RegistryKey has "RunMRU"
| where NewValue has_any("powershell", "wscript", "mshta", "base64")
| project TimeGenerated, DeviceName, RegistryKey, ValueName, NewValue""",
                "severity": "Medium",
                "tactics": ["Persistence", "Execution"],
                "techniques": ["T1547.001", "T1204.004"]
            },
            {
                "name": "ClipboardHijacking_MSHTA_URL",
                "displayName": "Clipboard Hijacking - MSHTA with Remote URL",
                "description": "Detects MSHTA.exe executing remote URLs, common in pastejacking campaigns.",
                "query": """DeviceProcessEvents
| where ProcessName == "mshta.exe"
| where CommandLine has_any("http://", "https://")
| project TimeGenerated, DeviceName, ProcessName, CommandLine, AccountName""",
                "severity": "High",
                "tactics": ["Execution"],
                "techniques": ["T1218.011", "T1204.004"]
            },
        ]
        return rules
    
    def generate_yara(self) -> str:
        """Generate YARA rules for payload detection."""
        yara_rules = """/*
 * Clipboard Hijacking Detection Rules
 * Detects common pastejacking and ClickFix attack patterns
 */

rule ClipboardHijacking_PowerShell_Encoded {
    meta:
        description = "Detects Base64 encoded PowerShell commands"
        author = "Security Team"
        level = "high"
        tlp = "green"
    
    strings:
        $enc1 = "powershell" ascii
        $enc2 = "-enc" ascii
        $enc3 = "-nop" ascii
        $enc4 = "-w hidden" ascii
        $iex = "iex(" ascii
        $iwr = "iwr" ascii
        $download = "Invoke-WebRequest" ascii
        $temp = "%TEMP%" ascii
    
    condition:
        ($enc1 and $enc2) or
        ($enc1 and $enc3 and $enc4) or
        ($iex and $iwr) or
        ($download and $temp)
}

rule ClipboardHijacking_WScript_LOLBAS {
    meta:
        description = "Detects WScript with suspicious VBScript"
        author = "Security Team"
        level = "high"
        tlp = "green"
    
    strings:
        $wscript = "wscript.exe" ascii
        $syncappv = "SyncAppvPublishingServer.vbs" ascii
        $gal = "gal i*x" ascii
        $gcm = "gcm *stM*" ascii
    
    condition:
        $wscript and ($syncappv or $gal or $gcm)
}

rule ClipboardHijacking_MSHTA_URL {
    meta:
        description = "Detects MSHTA with remote URL execution"
        author = "Security Team"
        level = "high"
        tlp = "green"
    
    strings:
        $mshta = "mshta" ascii
        $http = "http://" ascii
        $https = "https://" ascii
    
    condition:
        $mshta and ($http or $https)
}

rule ClipboardHijacking_JavaScript_Obfuscation {
    meta:
        description = "Detects JavaScript obfuscation patterns"
        author = "Security Team"
        level = "medium"
        tlp = "green"
    
    strings:
        $split = ".split('')" ascii
        $reverse = ".reverse()" ascii
        $join = ".join('')" ascii
        $eval = "eval(" ascii
        $responseText = "responseText" ascii
    
    condition:
        ($split and $reverse and $join) or
        ($eval and $responseText)
}

rule ClipboardHijacking_DLL_Sideloading {
    meta:
        description = "Detects potential DLL sideloading patterns"
        author = "Security Team"
        level = "high"
        tlp = "green"
    
    strings:
        $expand = "Expand-Archive" ascii
        $dll = ".dll" ascii
        $launcher = "launcher.exe" ascii
        $msvcp = "msvcp140.dll" ascii
    
    condition:
        ($expand and $dll) or
        ($launcher and $dll) or
        $msvcp
}
"""
        return yara_rules
    
    def generate_sigma(self) -> List[Dict[str, Any]]:
        """Generate Sigma detection rules."""
        rules = [
            {
                "title": "Clipboard Hijacking - Encoded PowerShell from Explorer",
                "id": "clipboard-hijacking-001",
                "status": "experimental",
                "description": "Detects encoded PowerShell commands spawned from explorer.exe",
                "author": "Security Team",
                "logsource:
                    category: "process_creation"
                    product: "windows"
                    service: "sysmon"
                "detection:
                    selection:
                        ParentImage: "*\\explorer.exe"
                        Image: "*\\powershell.exe"
                        CommandLine|contains:
                            - "-enc"
                            - "-nop -w hidden"
                            - "-NoProfile -NonInteractive -Command -"
                    condition: selection
                "falsepositives:
                    - "Legitimate administrative tasks"
                "level": "high"
                "tags:
                    - "attack.execution"
                    - "attack.t1059.001"
                    - "attack.t1204.004"
            },
            {
                "title": "Clipboard Hijacking - WScript LOLBAS Abuse",
                "id": "clipboard-hijacking-002",
                "status": "experimental",
                "description": "Detects WScript.exe executing suspicious VBScript files",
                "author": "Security Team",
                "logsource:
                    category: "process_creation"
                    product: "windows"
                    service: "sysmon"
                "detection:
                    selection:
                        Image: "*\\wscript.exe"
                        CommandLine|contains: "SyncAppvPublishingServer.vbs"
                    condition: selection
                "falsepositives:
                    - "Legitimate App-V operations (rare)"
                "level": "high"
                "tags:
                    - "attack.execution"
                    - "attack.t1218.010"
                    - "attack.t1204.004"
            },
        ]
        return rules
    
    def generate(self, platform: str) -> Any:
        """Generate rules for specified platform."""
        generators = {
            "splunk": self.generate_splunk,
            "sentinel": self.generate_sentinel,
            "yara": self.generate_yara,
            "sigma": self.generate_sigma,
        }
        
        if platform not in generators:
            raise ValueError(f"Unknown platform: {platform}. Supported: {list(generators.keys())}")
        
        return generators[platform]()


def main():
    parser = argparse.ArgumentParser(
        description="Generate detection rules for clipboard hijacking attacks."
    )
    parser.add_argument(
        "--platform",
        required=True,
        choices=["splunk", "sentinel", "yara", "sigma"],
        help="Target platform for detection rules"
    )
    parser.add_argument(
        "-o", "--output",
        help="Output file path (default: stdout)"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output as JSON (for sentinel/sigma)"
    )
    
    args = parser.parse_args()
    
    generator = DetectionRuleGenerator()
    
    try:
        rules = generator.generate(args.platform)
        
        if args.platform == "yara":
            output = rules
        elif args.json:
            output = json.dumps(rules, indent=2)
        else:
            if args.platform == "splunk":
                output = "\n\n".join(rules)
            elif args.platform in ["sentinel", "sigma"]:
                output = json.dumps(rules, indent=2)
            else:
                output = str(rules)
        
        if args.output:
            Path(args.output).write_text(output)
            print(f"Rules written to {args.output}")
        else:
            print(output)
    
    except Exception as e:
        print(f"Error generating rules: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
