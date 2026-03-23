#!/usr/bin/env python3
"""
Analyze Uniswap v4 hook implementations for precision/rounding vulnerabilities.

Usage:
    python scripts/analyze_hook_math.py --hook-address <address> --abi <path>
    python scripts/analyze_hook_math.py --bytecode <path>  # for on-chain bytecode
    python scripts/analyze_hook_math.py --source <path>    # for Solidity source
"""

import argparse
import json
import re
from pathlib import Path
from typing import Optional, List, Dict, Any

# Risk patterns to detect
RISK_PATTERNS = {
    "mulDiv_floor": {
        "regex": r"\.mulDiv\s*\(",
        "risk": "HIGH",
        "description": "mulDiv floors by default; check if rounding should be against user",
        "recommendation": "Use mulDivUp for calculations that should round against the caller"
    },
    "mulDivUp_ceil": {
        "regex": r"\.mulDivUp\s*\(",
        "risk": "MEDIUM",
        "description": "mulDivUp ceils; ensure consistent rounding policy",
        "recommendation": "Document rounding direction; ensure all paths round against user"
    },
    "SafeCast_conversion": {
        "regex": r"SafeCast\.(toUint256|toInt256)\s*\(",
        "risk": "MEDIUM",
        "description": "Type conversions may lose precision or overflow",
        "recommendation": "Verify bounds before casting; check for overflow conditions"
    },
    "BalanceDelta_credit": {
        "regex": r"BalanceDelta|balanceDelta|delta\s*[+\-]=",
        "risk": "CRITICAL",
        "description": "BalanceDelta tracking may credit caller with rounding residue",
        "recommendation": "Ensure delta settlement is neutral; burn or treasury residue"
    },
    "sqrtPriceX96": {
        "regex": r"sqrtPriceX96|sqrtPrice",
        "risk": "MEDIUM",
        "description": "Q64.96 fixed-point conversions may lose precision",
        "recommendation": "Verify bidirectional conversion accuracy"
    },
    "tick_boundary": {
        "regex": r"tick\s*[=<>!]=|tickSpacing",
        "risk": "HIGH",
        "description": "Tick boundary logic may have rounding inconsistencies",
        "recommendation": "Test ±1 wei around all tick boundaries"
    },
    "user_credit": {
        "regex": r"credits\[msg\.sender\]|userCredits|credits\[initiator\]",
        "risk": "CRITICAL",
        "description": "Direct credit to caller may accumulate rounding residue",
        "recommendation": "Never attribute rounding residue to msg.sender"
    },
    "division_truncation": {
        "regex": r"\s/\s(?!/)",
        "risk": "HIGH",
        "description": "Integer division truncates; may favor caller",
        "recommendation": "Use explicit rounding or mulDiv with documented direction"
    }
}

# Callback patterns indicating hook activity
CALLBACK_PATTERNS = [
    "beforeSwap",
    "afterSwap",
    "beforeAddLiquidity",
    "afterAddLiquidity",
    "beforeRemoveLiquidity",
    "afterRemoveLiquidity",
    "beforeInitialize",
    "afterInitialize",
    "beforeDonate",
    "afterDonate"
]


def analyze_source_code(source_path: Path) -> Dict[str, Any]:
    """Analyze Solidity source code for vulnerability patterns."""
    content = source_path.read_text()
    
    findings = []
    callbacks_found = []
    
    # Check for callbacks
    for callback in CALLBACK_PATTERNS:
        if callback in content:
            callbacks_found.append(callback)
    
    # Check for risk patterns
    for pattern_name, pattern_info in RISK_PATTERNS.items():
        matches = re.finditer(pattern_info["regex"], content, re.IGNORECASE)
        for match in matches:
            # Get context (line number and surrounding code)
            line_start = content.rfind("\n", 0, match.start()) + 1
            line_end = content.find("\n", match.end())
            if line_end == -1:
                line_end = len(content)
            line_num = content[:match.start()].count("\n") + 1
            context = content[line_start:line_end].strip()
            
            findings.append({
                "pattern": pattern_name,
                "risk": pattern_info["risk"],
                "description": pattern_info["description"],
                "recommendation": pattern_info["recommendation"],
                "line": line_num,
                "context": context[:100] + "..." if len(context) > 100 else context
            })
    
    return {
        "file": str(source_path),
        "callbacks": callbacks_found,
        "findings": findings,
        "summary": {
            "total_findings": len(findings),
            "critical": sum(1 for f in findings if f["risk"] == "CRITICAL"),
            "high": sum(1 for f in findings if f["risk"] == "HIGH"),
            "medium": sum(1 for f in findings if f["risk"] == "MEDIUM"),
            "low": sum(1 for f in findings if f["risk"] == "LOW")
        }
    }


def analyze_abi(abi_path: Path) -> Dict[str, Any]:
    """Analyze hook ABI for callback signatures."""
    abi = json.loads(abi_path.read_text())
    
    callbacks_found = []
    functions = []
    
    for item in abi:
        if item.get("type") == "function":
            name = item.get("name", "")
            functions.append(name)
            
            if name in CALLBACK_PATTERNS:
                callbacks_found.append({
                    "name": name,
                    "inputs": item.get("inputs", []),
                    "outputs": item.get("outputs", [])
                })
    
    return {
        "file": str(abi_path),
        "callbacks": callbacks_found,
        "functions": functions,
        "summary": {
            "total_callbacks": len(callbacks_found),
            "total_functions": len(functions)
        }
    }


def generate_report(analysis_results: List[Dict[str, Any]], output_path: Optional[Path] = None) -> str:
    """Generate a human-readable audit report."""
    report_lines = [
        "# Hook Precision Audit Report",
        "",
        "## Summary"
    ]
    
    total_critical = 0
    total_high = 0
    total_medium = 0
    
    for result in analysis_results:
        if "summary" in result:
            total_critical += result["summary"].get("critical", 0)
            total_high += result["summary"].get("high", 0)
            total_medium += result["summary"].get("medium", 0)
    
    report_lines.append(f"- **Critical findings**: {total_critical}")
    report_lines.append(f"- **High findings**: {total_high}")
    report_lines.append(f"- **Medium findings**: {total_medium}")
    report_lines.append("")
    
    for result in analysis_results:
        report_lines.append(f"## File: {result.get('file', 'Unknown')}")
        report_lines.append("")
        
        if "callbacks" in result:
            callbacks = result["callbacks"]
            if isinstance(callbacks, list) and callbacks and isinstance(callbacks[0], dict):
                report_lines.append("### Detected Callbacks")
                for cb in callbacks:
                    report_lines.append(f"- `{cb['name']}`")
            elif isinstance(callbacks, list):
                report_lines.append("### Detected Callbacks")
                for cb in callbacks:
                    report_lines.append(f"- `{cb}`")
            report_lines.append("")
        
        if "findings" in result:
            report_lines.append("### Findings")
            for finding in result["findings"]:
                risk_marker = {"CRITICAL": "🔴", "HIGH": "🟠", "MEDIUM": "🟡", "LOW": "🟢"}.get(finding["risk"], "⚪")
                report_lines.append(f"#### {risk_marker} {finding['pattern']} (Line {finding['line']})")
                report_lines.append(f"**Risk**: {finding['risk']}")
                report_lines.append(f"**Description**: {finding['description']}")
                report_lines.append(f"**Recommendation**: {finding['recommendation']}")
                report_lines.append(f"**Context**: `{finding['context']}`")
                report_lines.append("")
    
    report = "\n".join(report_lines)
    
    if output_path:
        output_path.write_text(report)
        print(f"Report saved to: {output_path}")
    
    return report


def main():
    parser = argparse.ArgumentParser(
        description="Analyze Uniswap v4 hooks for precision/rounding vulnerabilities"
    )
    parser.add_argument(
        "--source", "-s",
        type=Path,
        help="Path to Solidity source file"
    )
    parser.add_argument(
        "--abi", "-a",
        type=Path,
        help="Path to hook ABI JSON file"
    )
    parser.add_argument(
        "--bytecode", "-b",
        type=Path,
        help="Path to bytecode file (not yet implemented)"
    )
    parser.add_argument(
        "--output", "-o",
        type=Path,
        help="Output path for report (default: stdout)"
    )
    
    args = parser.parse_args()
    
    if not any([args.source, args.abi, args.bytecode]):
        parser.print_help()
        print("\nError: At least one of --source, --abi, or --bytecode is required")
        return 1
    
    results = []
    
    if args.source:
        if not args.source.exists():
            print(f"Error: Source file not found: {args.source}")
            return 1
        results.append(analyze_source_code(args.source))
    
    if args.abi:
        if not args.abi.exists():
            print(f"Error: ABI file not found: {args.abi}")
            return 1
        results.append(analyze_abi(args.abi))
    
    if args.bytecode:
        print("Warning: Bytecode analysis not yet implemented")
    
    report = generate_report(results, args.output)
    print(report)
    
    return 0


if __name__ == "__main__":
    exit(main())
