#!/usr/bin/env python3
"""
Simulate precision drift scenarios in Uniswap v4 hooks.

Usage:
    python scripts/simulate_rounding_drift.py \
        --iterations 1000 \
        --swap-size 1000000000000000000 \
        --output drift_analysis.json
"""

import argparse
import json
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import List, Dict, Any
import math


@dataclass
class DriftSimulation:
    """Results from a precision drift simulation."""
    iteration: int
    input_amount: int
    expected_output: int
    actual_output: int
    rounding_error: int
    cumulative_error: int
    tick_before: int
    tick_after: int
    crossed_boundary: bool


def simulate_floor_rounding(
    iterations: int,
    swap_size: int,
    initial_balance: int = 10_000_000_000_000_000_000,
    shares: int = 1_000_000_000_000_000_000,
    total_supply: int = 10_000_000_000_000_000_000
) -> List[DriftSimulation]:
    """
    Simulate floor rounding drift similar to Bunni V2 vulnerability.
    
    The vulnerability: balance.mulDiv(shares, totalSupply) floors,
    allowing repeated micro-withdrawals to ratchet balance downward.
    """
    results = []
    balance = initial_balance
    cumulative_error = 0
    
    for i in range(iterations):
        # Simulate withdrawal with floor rounding (vulnerable)
        # newBalance = balance - balance.mulDiv(shares, totalSupply)
        withdrawal_amount = (balance * shares) // total_supply  # Floor division
        
        # Expected (high precision)
        expected_withdrawal = balance * shares / total_supply
        
        # Rounding error (what the user "lost" to floor)
        rounding_error = expected_withdrawal - withdrawal_amount
        cumulative_error += rounding_error
        
        # Update balance
        balance -= withdrawal_amount
        
        results.append(DriftSimulation(
            iteration=i,
            input_amount=shares,
            expected_output=int(expected_withdrawal),
            actual_output=int(withdrawal_amount),
            rounding_error=int(rounding_error),
            cumulative_error=int(cumulative_error),
            tick_before=0,
            tick_after=0,
            crossed_boundary=False
        ))
        
        # Stop if balance gets too small
        if balance < 10:
            break
    
    return results


def simulate_ceil_rounding(
    iterations: int,
    swap_size: int,
    initial_balance: int = 10_000_000_000_000_000_000,
    shares: int = 1_000_000_000_000_000_000,
    total_supply: int = 10_000_000_000_000_000_000
) -> List[DriftSimulation]:
    """
    Simulate ceil rounding (fixed version).
    
    The fix: balance.mulDivUp(shares, totalSupply) rounds up,
    preventing downward ratcheting.
    """
    results = []
    balance = initial_balance
    cumulative_error = 0
    
    for i in range(iterations):
        # Simulate withdrawal with ceil rounding (fixed)
        # newBalance = balance - balance.mulDivUp(shares, totalSupply)
        withdrawal_amount = (balance * shares + total_supply - 1) // total_supply  # Ceil division
        
        # Expected (high precision)
        expected_withdrawal = balance * shares / total_supply
        
        # Rounding error (what the user "paid" extra for ceil)
        rounding_error = withdrawal_amount - expected_withdrawal
        cumulative_error += rounding_error
        
        # Update balance
        balance -= withdrawal_amount
        
        results.append(DriftSimulation(
            iteration=i,
            input_amount=shares,
            expected_output=int(expected_withdrawal),
            actual_output=int(withdrawal_amount),
            rounding_error=int(rounding_error),
            cumulative_error=int(cumulative_error),
            tick_before=0,
            tick_after=0,
            crossed_boundary=False
        ))
        
        if balance < 10:
            break
    
    return results


def simulate_tick_boundary_crossing(
    iterations: int,
    swap_size: int,
    initial_tick: int = 0,
    tick_spacing: int = 10
) -> List[DriftSimulation]:
    """
    Simulate tick boundary crossing with potential rounding drift.
    """
    results = []
    tick = initial_tick
    cumulative_error = 0
    
    for i in range(iterations):
        tick_before = tick
        
        # Simulate price movement
        # In real scenario, this would use sqrtPriceX96 math
        tick_delta = 1  # Move 1 tick per iteration
        tick_after = tick + tick_delta
        
        # Check if we crossed a tick spacing boundary
        crossed_boundary = (tick_before // tick_spacing) != (tick_after // tick_spacing)
        
        # Simulate rounding error at boundary
        if crossed_boundary:
            # At boundaries, rounding might favor caller
            rounding_error = swap_size // 1_000_000  # Small error at boundary
        else:
            rounding_error = 0
        
        cumulative_error += rounding_error
        tick = tick_after
        
        results.append(DriftSimulation(
            iteration=i,
            input_amount=swap_size,
            expected_output=swap_size,
            actual_output=swap_size + rounding_error,
            rounding_error=rounding_error,
            cumulative_error=cumulative_error,
            tick_before=tick_before,
            tick_after=tick_after,
            crossed_boundary=crossed_boundary
        ))
    
    return results


def analyze_results(
    floor_results: List[DriftSimulation],
    ceil_results: List[DriftSimulation],
    boundary_results: List[DriftSimulation]
) -> Dict[str, Any]:
    """Analyze simulation results and generate summary."""
    
    # Floor rounding analysis
    floor_cumulative = floor_results[-1].cumulative_error if floor_results else 0
    floor_iterations = len(floor_results)
    
    # Ceil rounding analysis
    ceil_cumulative = ceil_results[-1].cumulative_error if ceil_results else 0
    ceil_iterations = len(ceil_results)
    
    # Boundary crossing analysis
    boundary_crossings = sum(1 for r in boundary_results if r.crossed_boundary)
    boundary_cumulative = boundary_results[-1].cumulative_error if boundary_results else 0
    
    return {
        "floor_rounding": {
            "iterations": floor_iterations,
            "cumulative_error": floor_cumulative,
            "error_per_iteration": floor_cumulative / floor_iterations if floor_iterations > 0 else 0,
            "vulnerability": "HIGH - Floor rounding allows balance to ratchet downward"
        },
        "ceil_rounding": {
            "iterations": ceil_iterations,
            "cumulative_error": ceil_cumulative,
            "error_per_iteration": ceil_cumulative / ceil_iterations if ceil_iterations > 0 else 0,
            "vulnerability": "LOW - Ceil rounding prevents downward ratcheting"
        },
        "boundary_crossing": {
            "total_iterations": len(boundary_results),
            "boundary_crossings": boundary_crossings,
            "cumulative_error": boundary_cumulative,
            "error_per_crossing": boundary_cumulative / boundary_crossings if boundary_crossings > 0 else 0,
            "vulnerability": "MEDIUM - Boundary crossings may accumulate rounding error"
        },
        "recommendations": [
            "Use mulDivUp instead of mulDiv for balance calculations",
            "Test ±1 wei around all tick boundaries",
            "Burn or treasury rounding residue instead of crediting caller",
            "Implement invariant checks for balance conservation"
        ]
    }


def main():
    parser = argparse.ArgumentParser(
        description="Simulate precision drift in Uniswap v4 hooks"
    )
    parser.add_argument(
        "--iterations", "-i",
        type=int,
        default=1000,
        help="Number of iterations to simulate (default: 1000)"
    )
    parser.add_argument(
        "--swap-size", "-s",
        type=int,
        default=1_000_000_000_000_000_000,
        help="Swap size in wei (default: 1 token)"
    )
    parser.add_argument(
        "--output", "-o",
        type=Path,
        default=Path("drift_analysis.json"),
        help="Output path for analysis results"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Print detailed results"
    )
    
    args = parser.parse_args()
    
    print(f"Running precision drift simulation...")
    print(f"  Iterations: {args.iterations}")
    print(f"  Swap size: {args.swap_size}")
    print()
    
    # Run simulations
    floor_results = simulate_floor_rounding(args.iterations, args.swap_size)
    ceil_results = simulate_ceil_rounding(args.iterations, args.swap_size)
    boundary_results = simulate_tick_boundary_crossing(args.iterations, args.swap_size)
    
    # Analyze results
    analysis = analyze_results(floor_results, ceil_results, boundary_results)
    
    # Prepare output
    output = {
        "simulation_params": {
            "iterations": args.iterations,
            "swap_size": args.swap_size
        },
        "analysis": analysis,
        "floor_results_sample": [asdict(r) for r in floor_results[:10]],
        "ceil_results_sample": [asdict(r) for r in ceil_results[:10]],
        "boundary_results_sample": [asdict(r) for r in boundary_results[:10]]
    }
    
    # Save results
    output_path = args.output
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(output, indent=2))
    
    print(f"Results saved to: {output_path}")
    print()
    
    # Print summary
    print("=" * 60)
    print("SIMULATION SUMMARY")
    print("=" * 60)
    print()
    print(f"Floor Rounding (Vulnerable):")
    print(f"  Cumulative error: {analysis['floor_rounding']['cumulative_error']}")
    print(f"  Error per iteration: {analysis['floor_rounding']['error_per_iteration']:.2f}")
    print(f"  Risk: {analysis['floor_rounding']['vulnerability']}")
    print()
    print(f"Ceil Rounding (Fixed):")
    print(f"  Cumulative error: {analysis['ceil_rounding']['cumulative_error']}")
    print(f"  Error per iteration: {analysis['ceil_rounding']['error_per_iteration']:.2f}")
    print(f"  Risk: {analysis['ceil_rounding']['vulnerability']}")
    print()
    print(f"Boundary Crossing:")
    print(f"  Crossings: {analysis['boundary_crossing']['boundary_crossings']}")
    print(f"  Cumulative error: {analysis['boundary_crossing']['cumulative_error']}")
    print(f"  Risk: {analysis['boundary_crossing']['vulnerability']}")
    print()
    print("Recommendations:")
    for rec in analysis["recommendations"]:
        print(f"  - {rec}")


if __name__ == "__main__":
    main()
