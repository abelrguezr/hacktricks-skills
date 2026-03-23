---
name: web3-signing-workflow-compromise
description: Analyze and detect Web3 signing workflow compromises, Safe{Wallet} delegatecall proxy takeover attacks, and EIP-712 signature manipulation. Use this skill whenever the user mentions Safe wallets, multisig security, delegatecall vulnerabilities, proxy storage slot attacks, signing UI compromises, EIP-712 signature issues, or any Web3 wallet security audit. Also trigger for cold-wallet security reviews, transaction signing validation, or when investigating potential wallet takeover incidents.
---

# Web3 Signing Workflow Compromise & Safe Delegatecall Proxy Takeover

A skill for analyzing and detecting sophisticated Web3 wallet compromise patterns involving signing workflow manipulation and on-chain delegatecall proxy takeovers.

## What This Skill Covers

This skill helps you understand and detect a specific attack chain that combines:
1. **Off-chain supply-chain compromise** of signing UI (e.g., Safe{Wallet} web interface)
2. **On-chain delegatecall primitive abuse** to overwrite proxy implementation pointers

The pattern was used in major incidents including the February 2025 Bybit cold-wallet drain (~401k ETH).

## Attack Pattern Overview

### The Two-Stage Attack

```
Stage 1 (Off-chain): Compromised signing UI
├── Tampered JS bundle injected into Safe{Wallet}
├── Context-gated: only triggers for specific Safe + signer addresses
├── Mutates transaction fields immediately before signing
├── Restores original UI data after signature is obtained
└── Victim signs attacker-chosen payload without knowing

Stage 2 (On-chain): Delegatecall proxy takeover
├── Safe proxy executes delegatecall (operation=1) to attacker contract
├── Attacker contract writes to storage slot 0 (masterCopy pointer)
├── Proxy implementation now points to attacker logic
└── Full wallet control achieved
```

### Key Technical Details

**Storage Slot Collision**: Safe proxies store `masterCopy` (implementation address) at **storage slot 0**. Because Safe supports `operation = 1` (delegatecall), any signed transaction can execute arbitrary code in the proxy's storage context.

**The Malicious Contract Pattern**:
```solidity
// Attacker contract mimics ERC-20 transfer but writes slot 0
uint256 stor0; // slot 0

function transfer(address _to, uint256 _value) external {
    stor0 = uint256(uint160(_to));  // Overwrites masterCopy!
}
```

**The Signing Mutation**:
```javascript
// Pseudocode of the malicious flow
orig = structuredClone(tx.data);
if (isVictimSafe && isVictimSigner && tx.data.operation === 0) {
  tx.data.to = attackerContract;
  tx.data.data = "0xa9059cbb...";      // ERC-20 transfer selector
  tx.data.operation = 1;                 // delegatecall
  tx.data.value = 0;
  tx.data.safeTxGas = 45746;
  const sig = await sdk.signTransaction(tx, safeVersion);
  sig.data = orig;                       // restore original before submission
  tx.data = orig;
  return sig;
}
```

## Detection Checklist

Use this checklist when auditing Safe wallets or investigating potential compromises:

### UI Integrity Checks
- [ ] **Pin JS assets**: Verify SRI (Subresource Integrity) hashes on all signing UI bundles
- [ ] **Monitor bundle diffs**: Alert on any changes to `_app-*.js` or similar critical files
- [ ] **Check Wayback Machine**: Compare current bundles against historical snapshots
- [ ] **Verify CDN integrity**: Ensure signing UI is served from expected, verified sources

### Transaction Analysis
- [ ] **Flag delegatecall operations**: Any `operation = 1` from treasury wallets should trigger review
- [ ] **Decode nested calldata**: Don't trust UI rendering; decode `tx.data` to see actual function calls
- [ ] **Verify safeTxHash**: Recompute hash and validate it matches the signed data
- [ ] **Check operation changes**: Alert if `operation` differs from typical patterns (most are `call`)

### Server-Side Validation
- [ ] **Hash verification**: Gateways must recompute `safeTxHash` and validate signatures match submitted fields
- [ ] **Signature-data consistency**: Reject proposals where signature corresponds to different fields than JSON body
- [ ] **Policy enforcement**: Implement preflight rules for `to`, selectors, and asset types

### Contract Design Review
- [ ] **Guard installation**: Safes >= v1.3.0 can install Guards to veto delegatecall or enforce ACLs
- [ ] **Slot collision risk**: Avoid placing upgrade pointers at slot 0 if delegatecall is possible
- [ ] **Delegatecall necessity**: Question whether arbitrary delegatecall is truly needed in multisig/treasury

## Hardening Recommendations

### Immediate Actions

1. **Upgrade Safe contracts** to v1.3.0+ to enable Guard functionality
2. **Install a Guard** that vetoes `delegatecall` operations or enforces strict ACLs
3. **Implement server-side hash verification** on any signing-orchestration API
4. **Pin and monitor** all signing UI assets with SRI hashes

### Policy Changes

1. **Disallow delegatecall** except for vetted, whitelisted flows
2. **Require internal policy service** approval before broadcasting fully signed transactions
3. **Implement clear-signing** on hardware wallets that explicitly renders `operation` and decodes nested calldata
4. **Set up monitoring** for delegatecall executions from wallets holding treasury funds

### Architectural Improvements

1. **Separate signing from execution**: Use a policy service that validates transactions before they're signed
2. **Multi-layer verification**: Require independent verification of transaction parameters at signing time
3. **Storage slot isolation**: Place upgrade pointers away from slot 0 or guard with explicit upgrade logic
4. **Bundle integrity**: Serve signing UI from immutable, versioned sources with cryptographic verification

## Real-World Incident: Bybit February 2025

### Timeline
- **February 21, 2025**: Bybit cold-wallet drained (~401k ETH)
- **Attack vector**: Compromised Safe S3 bundle (`_app-52c9031bfa03da47.js`)
- **Targeting**: Hard-coded allowlist for Bybit's Safe (`0x1db9…cf4`) and signer addresses
- **Cleanup**: Bundle rolled back to clean version 2 minutes after execution

### Attack Flow
1. Compromised bundle loaded in Safe{Wallet} web UI
2. Context-gated logic detected Bybit Safe + signer addresses
3. Transaction mutated: `operation=0` → `1`, `to` → attacker contract
4. Victim signed the mutated transaction (EIP-712 signature)
5. UI restored original data before submission
6. Safe Client Gateway accepted proposal (pre-hardening)
7. Transaction executed: delegatecall to attacker contract
8. Attacker contract wrote slot 0, overwriting `masterCopy`
9. Proxy implementation now attacker-controlled
10. Funds swept via `sweepETH/sweepERC20` functions

### Post-Incident Hardening
- Safe Client Gateway now rejects proposals where hash/signature don't match submitted transaction
- Similar server-side verification should be enforced on any signing-orchestration API

## When to Use This Skill

Trigger this skill when you need to:
- Audit Safe{Wallet} or similar multisig security
- Investigate potential wallet compromise incidents
- Review transaction signing workflows for vulnerabilities
- Analyze EIP-712 signature security
- Design hardening measures for treasury wallets
- Understand delegatecall proxy attack patterns
- Review storage slot collision risks in proxy contracts
- Investigate supply-chain compromises in Web3 signing UIs

## References

- [AnChain.AI forensic breakdown of the Bybit Safe exploit](https://www.anchain.ai/blog/bybit)
- [Zero Hour Technology analysis of the Safe bundle compromise](https://www.panewslab.com/en/articles/7r34t0qk9a15)
- [In-depth technical analysis of the Bybit hack (NCC Group)](https://www.nccgroup.com/research-blog/in-depth-technical-analysis-of-the-bybit-hack/)
- [EIP-712 Specification](https://eips.ethereum.org/EIPS/eip-712)
- [safe-client-gateway (GitHub)](https://github.com/safe-global/safe-client-gateway)

## Quick Reference: Attack Indicators

| Indicator | What to Look For | Risk Level |
|-----------|------------------|------------|
| `operation = 1` | Delegatecall from treasury wallet | 🔴 Critical |
| Slot 0 writes | Any contract writing to storage slot 0 in proxy context | 🔴 Critical |
| UI bundle changes | Unverified changes to signing UI JS files | 🟠 High |
| Hash mismatch | `safeTxHash` doesn't match signed data | 🔴 Critical |
| Context-gated logic | Hard-coded address allowlists in signing code | 🟠 High |
| ERC-20 selector abuse | `0xa9059cbb` (transfer) to non-ERC-20 contract | 🟡 Medium |
