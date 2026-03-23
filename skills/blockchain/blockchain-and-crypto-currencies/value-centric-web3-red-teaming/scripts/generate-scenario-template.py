#!/usr/bin/env python3
"""
Generate a detailed scenario execution template for Web3 red teaming.
Creates a structured markdown document for planning and documenting
a specific AADAPT-based attack scenario.
"""

import json
import argparse
from pathlib import Path
from datetime import datetime


SCENARIO_TEMPLATES = {
    "flash-loan": {
        "name": "Flash-Loan Economic Manipulation",
        "aadapt_techniques": ["T1505.003", "T1565.003"],
        "objective": "Borrow transient capital inside one transaction to distort AMM prices/liquidity and trigger mispriced borrows, liquidations, or mints before repaying.",
        "prerequisites": [
            "Forked mainnet or isolated testnet with production-like state",
            "Flash loan provider deployed or accessible",
            "Target protocol contracts deployed",
            "Liquidity seeded in relevant pools",
            "Telemetry instrumentation active"
        ],
        "execution_steps": [
            "1. Fork the target chain and seed pools with production-like liquidity",
            "2. Borrow large notional via flash loan (document amount and source)",
            "3. Perform calibrated swaps to cross price/threshold boundaries",
            "4. Invoke the victim contract immediately after distortion",
            "5. Repay the flash loan within the same transaction",
            "6. Verify transaction success/failure"
        ],
        "measurement_criteria": [
            "Invariant violation success/failure",
            "Slippage/price-deviation monitor triggers",
            "Circuit breaker activation",
            "Governance pause hook triggers",
            "Time to analytics flag abnormal patterns",
            "Gas usage patterns",
            "Call graph structure"
        ],
        "telemetry_requirements": [
            "Full transaction call graph",
            "Gas usage per step",
            "Price oracle values before/during/after",
            "Pool liquidity snapshots",
            "Transaction timestamps",
            "Alert generation timestamps"
        ]
    },
    "oracle-poisoning": {
        "name": "Oracle/Data-Feed Poisoning",
        "aadapt_techniques": ["T1565.003", "T1071.001"],
        "objective": "Determine whether manipulated feeds can trigger destructive automated actions (mass liquidations, incorrect settlements).",
        "prerequisites": [
            "Forked environment with oracle infrastructure",
            "Access to deploy malicious feed or modify aggregator",
            "Dependent contracts consuming oracle data",
            "Telemetry on oracle update streams"
        ],
        "execution_steps": [
            "1. Deploy malicious feed or adjust aggregator weights/quorum",
            "2. Modify update cadence beyond tolerated deviation",
            "3. Inject poisoned values into the feed",
            "4. Trigger dependent contract logic",
            "5. Observe automated actions taken",
            "6. Document all downstream effects"
        ],
        "measurement_criteria": [
            "Feed-level out-of-band alert generation",
            "Fallback oracle activation",
            "Min/max bound enforcement",
            "Latency between anomaly onset and detection",
            "Operator response time",
            "Automated action correctness"
        ],
        "telemetry_requirements": [
            "Per-update data source composition",
            "Reported values with timestamps",
            "Deviation from rolling averages",
            "Threshold trigger events",
            "Failover path activation",
            "Dependent contract execution logs"
        ]
    },
    "credential-abuse": {
        "name": "Credential/Signing Abuse",
        "aadapt_techniques": ["T1552", "T1098", "T1078"],
        "objective": "Test whether compromising a single signer or automation identity enables unauthorized upgrades, parameter changes, or treasury drains.",
        "prerequisites": [
            "Inventory of all signing identities",
            "Access to simulate credential compromise",
            "Test environment with signing infrastructure",
            "KMS/HSM logging enabled"
        ],
        "execution_steps": [
            "1. Enumerate identities with sensitive signing rights",
            "2. Simulate compromise of selected identity",
            "3. Attempt proxy upgrade transactions",
            "4. Attempt risk parameter changes",
            "5. Attempt asset minting or pausing",
            "6. Attempt governance proposal submission",
            "7. Document success/failure of each attempt"
        ],
        "measurement_criteria": [
            "KMS/HSM anomaly alert generation",
            "Time-of-day policy enforcement",
            "Destination drift detection",
            "Burst operation detection",
            "Multisig threshold enforcement",
            "Throttle/rate limit activation",
            "Additional approval requirements"
        ],
        "telemetry_requirements": [
            "Key ID for every signature",
            "Caller principal identification",
            "Policy result logging",
            "Destination address capture",
            "Reason code documentation",
            "Baseline deviation alerts"
        ]
    },
    "cross-chain": {
        "name": "Cross-Chain Evasion & Traceability",
        "aadapt_techniques": ["T1070", "T1562.003"],
        "objective": "Evaluate how well defenders can trace and interdict assets rapidly laundered across bridges, DEX routers, and privacy hops.",
        "prerequisites": [
            "Multi-chain test environment",
            "Bridge contracts deployed",
            "DEX/router access on each chain",
            "Cross-chain telemetry correlation setup"
        ],
        "execution_steps": [
            "1. Initiate lock/mint on source chain",
            "2. Execute swap/mixer on destination chain",
            "3. Chain additional bridge operations",
            "4. Interleave swaps/mixers on each hop",
            "5. Maintain correlation IDs throughout",
            "6. Accelerate transfers to stress latency",
            "7. Complete multi-hop within minutes/blocks"
        ],
        "measurement_criteria": [
            "Time to correlate events across telemetry",
            "Commercial chain analytics correlation time",
            "Path reconstruction completeness",
            "Choke point identification for freezing",
            "Alert fidelity for abnormal velocity",
            "Value tracking accuracy"
        ],
        "telemetry_requirements": [
            "Lock/mint/unlock event correlation",
            "Correlation ID tracking",
            "Chain ID logging",
            "Relayer identity capture",
            "Hop timing measurement",
            "Cross-chain event alignment"
        ]
    }
}


def generate_scenario_template(scenario_type: str, scenario_name: str = None) -> str:
    """Generate a detailed scenario execution template."""
    
    if scenario_type not in SCENARIO_TEMPLATES:
        raise ValueError(f"Unknown scenario type: {scenario_type}. Valid types: {list(SCENARIO_TEMPLATES.keys())}")
    
    template = SCENARIO_TEMPLATES[scenario_type]
    name = scenario_name or template["name"]
    
    lines = []
    lines.append(f"# Scenario: {name}")
    lines.append(f"Generated: {datetime.now().isoformat()}")
    lines.append("")
    lines.append(f"## AADAPT Techniques")
    lines.append("")
    for technique in template["aadapt_techniques"]:
        lines.append(f"- {technique}")
    lines.append("")
    
    lines.append("## Objective")
    lines.append("")
    lines.append(template["objective"])
    lines.append("")
    
    lines.append("## Prerequisites")
    lines.append("")
    for prereq in template["prerequisites"]:
        lines.append(f"- [ ] {prereq}")
    lines.append("")
    
    lines.append("## Execution Steps")
    lines.append("")
    for step in template["execution_steps"]:
        lines.append(f"- [ ] {step}")
    lines.append("")
    
    lines.append("## Measurement Criteria")
    lines.append("")
    for criterion in template["measurement_criteria"]:
        lines.append(f"- [ ] {criterion}")
    lines.append("")
    
    lines.append("## Telemetry Requirements")
    lines.append("")
    for req in template["telemetry_requirements"]:
        lines.append(f"- [ ] {req}")
    lines.append("")
    
    lines.append("## Results")
    lines.append("")
    lines.append("### Execution Outcome")
    lines.append("")
    lines.append("| Step | Status | Notes |")
    lines.append("|------|--------|-------|")
    for i, step in enumerate(template["execution_steps"], 1):
        lines.append(f"| {i} | | |")
    lines.append("")
    
    lines.append("### Measurement Results")
    lines.append("")
    lines.append("| Criterion | Result | Evidence |")
    lines.append("|-----------|--------|----------|")
    for criterion in template["measurement_criteria"]:
        lines.append(f"| {criterion} | | |")
    lines.append("")
    
    lines.append("### Detection Performance")
    lines.append("")
    lines.append("| Metric | Value | Target |")
    lines.append("|--------|-------|--------|")
    lines.append("| MTTD (Mean Time to Detect) | | |")
    lines.append("| MTTC (Mean Time to Contain) | | |")
    lines.append("| Alert Fidelity | | |")
    lines.append("")
    
    lines.append("### Findings")
    lines.append("")
    lines.append("")
    
    lines.append("### Recommendations")
    lines.append("")
    lines.append("")
    
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Generate a Web3 red teaming scenario template"
    )
    parser.add_argument(
        "scenario_type",
        choices=list(SCENARIO_TEMPLATES.keys()),
        help="Type of scenario to generate"
    )
    parser.add_argument(
        "-n", "--name",
        type=str,
        help="Custom scenario name (optional)"
    )
    parser.add_argument(
        "-o", "--output",
        type=Path,
        default=None,
        help="Output file path (default: <scenario_type>-scenario.md)"
    )
    
    args = parser.parse_args()
    
    template = generate_scenario_template(args.scenario_type, args.name)
    
    output_path = args.output or Path(f"{args.scenario_type}-scenario.md")
    output_path.write_text(template)
    print(f"Scenario template written to {output_path}")


if __name__ == "__main__":
    main()
