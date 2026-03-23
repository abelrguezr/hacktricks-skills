#!/usr/bin/env python3
"""
Generate Foundry test harness for Uniswap v4 hook precision vulnerability testing.

Usage:
    python scripts/generate_test_harness.py \
        --pool-address <address> \
        --hook-address <address> \
        --output test/PrecisionDrift.t.sol
"""

import argparse
from pathlib import Path
from datetime import datetime


def generate_test_harness(
    pool_address: str,
    hook_address: str,
    currency0: str = "USDC",
    currency1: str = "USDT",
    fee: int = 500,
    tick_spacing: int = 10,
    output_path: Path = None
) -> str:
    """Generate a Foundry test harness for precision drift testing."""
    
    test_template = f'''// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@uniswap/v4-core/contracts/interfaces/IPoolManager.sol";
import "@uniswap/v4-core/contracts/interfaces/IMintHook.sol";
import "@uniswap/v4-core/contracts/interfaces/ISwapHook.sol";

/// @title Precision Drift Test Harness
/// @notice Generated test for Uniswap v4 hook precision/rounding vulnerability
/// @dev Generated: {datetime.now().isoformat()}
contract PrecisionDriftTest is Test {
    IPoolManager public pm;
    address public constant HOOK = {hook_address};
    address public constant POOL = {pool_address};
    
    // Token addresses (update as needed)
    address public constant {currency0.upper()} = 0x{currency0.lower()};
    address public constant {currency1.upper()} = 0x{currency1.lower()};
    
    // Test configuration
    uint256 public constant SWAP_ITERATIONS = 100;
    uint256 public constant INITIAL_BALANCE = 10_000_000_000_000_000_000; // 10 tokens
    
    /// @notice Set up the test environment
    function setUp() public {
        // Deploy or use existing PoolManager
        // pm = new PoolManager(); // Uncomment if deploying fresh
        
        // Fund test account
        vm.deal(address(this), 1000 ether);
    }
    
    /// @notice Test precision drift via threshold-crossing swaps
    function test_precision_drift_threshold_crossing() public {
        // 1. Get current pool state
        PoolKey memory key = pm.getPoolKey(
            address({currency0.upper()}),
            address({currency1.upper()}),
            {fee},
            {tick_spacing}
        );
        
        // Verify hook is set
        assertEq(key.hooks, HOOK, "Hook not configured");
        
        // 2. Record initial balances
        uint256 initialBalance0 = {currency0.upper()}.balanceOf(address(this));
        uint256 initialBalance1 = {currency1.upper()}.balanceOf(address(this));
        
        // 3. Calibrate swap size to cross threshold
        uint256 calibratedAmount = calibrateToCrossThreshold(key);
        
        // 4. Execute swap loop to accumulate rounding credit
        for (uint256 i = 0; i < SWAP_ITERATIONS; i++) {
            // Exact input swap
            (, int256 amount0, int256 amount1, ) = pm.swap(
                key,
                IPoolManager.SwapParams({
                    zeroForOne: true,
                    amountSpecified: int256(calibratedAmount),
                    sqrtPriceLimitX96: 0 // Allow tick crossing
                }),
                ""
            );
            
            // Log delta for analysis
            emit SwapDelta(i, amount0, amount1);
        }
        
        // 5. Check final balances
        uint256 finalBalance0 = {currency0.upper()}.balanceOf(address(this));
        uint256 finalBalance1 = {currency1.upper()}.balanceOf(address(this));
        
        // 6. Verify if rounding credit was accumulated
        // This assertion should FAIL if vulnerability exists
        int256 netDelta0 = int256(finalBalance0) - int256(initialBalance0);
        int256 netDelta1 = int256(finalBalance1) - int256(initialBalance1);
        
        // If netDelta is positive without corresponding input, vulnerability exists
        emit Result("Net delta 0", netDelta0);
        emit Result("Net delta 1", netDelta1);
        
        // Note: Remove this assertion for actual exploit testing
        // assertTrue(netDelta0 <= 0 || netDelta1 <= 0, "Unexpected positive delta");
    }
    
    /// @notice Test with flash loan amplification
    function test_precision_drift_with_flash_loan() public {
        // Borrow large amount
        uint256 loanAmount = 1_000_000_000_000_000_000_000; // 1M tokens
        
        // Simulate flash loan (implement actual flash loan logic)
        // IERC20({currency0.upper()}).transferFrom(lender, address(this), loanAmount);
        
        // Execute many iterations
        uint256 iterations = 1000;
        uint256 calibratedAmount = calibrateToCrossThreshold(
            pm.getPoolKey(
                address({currency0.upper()}),
                address({currency1.upper()}),
                {fee},
                {tick_spacing}
            )
        );
        
        for (uint256 i = 0; i < iterations; i++) {
            // Swap logic here
        }
        
        // Repay flash loan
        // IERC20({currency0.upper()}).transfer(lender, loanAmount + premium);
    }
    
    /// @notice Calibrate swap size to cross tick boundary
    function calibrateToCrossThreshold(PoolKey memory key) 
        public 
        view 
        returns (uint256)
    {
        // Get current tick
        Slot0 memory slot0 = pm.slot0(key);
        int24 currentTick = slot0.tick;
        
        // Calculate amount to move to next tick
        // This is simplified; implement full v3/v4 math for accuracy
        uint256 tickSpacing = key.tickSpacing;
        int24 targetTick = currentTick + tickSpacing;
        
        // Approximate amount needed (implement precise calculation)
        // Δx ≈ L × (ΔsqrtP / (sqrtP_next × sqrtP_current))
        return 1_000_000_000_000_000_000; // 1 token (adjust based on pool)
    }
    
    /// @notice Test boundary conditions at ±1 wei
    function test_boundary_conditions() public {
        PoolKey memory key = pm.getPoolKey(
            address({currency0.upper()}),
            address({currency1.upper()}),
            {fee},
            {tick_spacing}
        );
        
        // Test at boundary - 1 wei
        testAtBoundary(key, -1);
        
        // Test at boundary + 1 wei  
        testAtBoundary(key, 1);
        
        // Test exactly at boundary
        testAtBoundary(key, 0);
    }
    
    function testAtBoundary(PoolKey memory key, int256 offset) internal {
        // Implement boundary testing logic
        // Compare rounding behavior at offset positions
    }
    
    // Events for debugging
    event SwapDelta(uint256 iteration, int256 amount0, int256 amount1);
    event Result(string metric, int256 value);
}
'''
    
    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(test_template)
        print(f"Test harness generated: {output_path}")
    
    return test_template


def main():
    parser = argparse.ArgumentParser(
        description="Generate Foundry test harness for hook precision testing"
    )
    parser.add_argument(
        "--pool-address", "-p",
        required=True,
        help="Pool address (or PoolManager address)"
    )
    parser.add_argument(
        "--hook-address", "-h",
        required=True,
        help="Hook contract address"
    )
    parser.add_argument(
        "--currency0", "-c0",
        default="USDC",
        help="First token symbol (default: USDC)"
    )
    parser.add_argument(
        "--currency1", "-c1",
        default="USDT",
        help="Second token symbol (default: USDT)"
    )
    parser.add_argument(
        "--fee",
        type=int,
        default=500,
        help="Fee tier (default: 500 = 0.05%%)"
    )
    parser.add_argument(
        "--tick-spacing",
        type=int,
        default=10,
        help="Tick spacing (default: 10)"
    )
    parser.add_argument(
        "--output", "-o",
        type=Path,
        default=Path("test/PrecisionDrift.t.sol"),
        help="Output path for test file"
    )
    
    args = parser.parse_args()
    
    generate_test_harness(
        pool_address=args.pool_address,
        hook_address=args.hook_address,
        currency0=args.currency0,
        currency1=args.currency1,
        fee=args.fee,
        tick_spacing=args.tick_spacing,
        output_path=args.output
    )


if __name__ == "__main__":
    main()
