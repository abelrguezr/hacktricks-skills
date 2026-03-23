#!/usr/bin/env python3
"""
Analyze kernel traces for potential TOCTOU vulnerabilities.

This script parses kernel traces (ETW, hypervisor traces, or symbol dumps)
to identify potential Time-of-Check-Time-of-Use vulnerabilities in
Windows kernel drivers.

Usage:
    python analyze_kernel_trace.py --trace "trace.etl" --output "analysis.json"
"""

import argparse
import json
import re
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import List, Optional, Dict, Any


@dataclass
class VulnerabilityCandidate:
    """Represents a potential TOCTOU vulnerability."""
    function_name: str
    file_path: str
    line_number: int
    check_function: str
    use_function: str
    gap_description: str
    severity: str  # "high", "medium", "low"
    confidence: float  # 0.0 to 1.0
    
    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


@dataclass
class RaceWindow:
    """Represents a measured race window."""
    location: str
    min_time_us: float
    max_time_us: float
    avg_time_us: float
    
    def to_dict(self) -> Dict[str, Any]:
        return asdict(self)


class KernelTraceAnalyzer:
    """Analyzes kernel traces for TOCTOU vulnerabilities."""
    
    # Patterns that indicate potential TOCTOU vulnerabilities
    TOCTOU_PATTERNS = [
        # Check-then-open patterns
        (r"(ObfReferenceObject|ObReferenceObjectByPointer).*?NtOpen", "check-then-open"),
        (r"(IoIsFileInSession|IoCheckShareAccess).*?NtCreate", "check-then-create"),
        (r"(SePrivilegeCheck|SeAccessCheck).*?NtOpen", "privilege-check-then-open"),
        
        # Object Manager operations
        (r"ObOpenObjectByName.*?ObReferenceObject", "open-then-reference"),
        (r"NtOpenEvent.*?NtSetEvent", "open-then-set"),
        (r"NtOpenSection.*?NtMapViewOfSection", "open-then-map"),
        
        # Security descriptor checks
        (r"(SeCompareSecurityDescriptor|SeAccessCheck).*?Nt\w+", "security-check-then-action"),
    ]
    
    # Functions that are commonly involved in race conditions
    RACE_RELEVANT_FUNCTIONS = [
        "NtOpenEvent",
        "NtOpenSection",
        "NtOpenSemaphore",
        "NtOpenMutant",
        "NtOpenKey",
        "NtOpenFile",
        "NtCreateEvent",
        "NtCreateSection",
        "ObOpenObjectByName",
        "ObReferenceObjectByName",
    ]
    
    def __init__(self):
        self.candidates: List[VulnerabilityCandidate] = []
        self.race_windows: List[RaceWindow] = []
        self.statistics: Dict[str, Any] = {}
    
    def analyze_source_code(self, source_text: str) -> List[VulnerabilityCandidate]:
        """
        Analyze source code for potential TOCTOU patterns.
        
        Args:
            source_text: The source code to analyze
            
        Returns:
            List of vulnerability candidates
        """
        candidates = []
        lines = source_text.split('\n')
        
        for i, line in enumerate(lines):
            for pattern, pattern_type in self.TOCTOU_PATTERNS:
                if re.search(pattern, line, re.IGNORECASE | re.DOTALL):
                    candidate = VulnerabilityCandidate(
                        function_name=self._extract_function_name(line),
                        file_path="unknown",
                        line_number=i + 1,
                        check_function=self._extract_check_function(pattern_type),
                        use_function=self._extract_use_function(pattern_type),
                        gap_description=f"Potential {pattern_type} pattern detected",
                        severity="medium",
                        confidence=0.6
                    )
                    candidates.append(candidate)
        
        return candidates
    
    def analyze_trace_file(self, trace_path: str) -> Dict[str, Any]:
        """
        Analyze a trace file for race condition indicators.
        
        Args:
            trace_path: Path to the trace file
            
        Returns:
            Analysis results
        """
        results = {
            "trace_path": trace_path,
            "status": "error",
            "message": "",
            "candidates": [],
            "statistics": {},
        }
        
        try:
            path = Path(trace_path)
            if not path.exists():
                results["message"] = f"Trace file not found: {trace_path}"
                return results
            
            # Read trace file
            with open(trace_path, 'r', encoding='utf-8', errors='ignore') as f:
                content = f.read()
            
            # Analyze content
            candidates = self.analyze_source_code(content)
            results["candidates"] = [c.to_dict() for c in candidates]
            results["status"] = "success"
            results["message"] = f"Found {len(candidates)} potential vulnerabilities"
            results["statistics"] = {
                "total_candidates": len(candidates),
                "high_severity": sum(1 for c in candidates if c.severity == "high"),
                "medium_severity": sum(1 for c in candidates if c.severity == "medium"),
                "low_severity": sum(1 for c in candidates if c.severity == "low"),
            }
            
        except Exception as e:
            results["message"] = f"Error analyzing trace: {str(e)}"
        
        return results
    
    def _extract_function_name(self, line: str) -> str:
        """Extract function name from a line of code."""
        # Simple heuristic: look for function-like patterns
        match = re.search(r'\b(\w+)(?:\(|::)', line)
        return match.group(1) if match else "unknown"
    
    def _extract_check_function(self, pattern_type: str) -> str:
        """Extract the check function from a pattern type."""
        mapping = {
            "check-then-open": "ObfReferenceObject",
            "check-then-create": "IoIsFileInSession",
            "privilege-check-then-open": "SePrivilegeCheck",
            "open-then-reference": "ObOpenObjectByName",
            "open-then-set": "NtOpenEvent",
            "open-then-map": "NtOpenSection",
            "security-check-then-action": "SeAccessCheck",
        }
        return mapping.get(pattern_type, "unknown")
    
    def _extract_use_function(self, pattern_type: str) -> str:
        """Extract the use function from a pattern type."""
        mapping = {
            "check-then-open": "NtOpen*",
            "check-then-create": "NtCreate*",
            "privilege-check-then-open": "NtOpen*",
            "open-then-reference": "ObReferenceObject",
            "open-then-set": "NtSetEvent",
            "open-then-map": "NtMapViewOfSection",
            "security-check-then-action": "Nt*",
        }
        return mapping.get(pattern_type, "unknown")


def main():
    parser = argparse.ArgumentParser(
        description="Analyze kernel traces for TOCTOU vulnerabilities"
    )
    parser.add_argument(
        "--trace",
        type=str,
        default=None,
        help="Path to trace file to analyze"
    )
    parser.add_argument(
        "--source",
        type=str,
        default=None,
        help="Path to source code file to analyze"
    )
    parser.add_argument(
        "--output",
        type=str,
        default="analysis.json",
        help="Output JSON file path (default: analysis.json)"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print detailed output"
    )
    
    args = parser.parse_args()
    
    analyzer = KernelTraceAnalyzer()
    results = {
        "analysis_type": "kernel_trace",
        "timestamp": "2025-01-01T00:00:00Z",
        "candidates": [],
        "statistics": {},
    }
    
    if args.trace:
        print(f"Analyzing trace file: {args.trace}")
        trace_results = analyzer.analyze_trace_file(args.trace)
        results["candidates"] = trace_results.get("candidates", [])
        results["statistics"] = trace_results.get("statistics", {})
        
        if args.verbose:
            print(f"Status: {trace_results['status']}")
            print(f"Message: {trace_results['message']}")
    
    if args.source:
        print(f"Analyzing source file: {args.source}")
        try:
            with open(args.source, 'r') as f:
                source_content = f.read()
            
            candidates = analyzer.analyze_source_code(source_content)
            results["candidates"].extend([c.to_dict() for c in candidates])
            
            if args.verbose:
                print(f"Found {len(candidates)} potential vulnerabilities")
                for c in candidates:
                    print(f"  - Line {c.line_number}: {c.gap_description}")
                    
        except Exception as e:
            print(f"Error reading source file: {e}")
    
    # Calculate overall statistics
    if results["candidates"]:
        results["statistics"] = {
            "total_candidates": len(results["candidates"]),
            "high_severity": sum(1 for c in results["candidates"] if c.get("severity") == "high"),
            "medium_severity": sum(1 for c in results["candidates"] if c.get("severity") == "medium"),
            "low_severity": sum(1 for c in results["candidates"] if c.get("severity") == "low"),
        }
    
    # Save results
    with open(args.output, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\nAnalysis complete. Results saved to: {args.output}")
    print(f"Total candidates: {results['statistics'].get('total_candidates', 0)}")


if __name__ == "__main__":
    main()
