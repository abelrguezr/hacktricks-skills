---
name: web3-red-teaming-aadapt
description: How to conduct value-centric Web3 red teaming using the MITRE AADAPT framework. Use this skill whenever the user mentions Web3 security, blockchain red teaming, smart contract testing, DeFi security, oracle manipulation, flash loan attacks, cross-chain security, or wants to test crypto infrastructure against economic attacks. This skill helps inventory value-bearing components, map them to AADAPT techniques, design attack scenarios, and set up detection telemetry.
---

# Value-Centric Web3 Red Teaming (MITRE AADAPT)

This skill guides you through conducting red team exercises that test whether Web3 infrastructure can resist irreversible economic loss. The MITRE AADAPT (Adversarial Actions in Digital Asset Payment Techniques) framework focuses on attacker behaviors that manipulate digital value rather than just infrastructure.

## When to Use This Skill

Use this skill when:
- Planning or executing Web3/blockchain security assessments
- Testing DeFi protocols, bridges, oracles, or smart contracts
- Designing red team scenarios for crypto infrastructure
- Setting up detection and monitoring for blockchain systems
- Evaluating governance, signing, or upgrade mechanisms
- The user mentions any of: flash loans, oracle manipulation, cross-chain attacks, smart contract security, DeFi red teaming, blockchain penetration testing

## Core Methodology

### Phase 1: Inventory Value-Bearing Components

Build a complete map of everything that can influence value state, on-chain and off-chain.

**What to inventory:**

1. **Custodial signing services**
   - HSM/KMS clusters, Vault/KMaaS, signing APIs
   - Key IDs, policies, automation identities
   - Approval workflows and authorization chains

2. **Admin & upgrade paths**
   - Proxy admins, governance timelocks
   - Emergency pause keys, parameter registries
   - Who/what can call them, quorum requirements, delays

3. **On-chain protocol logic**
   - Lending, AMMs, vaults, staking, bridges, settlement rails
   - Document invariants: oracle prices, collateral ratios, rebalance cadence

4. **Off-chain automation**
   - Market-making bots, CI/CD pipelines, cron jobs, serverless functions
   - API keys, service principals that request signatures

5. **Oracles & data feeds**
   - Aggregator composition, quorum, deviation thresholds, update cadence
   - Every upstream relied on by automated risk logic

6. **Bridges and cross-chain routers**
   - Lock/mint contracts, relayers, settlement jobs
   - Chains or custodial stacks being tied together

**Deliverable:** A value-flow diagram showing how assets move, who authorizes movement, and which external signals influence business logic.

### Phase 2: Map Components to AADAPT Behaviors

Translate the AADAPT taxonomy into concrete attack candidates per component:

| Component | Primary AADAPT Focus |
|-----------|---------------------|
| Signing/KMS estates | Credential theft, policy bypass, signing-abuse, governance takeover |
| Oracles/feeds | Input poisoning, aggregation manipulation, deviation-threshold evasion |
| On-chain protocols | Flash-loan economic manipulation, invariant breaking, parameter reconfiguration |
| Automation pipelines | Compromised bot/CI identities, batch replay, unauthorized deployment |
| Bridges/routers | Cross-chain evasion, rapid hop laundering, settlement desynchronization |

### Phase 3: Prioritize by Feasibility vs Impact

**Operational weaknesses** (start here - could succeed today):
- Exposed CI credentials
- Over-privileged IAM roles
- Misconfigured KMS policies
- Automation accounts that can request arbitrary signatures
- Public buckets with bridge configs

**Value-specific weaknesses** (deeper protocol attacks):
- Fragile oracle parameters
- Upgradable contracts without multi-party approvals
- Flash-loan sensitive liquidity
- Governance actions that bypass timelocks

Work the queue like an adversary: start with operational footholds, then progress into deep protocol/economic manipulation paths.

### Phase 4: Execute in Controlled Environments

**Environment setup:**
- Forked mainnets or isolated testnets
- Replicate bytecode, storage, and liquidity
- Enable flash-loan paths, oracle drifts, and bridge flows end-to-end
- Never touch real funds

**Blast-radius planning:**
- Define circuit breakers and pausable modules
- Prepare rollback runbooks
- Use test-only admin keys

**Coordination:**
- Notify custodians, oracle operators, bridge partners, compliance
- Ensure monitoring teams expect the traffic
- Document scope, authorization, and stop conditions

### Phase 5: Instrument Telemetry

Align telemetry streams so every scenario produces actionable detection data:

**Chain-level traces:**
- Full call graphs, gas usage, transaction nonces, block timestamps
- Reconstruct flash-loan bundles, reentrancy-like structures, cross-contract hops

**Application/API logs:**
- Tie each on-chain tx to human or automation identity
- Session ID, OAuth client, API key, CI job ID, IPs, auth methods

**KMS/HSM logs:**
- Key ID, caller principal, policy result, destination address, reason codes
- Baseline change windows and high-risk operations

**Oracle/feed metadata:**
- Per-update data source composition, reported value
- Deviation from rolling averages, thresholds triggered, failover paths

**Bridge/swap traces:**
- Correlate lock/mint/unlock events across chains
- Correlation IDs, chain IDs, relayer identity, hop timing

**Anomaly markers:**
- Slippage spikes, abnormal collateralization ratios
- Unusual gas density, cross-chain velocity

Tag everything with scenario IDs or synthetic user IDs.

### Phase 6: Purple-Team Loop

1. Run the scenario in the controlled environment
2. Capture detections (alerts, dashboards, responders paged)
3. Map each step to specific AADAPT techniques plus observables
4. Formulate and deploy detection hypotheses
5. Re-run until MTTD and MTTC meet business tolerances

**Track maturity on three axes:**
- **Visibility:** Every critical value path has telemetry in each plane
- **Coverage:** Proportion of prioritized AADAPT techniques exercised end-to-end
- **Response:** Ability to pause contracts, revoke keys, or freeze flows before irreversible loss

## Scenario Templates

Use these repeatable blueprints to design simulations:

### Scenario A: Flash-Loan Economic Manipulation

**Objective:** Borrow transient capital inside one transaction to distort AMM prices/liquidity and trigger mispriced borrows, liquidations, or mints before repaying.

**Execution:**
1. Fork the target chain and seed pools with production-like liquidity
2. Borrow large notional via flash loan
3. Perform calibrated swaps to cross price/threshold boundaries relied on by lending, vault, or derivative logic
4. Invoke the victim contract immediately after the distortion (borrow, liquidate, mint) and repay the flash loan

**Measurement:**
- Did the invariant violation succeed?
- Were slippage/price-deviation monitors, circuit breakers, or governance pause hooks triggered?
- How long until analytics flagged the abnormal gas/call graph pattern?

### Scenario B: Oracle/Data-Feed Poisoning

**Objective:** Determine whether manipulated feeds can trigger destructive automated actions (mass liquidations, incorrect settlements).

**Execution:**
1. In the fork/testnet, deploy a malicious feed or adjust aggregator weights/quorum/update cadence beyond tolerated deviation
2. Let dependent contracts consume the poisoned values and execute their standard logic

**Measurement:**
- Feed-level out-of-band alerts
- Fallback oracle activation
- Min/max bound enforcement
- Latency between anomaly onset and operator response

### Scenario C: Credential/Signing Abuse

**Objective:** Test whether compromising a single signer or automation identity enables unauthorized upgrades, parameter changes, or treasury drains.

**Execution:**
1. Enumerate identities with sensitive signing rights (operators, CI tokens, service accounts invoking KMS/HSM, multisig participants)
2. Simulate compromise (re-use their credentials/keys within the lab scope)
3. Attempt privileged actions: upgrade proxies, change risk parameters, mint/pause assets, or trigger governance proposals

**Measurement:**
- Do KMS/HSM logs raise anomaly alerts (time-of-day, destination drift, burst of high-risk operations)?
- Can policies or multisig thresholds prevent unilateral abuse?
- Are throttles/rate limits or additional approvals enforced?

### Scenario D: Cross-Chain Evasion & Traceability Gaps

**Objective:** Evaluate how well defenders can trace and interdict assets rapidly laundered across bridges, DEX routers, and privacy hops.

**Execution:**
1. Chain together lock/mint operations across common bridges
2. Interleave swaps/mixers on each hop, maintain per-hop correlation IDs
3. Accelerate transfers to stress monitoring latency (multi-hop within minutes/blocks)

**Measurement:**
- Time to correlate events across telemetry + commercial chain analytics
- Completeness of the reconstructed path
- Ability to identify choke points for freezing in a real incident
- Alert fidelity for abnormal cross-chain velocity/value

## Quick Start Checklist

When starting a Web3 red team engagement:

1. [ ] Complete value inventory (all 6 component categories)
2. [ ] Map components to AADAPT techniques
3. [ ] Prioritize by operational feasibility first
4. [ ] Set up forked testnet with production-like state
5. [ ] Define blast-radius controls and circuit breakers
6. [ ] Coordinate with stakeholders and get legal sign-off
7. [ ] Instrument telemetry for all value planes
8. [ ] Select and execute scenario templates
9. [ ] Run purple-team loop until MTTD/MTTC targets met
10. [ ] Document findings and detection improvements

## References

- [MITRE AADAPT Framework as a Red Team Roadmap (Bishop Fox)](https://bishopfox.com/blog/mitre-aadapt-framework-as-a-red-team-roadmap)
- MITRE AADAPT Matrix: https://attack.mitre.org/adapt/
