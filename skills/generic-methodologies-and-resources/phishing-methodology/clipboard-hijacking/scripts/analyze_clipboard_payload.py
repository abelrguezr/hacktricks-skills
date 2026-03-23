#!/usr/bin/env python3
"""
Clipboard Hijacking Payload Analyzer

Analyzes suspicious clipboard payloads for pastejacking attacks.
Supports Base64 decoding, obfuscation detection, and chain analysis.

Usage:
    python analyze_clipboard_payload.py "powershell -enc <BASE64>"
    python analyze_clipboard_payload.py -f suspicious.ps1
    python analyze_clipboard_payload.py --decode <BASE64_STRING>
"""

import argparse
import base64
import re
import sys
import json
from pathlib import Path
from typing import Optional, List, Dict, Any


class PayloadAnalyzer:
    """Analyzes clipboard hijacking payloads for indicators of compromise."""
    
    # Known obfuscation patterns
    OBFUSCATION_PATTERNS = [
        r"\.split\(['"]\)\.reverse\(\)\.join\(['"]\)",
        r"-enc\s+",
        r"-nop\s+-w\s+hidden",
        r"iex\s*\(\s*irm\s*",
        r"iex\s*\(\s*iwr\s*",
        r"eval\s*\(\s*a\.responseText\s*\)",
        r"gal\s+i\*x",
        r"gcm\s+\*stM\*",
    ]
    
    # LOLBins commonly abused
    LOLBINS = [
        "mshta.exe", "wscript.exe", "cscript.exe", "regsvr32.exe",
        "certutil.exe", "bitsadmin.exe", "findstr.exe", "powershell.exe",
        "SyncAppvPublishingServer.vbs", "msiexec.exe", "cmd.exe"
    ]
    
    # Suspicious domains/patterns
    SUSPICIOUS_PATTERNS = [
        r"cdn\.jsdelivr\.net",
        r"github\.com/gh/",
        r"cloudflareworkers?",
        r"bsc-testnet\.drpc\.org",
        r"/Y\/?t=\d+",
        r"%TEMP%\\",
        r"%APPDATA%\\",
    ]
    
    def __init__(self):
        self.findings: List[Dict[str, Any]] = []
        self.decoded_content: Optional[str] = None
        
    def analyze(self, payload: str) -> Dict[str, Any]:
        """Analyze a payload for pastejacking indicators."""
        self.findings = []
        self.decoded_content = None
        
        # Check for Base64 encoded content
        base64_match = re.search(r"-enc\s+([A-Za-z0-9+/=]+)", payload)
        if base64_match:
            encoded = base64_match.group(1)
            try:
                decoded = base64.b64decode(encoded).decode('utf-16-le', errors='ignore')
                self.decoded_content = decoded
                self.findings.append({
                    "type": "base64_encoded",
                    "severity": "high",
                    "description": "Base64 encoded PowerShell detected",
                    "decoded_preview": decoded[:200] + "..." if len(decoded) > 200 else decoded
                })
                # Analyze decoded content
                self._analyze_decoded(decoded)
            except Exception as e:
                self.findings.append({
                    "type": "base64_decode_error",
                    "severity": "medium",
                    "description": f"Failed to decode Base64: {str(e)}"
                })
        
        # Check for obfuscation patterns
        for pattern in self.OBFUSCATION_PATTERNS:
            if re.search(pattern, payload, re.IGNORECASE):
                self.findings.append({
                    "type": "obfuscation",
                    "severity": "high",
                    "description": f"Obfuscation pattern detected: {pattern}",
                    "pattern": pattern
                })
        
        # Check for LOLBins
        for lolbin in self.LOLBINS:
            if lolbin.lower() in payload.lower():
                self.findings.append({
                    "type": "lolbin",
                    "severity": "medium",
                    "description": f"LOLBin detected: {lolbin}",
                    "lolbin": lolbin
                })
        
        # Check for suspicious patterns
        for pattern in self.SUSPICIOUS_PATTERNS:
            if re.search(pattern, payload, re.IGNORECASE):
                self.findings.append({
                    "type": "suspicious_pattern",
                    "severity": "medium",
                    "description": f"Suspicious pattern detected: {pattern}",
                    "pattern": pattern
                })
        
        # Check for persistence mechanisms
        persistence_patterns = [
            (r"Startup", "Startup folder persistence"),
            (r"ScheduledTask|schtasks", "Scheduled task persistence"),
            (r"HKLM.*Run|HKCU.*Run", "Registry Run key persistence"),
            (r"lnk|LNK", "LNK file persistence"),
        ]
        for pattern, desc in persistence_patterns:
            if re.search(pattern, payload, re.IGNORECASE):
                self.findings.append({
                    "type": "persistence",
                    "severity": "high",
                    "description": desc,
                    "pattern": pattern
                })
        
        return self._generate_report(payload)
    
    def _analyze_decoded(self, decoded: str):
        """Analyze decoded content for additional indicators."""
        if not decoded:
            return
            
        # Check for download cradles
        download_patterns = [
            (r"Invoke-WebRequest|iwr", "PowerShell download cradle"),
            (r"Invoke-Expression|iex", "PowerShell expression execution"),
            (r"curl|wget", "Download utility"),
            (r"base64\s*-d", "Base64 decode execution"),
        ]
        for pattern, desc in download_patterns:
            if re.search(pattern, decoded, re.IGNORECASE):
                self.findings.append({
                    "type": "download_cradle",
                    "severity": "high",
                    "description": desc,
                    "pattern": pattern
                })
        
        # Check for DLL sideloading indicators
        if re.search(r"\.dll", decoded, re.IGNORECASE):
            self.findings.append({
                "type": "dll_reference",
                "severity": "medium",
                "description": "DLL file reference detected (possible sideloading)"
            })
    
    def _generate_report(self, original_payload: str) -> Dict[str, Any]:
        """Generate analysis report."""
        severity_scores = {"critical": 4, "high": 3, "medium": 2, "low": 1}
        max_severity = "low"
        
        for finding in self.findings:
            if severity_scores.get(finding["severity"], 0) > severity_scores[max_severity]:
                max_severity = finding["severity"]
        
        return {
            "original_payload": original_payload[:500] + "..." if len(original_payload) > 500 else original_payload,
            "decoded_content": self.decoded_content[:500] + "..." if self.decoded_content and len(self.decoded_content) > 500 else self.decoded_content,
            "findings": self.findings,
            "total_findings": len(self.findings),
            "max_severity": max_severity,
            "recommendation": self._get_recommendation(max_severity)
        }
    
    def _get_recommendation(self, severity: str) -> str:
        """Get recommendation based on severity."""
        recommendations = {
            "critical": "IMMEDIATE ACTION REQUIRED: Isolate affected systems, block identified IOCs, and conduct full incident response.",
            "high": "HIGH PRIORITY: Block identified IOCs at network and endpoint level. Review affected systems for compromise.",
            "medium": "MONITOR: Add IOCs to detection rules. Monitor for related activity.",
            "low": "REVIEW: Log for future reference. Consider adding to threat intelligence.",
        }
        return recommendations.get(severity, "REVIEW: Analyze findings and determine appropriate action.")


def main():
    parser = argparse.ArgumentParser(
        description="Analyze clipboard hijacking payloads for pastejacking attacks."
    )
    parser.add_argument(
        "payload",
        nargs="?",
        help="Payload string to analyze (e.g., 'powershell -enc <BASE64>')"
    )
    parser.add_argument(
        "-f", "--file",
        help="Read payload from file"
    )
    parser.add_argument(
        "--decode",
        help="Decode a Base64 string (PowerShell UTF-16 LE)"
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results as JSON"
    )
    
    args = parser.parse_args()
    
    # Handle decode-only mode
    if args.decode:
        try:
            decoded = base64.b64decode(args.decode).decode('utf-16-le', errors='ignore')
            print(decoded)
            return
        except Exception as e:
            print(f"Error decoding: {e}", file=sys.stderr)
            sys.exit(1)
    
    # Read payload
    payload = ""
    if args.file:
        try:
            payload = Path(args.file).read_text()
        except Exception as e:
            print(f"Error reading file: {e}", file=sys.stderr)
            sys.exit(1)
    elif args.payload:
        payload = args.payload
    else:
        # Read from stdin
        payload = sys.stdin.read()
    
    if not payload.strip():
        print("No payload provided", file=sys.stderr)
        sys.exit(1)
    
    # Analyze
    analyzer = PayloadAnalyzer()
    report = analyzer.analyze(payload)
    
    # Output
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        print("=" * 60)
        print("CLIPBOARD HIJACKING PAYLOAD ANALYSIS")
        print("=" * 60)
        print(f"\nTotal Findings: {report['total_findings']}")
        print(f"Max Severity: {report['max_severity'].upper()}")
        print(f"\nRecommendation: {report['recommendation']}")
        
        if report['findings']:
            print("\n" + "-" * 60)
            print("FINDINGS:")
            print("-" * 60)
            for i, finding in enumerate(report['findings'], 1):
                print(f"\n{i}. [{finding['severity'].upper()}] {finding['type']}")
                print(f"   {finding['description']}")
                if 'pattern' in finding:
                    print(f"   Pattern: {finding['pattern']}")
                if 'decoded_preview' in finding:
                    print(f"   Decoded preview: {finding['decoded_preview']}")
        
        if report['decoded_content']:
            print("\n" + "-" * 60)
            print("DECODED CONTENT:")
            print("-" * 60)
            print(report['decoded_content'])


if __name__ == "__main__":
    main()
