#!/usr/bin/env python3
"""
Futures vs Options Comparison Calculator

Compares risk/reward profiles between futures and options for the same underlying.
"""

import argparse
import json
import math


def calculate_futures_pnl(
    position_size: float,
    entry_price: float,
    exit_price: float,
    position_type: str = "long"
) -> dict:
    """
    Calculate futures P/L.
    
    Args:
        position_size: Notional value of position
        entry_price: Entry price per unit
        exit_price: Exit price per unit
        position_type: "long" or "short"
    
    Returns:
        Dictionary with P/L details
    """
    price_change = exit_price - entry_price
    price_change_percent = (price_change / entry_price) * 100
    
    if position_type == "long":
        pnl = position_size * (price_change / entry_price)
    else:
        pnl = position_size * (-price_change / entry_price)
    
    return {
        "instrument": "futures",
        "position_type": position_type,
        "position_size": position_size,
        "entry_price": entry_price,
        "exit_price": exit_price,
        "price_change_percent": price_change_percent,
        "profit_loss": pnl,
        "upfront_cost": 0,
        "net_pnl": pnl
    }


def calculate_options_pnl(
    position_size: float,
    entry_price: float,
    exit_price: float,
    strike_price: float,
    premium: float,
    option_type: str = "call"
) -> dict:
    """
    Calculate options P/L.
    
    Args:
        position_size: Notional value of position
        entry_price: Entry price per unit (current market price)
        exit_price: Exit price per unit
        strike_price: Strike price of option
        premium: Premium paid for option
        option_type: "call" or "put"
    
    Returns:
        Dictionary with P/L details
    """
    price_change = exit_price - entry_price
    price_change_percent = (price_change / entry_price) * 100
    
    # Calculate intrinsic value at exit
    if option_type == "call":
        intrinsic_value = max(0, exit_price - strike_price)
    else:  # put
        intrinsic_value = max(0, strike_price - exit_price)
    
    # Calculate P/L
    if intrinsic_value > 0:
        # Option is exercised
        gross_pnl = position_size * (intrinsic_value / entry_price)
        net_pnl = gross_pnl - premium
    else:
        # Option expires worthless
        net_pnl = -premium
    
    return {
        "instrument": "options",
        "option_type": option_type,
        "position_type": "long" if option_type == "call" else "short",
        "position_size": position_size,
        "entry_price": entry_price,
        "exit_price": exit_price,
        "strike_price": strike_price,
        "premium": premium,
        "price_change_percent": price_change_percent,
        "intrinsic_value": intrinsic_value,
        "profit_loss": net_pnl,
        "upfront_cost": premium,
        "net_pnl": net_pnl,
        "max_loss": premium,
        "is_exercised": intrinsic_value > 0
    }


def generate_comparison_table(
    position_size: float,
    entry_price: float,
    strike_price: float,
    premium: float,
    price_range: list
) -> list:
    """
    Generate comparison table for different exit prices.
    """
    comparisons = []
    
    for exit_price in price_range:
        futures_result = calculate_futures_pnl(
            position_size, entry_price, exit_price, "long"
        )
        
        options_result = calculate_options_pnl(
            position_size, entry_price, exit_price,
            strike_price, premium, "call"
        )
        
        comparisons.append({
            "exit_price": exit_price,
            "futures": futures_result,
            "options": options_result,
            "futures_advantage": futures_result["net_pnl"] - options_result["net_pnl"]
        })
    
    return comparisons


def print_comparison_table(comparisons: list):
    """
    Print comparison table in formatted output.
    """
    print("\n" + "=" * 100)
    print(f"{'Exit Price':<12} {'Price Change':<15} {'Futures P/L':<15} {'Options P/L':<15} {'Advantage':<15}")
    print("=" * 100)
    
    for comp in comparisons:
        price_change = f"{(comp['exit_price'] - comp['futures']['entry_price'])/comp['futures']['entry_price']*100:+.1f}%"
        futures_pnl = f"{comp['futures']['net_pnl']:+.2f}"
        options_pnl = f"{comp['options']['net_pnl']:+.2f}"
        
        if comp['futures_advantage'] > 0:
            advantage = f"Futures +{comp['futures_advantage']:.2f}"
        else:
            advantage = f"Options +{abs(comp['futures_advantage']):.2f}"
        
        print(f"{comp['exit_price']:<12.2f} {price_change:<15} {futures_pnl:<15} {options_pnl:<15} {advantage:<15}")
    
    print("=" * 100 + "\n")


def main():
    parser = argparse.ArgumentParser(
        description="Compare futures vs options risk/reward profiles"
    )
    parser.add_argument(
        "--position-size", "-s",
        type=float,
        default=10000,
        help="Position size in USD (default: 10000)"
    )
    parser.add_argument(
        "--entry-price", "-e",
        type=float,
        default=50000,
        help="Entry price (default: 50000)"
    )
    parser.add_argument(
        "--strike-price", "-k",
        type=float,
        default=52000,
        help="Option strike price (default: 52000)"
    )
    parser.add_argument(
        "--premium", "-p",
        type=float,
        default=2000,
        help="Option premium (default: 2000)"
    )
    parser.add_argument(
        "--output", "-o",
        type=str,
        default=None,
        help="Output JSON file path"
    )
    
    args = parser.parse_args()
    
    # Generate price range (from -20% to +20% of entry price)
    price_range = [
        args.entry_price * (1 + i/100) 
        for i in range(-20, 21, 2)
    ]
    
    # Generate comparisons
    comparisons = generate_comparison_table(
        args.position_size,
        args.entry_price,
        args.strike_price,
        args.premium,
        price_range
    )
    
    # Print summary
    print(f"\nFutures vs Options Comparison")
    print(f"Position Size: ${args.position_size:.2f}")
    print(f"Entry Price: ${args.entry_price:.2f}")
    print(f"Option Strike: ${args.strike_price:.2f}")
    print(f"Option Premium: ${args.premium:.2f}")
    print(f"\nKey Differences:")
    print(f"  - Futures: No upfront cost, unlimited risk/reward")
    print(f"  - Options: ${args.premium:.2f} upfront, max loss = premium")
    
    # Print table
    print_comparison_table(comparisons)
    
    # Output JSON if requested
    if args.output:
        with open(args.output, "w") as f:
            json.dump(comparisons, f, indent=2)
        print(f"Results saved to {args.output}")


if __name__ == "__main__":
    main()
