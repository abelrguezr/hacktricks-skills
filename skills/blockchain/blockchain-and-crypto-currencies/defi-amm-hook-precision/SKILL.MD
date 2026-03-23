---
name: defi-amm-hook-precision-audit
description: Audit Uniswap v4 hooks for precision/rounding vulnerabilities and threshold-crossing exploits. Use this skill whenever the user mentions DeFi AMM security, Uniswap v4 hooks, custom accounting, precision drift, rounding abuse, or wants to analyze/audit DEX hook implementations. Also trigger for Bunni V2-style exploits, LDF vulnerabilities, or when reviewing beforeSwap/afterSwap callbacks with custom math.
---

# DeFi AMM Hook Precision Audit

A skill for identifying and analyzing precision/rounding vulnerabilities in Uniswap v4–style DEX hooks, including threshold-crossing exploits and custom accounting drift.

## When to use this skill

Use this skill when:
- Auditing Uniswap v4 hook implementations for security vulnerabilities
- Investigating precision/rounding issues in DeFi AMM custom accounting
- Analyzing threshold-crossing exploit patterns (like Bunni V2)
- Reviewing beforeSwap/afterSwap callbacks with custom math
- Testing hook implementations for invariant violations
- Generating test harnesses for hook security validation
- Understanding how fixed-point math errors compound in hooks

## Core vulnerability pattern

Hooks that implement custom accounting with fixed-point math can accumulate rounding errors that benefit the swap initiator. The attack pattern:

1. **Identify** pools with custom hooks performing per-swap math
2. **Model** the hook's liquidity/redistribution formulas and thresholds
3. **Calibrate** exact-input swaps to cross boundaries where rounding favors the caller
4. **Amplify** with flash loans to execute many iterations atomically
5. **Withdraw** accumulated credits before settlement

## Audit methodology

### Step 1: Enumerate hook-enabled pools

```bash
# Check if pool uses hooks
PoolKey memory key = pm.getPoolKey(currency0, currency1, fee, tickSpacing);
require(key.hooks != address(0), "No hook");

# Inspect enabled callbacks
uint256 callbacks = IHook(key.hooks).hooks();
// Check: beforeSwap, afterSwap, beforeAddLiquidity, etc.
```

**What to look for:**
- Non-zero `hooks` address in PoolKey
- Callbacks enabled for swap operations (beforeSwap/afterSwap)
- Custom rebalancing or redistribution methods

### Step 2: Analyze hook math patterns

Run the hook analyzer script to identify risky patterns:

```bash
python scripts/analyze_hook_math.py --hook-address <address> --abi <path>
```

**Risky patterns to flag:**
- `mulDiv` (floors) mixed with `mulDivUp` (ceils)
- Conversions between `uint256`/`int256` with `SafeCast`
- Q64.96 `sqrtPriceX96` conversions without inverse verification
- Per-swap `BalanceDelta` tracking that credits `msg.sender`
- Threshold logic on tick boundaries or bucket crossings

### Step 3: Model threshold boundaries

Recreate the hook's formula to find where rounding direction changes:

```solidity
// Example: find tick boundary where rounding flips
function findRoundingBoundary() internal view returns (int24) {
    int24 currentTick = pool.slot0().tick;
    int24 tickSpacing = pool.tickSpacing();
    
    // Test ±1 wei around each boundary
    for (int24 t = currentTick - tickSpacing; t <= currentTick + tickSpacing; t++) {
        if (t % tickSpacing != 0) continue;
        
        uint256 delta = computeDelta(t, t + tickSpacing);
        if (delta % 1000000 != 0) {
            // Rounding residue detected
            emit BoundaryFound(t, delta);
        }
    }
}
```

### Step 4: Generate test harness

Create a Foundry test to verify the vulnerability:

```bash
python scripts/generate_test_harness.py \
  --pool-address <address> \
  --hook-address <address> \
  --output test/PrecisionDrift.t.sol
```

This generates a test template with:
- Pool initialization with the target hook
- Boundary-crossing swap calibration
- Loop to accumulate rounding credits
- Withdrawal path to realize profit

### Step 5: Simulate drift scenarios

Run simulations to quantify potential exploit impact:

```bash
python scripts/simulate_rounding_drift.py \
  --iterations 1000 \
  --swap-size 1000000000000000000 \
  --output drift_analysis.json
```

## Common vulnerability signatures

| Pattern | Risk | Detection |
|---------|------|----------|
| `mulDiv` without `mulDivUp` | High | Search for division in delta calculations |
| Tick alignment mismatch | High | Compare tick rounding in before/after paths |
| BalanceDelta credits caller | Critical | Trace delta settlement to msg.sender |
| Q64.96 precision loss | Medium | Check sqrtPrice conversions |
| Threshold on exact boundaries | High | Look for `if (tick == boundary)` patterns |

## Defensive recommendations

### For auditors

1. **Differential testing**: Compare hook math against high-precision reference
2. **Boundary fuzzing**: Test ±1 wei around all thresholds
3. **Invariant checks**: Sum of deltas must conserve value modulo fees
4. **Rounding policy audit**: Ensure all rounding works against the user

### For developers

```solidity
// ✅ Good: round against user
uint256 newBalance = balance - balance.mulDivUp(shares, totalSupply);

// ❌ Bad: round toward user
uint256 newBalance = balance - balance.mulDiv(shares, totalSupply);

// ✅ Good: burn residue
uint256 residue = total - distributed;
if (residue > 0) {
    address(this).transfer(residue); // burn or treasury
}

// ❌ Bad: credit residue to caller
userCredits[msg.sender] += residue;
```

## Case study: Bunni V2 pattern

The Bunni V2 exploit (Sep 2025) demonstrated this vulnerability:

1. **Price push**: Flash loan 3M USDT, push tick to ~5000, shrink active USDC to ~28 wei
2. **Rounding drain**: 44 micro-withdrawals exploited floor rounding, reduced balance to 4 wei (-85.7%)
3. **Liquidity rebound**: Large swap moved tick to ~839,189, liquidity estimate increased 16.8%
4. **Exit**: Sandwich attack at inflated price, profit realized

**Root cause**: `mulDiv` (floor) in idle balance update allowed cumulative underestimation.

**Fix**: Use `mulDivUp` to round up, preventing downward ratcheting.

## Quick audit checklist

- [ ] Pool uses non-zero hooks address?
- [ ] beforeSwap/afterSwap callbacks enabled?
- [ ] Custom math in per-swap accounting?
- [ ] Consistent rounding across all paths?
- [ ] BalanceDelta settlement neutral (no caller credit)?
- [ ] Threshold logic tested at ±1 wei boundaries?
- [ ] Q64.96 conversions verified bidirectionally?
- [ ] Rounding residue burned or sent to treasury?

## References

- [Bunni V2 Exploit Post-Mortem](https://blog.bunni.xyz/posts/exploit-post-mortem/)
- [Uniswap v4 Core Whitepaper](https://app.uniswap.org/whitepaper-v4.pdf)
- [QuillAudits: Uniswap v4 Hooks Security](https://www.quillaudits.com/research/uniswap-development/uniswap-v4/uniswap-v4-hooks-and-security)
- [Uniswap v4 Liquidity Mechanics](https://www.quillaudits.com/research/uniswap-development/uniswap-v4/liquidity-mechanics-in-uniswap-v4-core)

## Scripts

- `scripts/analyze_hook_math.py` - Analyze hook bytecode/ABI for risky patterns
- `scripts/generate_test_harness.py` - Generate Foundry test templates
- `scripts/simulate_rounding_drift.py` - Simulate precision drift scenarios

Run `python scripts/<script>.py --help` for usage details.
