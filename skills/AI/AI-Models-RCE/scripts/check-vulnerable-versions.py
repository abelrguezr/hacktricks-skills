#!/usr/bin/env python3
"""
Audit codebase for vulnerable ML model loading patterns.

Usage:
    python check-vulnerable-versions.py --path /path/to/codebase
    python check-vulnerable-versions.py --check-deps requirements.txt
"""

import argparse
import os
import re
import sys
from pathlib import Path
from typing import List, Dict, Tuple


# Vulnerable patterns to detect
VULNERABLE_PATTERNS = {
    "torch.load_no_weights_only": {
        "pattern": r"torch\.load\s*\([^)]*\)",
        "safe_pattern": r"weights_only\s*=\s*True",
        "severity": "HIGH",
        "description": "torch.load() without weights_only=True may deserialize pickle",
        "cve": "CVE-2025-32434",
        "fix": "Add weights_only=True or use torch.load_safe()",
    },
    "pickle_load": {
        "pattern": r"pickle\.load\s*\(",
        "severity": "HIGH",
        "description": "pickle.load() executes arbitrary code during deserialization",
        "fix": "Use JSON or other non-executable format; validate source",
    },
    "joblib_load": {
        "pattern": r"joblib\.load\s*\(",
        "severity": "HIGH",
        "description": "joblib.load() uses pickle internally",
        "fix": "Validate source; consider alternative serialization",
    },
    "yaml_unsafe_load": {
        "pattern": r"yaml\.(unsafe_load|load)\s*\([^)]*Loader",
        "severity": "HIGH",
        "description": "yaml.unsafe_load() or yaml.load() with Loader executes code",
        "cve": "CVE-2021-37678",
        "fix": "Use yaml.safe_load() instead",
    },
    "hydra_instantiate": {
        "pattern": r"hydra\.utils\.instantiate\s*\(",
        "severity": "MEDIUM",
        "description": "hydra.utils.instantiate() can execute arbitrary imports",
        "cve": "CVE-2025-23304",
        "fix": "Validate config source; restrict _target_ values",
    },
    "np_load_no_allow_pickle": {
        "pattern": r"np\.load\s*\([^)]*\)",
        "safe_pattern": r"allow_pickle\s*=\s*False",
        "severity": "MEDIUM",
        "description": "numpy.load() may deserialize pickle if allow_pickle not False",
        "cve": "CVE-2019-6446",
        "fix": "Add allow_pickle=False",
    },
    "keras_model_from_yaml": {
        "pattern": r"keras\.models\.model_from_yaml\s*\(",
        "severity": "HIGH",
        "description": "model_from_yaml() uses unsafe YAML deserialization",
        "fix": "Validate YAML source; use safe loading",
    },
    "keras_lambda": {
        "pattern": r"layers\.Lambda\s*\(",
        "severity": "MEDIUM",
        "description": "Lambda layers can execute arbitrary code on load",
        "cve": "CVE-2024-3660",
        "fix": "Avoid Lambda layers with untrusted models",
    },
}

# Vulnerable version ranges
VULNERABLE_VERSIONS = {
    "invokeai": {
        "vulnerable": ("5.3.1", "5.4.2"),
        "safe": "5.4.3+",
        "cve": "CVE-2024-12029",
    },
    "transformers4rec": {
        "vulnerable": "< PR #802",
        "safe": "Post-PR #802",
        "cve": "CVE-2025-23298",
    },
}


def scan_file(filepath: Path) -> List[Dict]:
    """Scan a single file for vulnerable patterns."""
    findings = []
    
    try:
        with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
            lines = content.split("\n")
    except Exception as e:
        return findings
    
    for name, config in VULNERABLE_PATTERNS.items():
        pattern = re.compile(config["pattern"], re.IGNORECASE)
        
        for line_num, line in enumerate(lines, 1):
            if pattern.search(line):
                # Check if safe pattern is present
                is_safe = False
                if "safe_pattern" in config:
                    safe_match = re.search(config["safe_pattern"], line, re.IGNORECASE)
                    if safe_match:
                        is_safe = True
                
                if not is_safe:
                    findings.append({
                        "file": str(filepath),
                        "line": line_num,
                        "pattern": name,
                        "severity": config["severity"],
                        "description": config["description"],
                        "cve": config.get("cve", ""),
                        "fix": config.get("fix", ""),
                        "code": line.strip(),
                    })
    
    return findings


def scan_directory(path: Path) -> List[Dict]:
    """Recursively scan directory for vulnerable patterns."""
    all_findings = []
    
    # Python file extensions to scan
    extensions = {".py", ".ipynb"}
    
    for root, dirs, files in os.walk(path):
        # Skip common non-source directories
        dirs[:] = [d for d in dirs if d not in {".git", "__pycache__", "node_modules", ".venv", "venv"}]
        
        for filename in files:
            if Path(filename).suffix in extensions:
                filepath = Path(root) / filename
                findings = scan_file(filepath)
                all_findings.extend(findings)
    
    return all_findings


def check_requirements(filepath: Path) -> List[Dict]:
    """Check requirements.txt for vulnerable package versions."""
    findings = []
    
    try:
        with open(filepath, "r") as f:
            content = f.read()
    except Exception:
        return findings
    
    for line in content.split("\n"):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        
        # Parse package name and version
        match = re.match(r"([a-zA-Z0-9_-]+)([=<>!~]+)?(.*)", line)
        if not match:
            continue
        
        package = match.group(1).lower()
        version_spec = match.group(3).strip() if match.group(3) else ""
        
        # Check against known vulnerable packages
        if package in VULNERABLE_VERSIONS:
            vuln_info = VULNERABLE_VERSIONS[package]
            findings.append({
                "file": str(filepath),
                "line": content.split("\n").index(line) + 1,
                "pattern": f"{package}_version",
                "severity": "HIGH",
                "description": f"{package} may have known vulnerabilities",
                "cve": vuln_info["cve"],
                "fix": f"Upgrade to {vuln_info['safe']}",
                "code": line,
            })
    
    return findings


def print_findings(findings: List[Dict]):
    """Print findings in a readable format."""
    if not findings:
        print("✅ No vulnerable patterns detected!")
        return
    
    # Group by severity
    by_severity = {"HIGH": [], "MEDIUM": [], "LOW": []}
    for f in findings:
        sev = f["severity"]
        if sev in by_severity:
            by_severity[sev].append(f)
    
    print(f"\n🔍 Found {len(findings)} potential vulnerability(ies):\n")
    
    for severity in ["HIGH", "MEDIUM", "LOW"]:
        if not by_severity[severity]:
            continue
        
        print(f"\n{'='*60}")
        print(f"🔴 {severity} SEVERITY ({len(by_severity[severity])} findings)")
        print(f"{'='*60}")
        
        for i, finding in enumerate(by_severity[severity], 1):
            print(f"\n[{i}] {finding['pattern']}")
            print(f"    File: {finding['file']}:{finding['line']}")
            if finding.get("cve"):
                print(f"    CVE: {finding['cve']}")
            print(f"    Issue: {finding['description']}")
            print(f"    Code: {finding['code'][:80]}..." if len(finding['code']) > 80 else f"    Code: {finding['code']}")
            if finding.get("fix"):
                print(f"    Fix: {finding['fix']}")
    
    print(f"\n{'='*60}")
    print(f"Summary: {len(by_severity['HIGH'])} HIGH, {len(by_severity['MEDIUM'])} MEDIUM")
    print(f"{'='*60}\n")


def main():
    parser = argparse.ArgumentParser(
        description="Audit codebase for vulnerable ML model loading patterns",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python check-vulnerable-versions.py --path /path/to/codebase
    python check-vulnerable-versions.py --check-deps requirements.txt
    python check-vulnerable-versions.py --path ./src --check-deps requirements.txt
        """
    )
    
    parser.add_argument(
        "--path", "-p",
        type=Path,
        help="Path to codebase directory to scan"
    )
    
    parser.add_argument(
        "--check-deps", "-d",
        type=Path,
        help="Path to requirements.txt to check for vulnerable versions"
    )
    
    args = parser.parse_args()
    
    all_findings = []
    
    if args.path:
        if not args.path.exists():
            print(f"[!] Path does not exist: {args.path}")
            sys.exit(1)
        
        print(f"[*] Scanning directory: {args.path}")
        findings = scan_directory(args.path)
        all_findings.extend(findings)
        print(f"    Found {len(findings)} potential issues")
    
    if args.check_deps:
        if not args.check_deps.exists():
            print(f"[!] File does not exist: {args.check_deps}")
            sys.exit(1)
        
        print(f"[*] Checking dependencies: {args.check_deps}")
        findings = check_requirements(args.check_deps)
        all_findings.extend(findings)
        print(f"    Found {len(findings)} potential issues")
    
    if not args.path and not args.check_deps:
        parser.print_help()
        sys.exit(1)
    
    print_findings(all_findings)
    
    # Exit with error code if HIGH severity findings
    high_count = sum(1 for f in all_findings if f["severity"] == "HIGH")
    sys.exit(1 if high_count > 0 else 0)


if __name__ == "__main__":
    main()
