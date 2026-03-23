---
name: mutation-testing-solidity
description: Run mutation testing on Solidity smart contracts using slither-mutate to find bugs your tests don't catch. Use this skill whenever you need to validate test suite quality, audit smart contract tests, or improve test coverage beyond line/branch metrics. Trigger when users mention mutation testing, slither-mutate, test quality, smart contract testing, or want to verify their tests actually assert correct behavior.
---

# Mutation Testing for Solidity with Slither

Mutation testing "tests your tests" by systematically introducing small changes (mutants) into your Solidity code and re-running your test suite. If a test fails, the mutant is killed. If tests still pass, the mutant survives, revealing a blind spot that line/branch coverage cannot detect.

**Key insight**: Coverage shows code was executed; mutation testing shows whether behavior is actually asserted.

## When to use this skill

- You want to validate your test suite actually catches bugs
- You're auditing smart contracts and need to verify test quality
- Your tests have 100% coverage but you suspect gaps
- You're preparing for a security audit and want to strengthen tests
- Surviving mutants from a previous run need triage

## Why coverage can deceive

Consider this threshold check:

```solidity
function verifyMinimumDeposit(uint256 deposit) public returns (bool) {
    if (deposit >= 1 ether) {
        return true;
    } else {
        return false;
    }
}
```

Tests checking values below and above the threshold can reach 100% line/branch coverage while failing to assert the equality boundary (`==`). A refactor to `deposit >= 2 ether` would still pass such tests, silently breaking protocol logic.

Mutation testing exposes this gap by mutating the condition and verifying your tests fail.

## Common Solidity mutation operators

Slither's mutation engine applies semantics-changing edits:

| Operator | Examples |
|----------|----------|
| Operator replacement | `+` ↔ `-`, `*` ↔ `/`, `==` ↔ `!=` |
| Assignment replacement | `+=` → `=`, `-=` → `=` |
| Constant replacement | non-zero → `0`, `true` ↔ `false` |
| Condition negation | `if (x)` → `if (!x)` |
| Comment replacement (CR) | Line → `// Line` |
| Revert replacement | Line → `revert()` |
| Data type swaps | `int128` → `int64` |

**Goal**: Kill 100% of generated mutants, or justify survivors with clear reasoning.

## Running mutation testing

### Prerequisites

- Slither v0.10.2+
- Working test suite (Foundry, Hardhat, or similar)

### Quick start

```bash
# List available mutators
slither-mutate --list-mutators

# Run mutation testing (Foundry example)
slither-mutate ./src/contracts --test-cmd="forge test" &> >(tee mutation.results)

# For Hardhat
slither-mutate ./contracts --test-cmd="npx hardhat test"
```

Artifacts and reports are stored in `./mutation_campaign` by default. Uncaught (surviving) mutants are copied there for inspection.

### Understanding the output

```text
INFO:Slither-Mutate:Mutating contract ContractName
INFO:Slither-Mutate:[CR] Line 123: 'original line' ==> '//original line' --> UNCAUGHT
```

- **Tag in brackets**: Mutator alias (e.g., `CR` = Comment Replacement)
- **UNCAUGHT**: Tests passed under mutated behavior → missing assertion
- **KILLED**: Tests correctly detected the mutation

## Reducing runtime

Mutation campaigns can take hours or days. Tips to reduce cost:

1. **Scope**: Start with critical contracts/directories only, then expand
2. **Prioritize mutators**: If a high-priority mutant survives (e.g., entire line commented), skip lower-priority variants for that line
3. **Parallelize**: Use test runner parallelization; cache dependencies/builds
4. **Fail-fast**: Stop early when a change clearly demonstrates an assertion gap

## Triage workflow for surviving mutants

### Step 1: Inspect the mutated line and behavior

Reproduce locally by applying the mutated line and running a focused test:

```bash
# Check the mutation_campaign directory for surviving mutants
cat mutation_campaign/<contract>/<line>.mutated
```

### Step 2: Strengthen tests to assert state, not only return values

- Add equality-boundary checks (e.g., test threshold `==`)
- Assert post-conditions: balances, total supply, authorization effects, emitted events
- Check that state actually changed, not just that functions returned expected values

### Step 3: Replace overly permissive mocks with realistic behavior

- Ensure mocks enforce transfers, failure paths, and event emissions that occur on-chain
- Mocks should fail when they should fail (e.g., insufficient balance, unauthorized access)

### Step 4: Add invariants for fuzz tests

```solidity
// Example invariants to add
function invariant_balancesNeverNegative() public {
    require(address(token).balanceOf(owner) >= 0);
}

function invariant_totalSupplyConserved() public {
    require(totalSupply() == sumOfAllBalances());
}

function invariant_onlyAuthorizedCanWithdraw() public {
    require(hasRole(WITHDRAWER_ROLE, msg.sender) || isOwner(msg.sender));
}
```

### Step 5: Re-run slither-mutate

Iterate until all mutants are killed or explicitly justified with comments and rationale.

## High-risk survivors to prioritize

Treat these as high-risk until killed:

- **Value transfers**: Any mutation affecting token transfers, balances, or accounting
- **Access control**: Mutations to authorization checks, role assignments
- **Critical invariants**: Supply conservation, non-negative balances, monotonic counters
- **External calls**: Mutations to calls to external contracts

## Case study: Arkis protocol

A mutation campaign during an audit of the Arkis DeFi protocol surfaced survivors like:

```text
INFO:Slither-Mutate:[CR] Line 33: 'cmdsToExecute.last().value = _cmd.value' ==> '//cmdsToExecute.last().value = _cmd.value' --> UNCAUGHT
```

Commenting out the assignment didn't break the tests, proving missing post-state assertions. Root cause: code trusted a user-controlled `_cmd.value` instead of validating actual token transfers. An attacker could desynchronize expected vs. actual transfers to drain funds.

**Result**: High severity risk to protocol solvency.

## Practical checklist

- [ ] Run a targeted campaign: `slither-mutate ./src/contracts --test-cmd="forge test"`
- [ ] Triage survivors and write tests/invariants that would fail under mutated behavior
- [ ] Assert balances, supply, authorizations, and events
- [ ] Add boundary tests (`==`, overflows/underflows, zero-address, zero-amount, empty arrays)
- [ ] Replace unrealistic mocks; simulate failure modes
- [ ] Iterate until all mutants are killed or justified with comments and rationale

## References

- [Use mutation testing to find the bugs your tests don't catch (Trail of Bits)](https://blog.trailofbits.com/2025/09/18/use-mutation-testing-to-find-the-bugs-your-tests-dont-catch/)
- [Arkis DeFi Prime Brokerage Security Review (Appendix C)](https://github.com/trailofbits/publications/blob/master/reviews/2024-12-arkis-defi-prime-brokerage-securityreview.pdf)
- [Slither (GitHub)](https://github.com/crytic/slither)
