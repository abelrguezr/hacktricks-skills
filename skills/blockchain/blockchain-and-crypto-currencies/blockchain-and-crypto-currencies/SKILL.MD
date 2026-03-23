---
name: blockchain-security-analyst
description: Expert guidance on blockchain and cryptocurrency security, privacy mechanisms, and Web3 threat analysis. Use this skill whenever the user asks about blockchain concepts, Bitcoin/Ethereum transactions, privacy attacks, DeFi security, smart contract vulnerabilities, or Web3 red teaming. Trigger for any questions about cryptocurrency privacy, transaction analysis, consensus mechanisms, or blockchain security best practices—even if the user doesn't explicitly mention "security" or "blockchain."
---

# Blockchain Security Analyst

A comprehensive skill for understanding, analyzing, and securing blockchain and cryptocurrency systems.

## When to Use This Skill

Use this skill when the user needs help with:
- Understanding blockchain concepts (smart contracts, dApps, tokens, DeFi, DEX, DAOs)
- Analyzing Bitcoin or Ethereum transactions
- Understanding privacy mechanisms and attacks on cryptocurrencies
- Web3 security assessments and red teaming
- Smart contract security analysis
- Cryptocurrency best practices for privacy and security
- Explaining consensus mechanisms (PoW, PoS)
- DeFi/AMM exploitation research

## Core Concepts

### Smart Contracts & dApps

**Smart Contracts** are programs that execute on a blockchain when certain conditions are met, automating agreement executions without intermediaries.

**Decentralized Applications (dApps)** build upon smart contracts, featuring:
- User-friendly front-end
- Transparent, auditable back-end
- No central authority control

### Tokens & Coins

| Type | Purpose |
|------|--------|
| **Coins** | Digital money native to a blockchain |
| **Tokens** | Represent value or ownership in specific contexts |
| **Utility Tokens** | Grant access to services |
| **Security Tokens** | Signify asset ownership |

### DeFi Ecosystem

- **DeFi** (Decentralized Finance): Financial services without central authorities
- **DEX** (Decentralized Exchange): Peer-to-peer trading platforms
- **DAOs** (Decentralized Autonomous Organizations): Community-governed entities

## Consensus Mechanisms

### Proof of Work (PoW)
- Relies on computational power for transaction verification
- Energy-intensive but battle-tested
- Example: Bitcoin

### Proof of Stake (PoS)
- Validators must hold a certain amount of tokens
- Reduces energy consumption compared to PoW
- Example: Ethereum (post-Merge)

## Bitcoin Transaction Analysis

### Transaction Structure

Bitcoin transactions consist of:
- **Inputs**: Source of funds (references previous UTXOs)
- **Outputs**: Destination addresses and amounts
- **Fees**: Paid to miners for validation
- **Scripts**: Transaction rules and conditions

### Key Components

**Multisignature Transactions**: Require multiple signatures to authorize a transaction, enhancing security.

**Lightning Network**: Enhances Bitcoin's scalability by allowing multiple transactions within a channel, only broadcasting the final state to the blockchain.

### Transaction Validation

Transactions are validated through digital signatures, ensuring only the owner of the private key can initiate transfers.

## Bitcoin Privacy Attacks

### Common Input Ownership Assumption

**Attack**: Two input addresses in the same transaction are often assumed to belong to the same owner.

**Why it works**: It's rare for inputs from different users to be combined in a single transaction due to complexity.

**Mitigation**: Use CoinJoin or PayJoin to mix transactions.

### UTXO Change Address Detection

**Attack**: When a UTXO is partially spent, the remainder goes to a change address. Observers can assume this new address belongs to the sender.

**Example**:
```
Input: 5 BTC
Output 1 (payment): 3 BTC
Output 2 (change): 2 BTC → Likely sender's address
```

**Mitigation**: 
- Use mixing services
- Generate multiple change outputs
- Avoid change outputs when possible

### Unnecessary Input Heuristic (Optimal Change Heuristic)

**Attack**: Analyze transactions with multiple inputs/outputs to guess which output is change.

**Example**:
```
2 BTC → 4 BTC (output 1)
3 BTC → 1 BTC (output 2)
```

If adding more inputs makes the change output larger than any single input, it can confuse the heuristic.

### Forced Address Reuse

**Attack**: Send small amounts to previously used addresses, hoping the recipient combines these with other inputs in future transactions, linking addresses together.

**Correct Wallet Behavior**: Avoid using coins received on already used, empty addresses.

### Other Analysis Techniques

| Technique | Description |
|-----------|-------------|
| **Exact Payment Amounts** | Transactions without change are likely between addresses owned by the same user |
| **Round Numbers** | Round numbers suggest payments; non-round outputs are likely change |
| **Wallet Fingerprinting** | Different wallets have unique transaction patterns |
| **Amount & Timing Correlations** | Disclosing transaction times/amounts makes transactions traceable |
| **Traffic Analysis** | Monitor network traffic to link transactions to IP addresses |

### Social Network Exposure

Users sometimes share Bitcoin addresses online, making it easy to link addresses to owners.

## Privacy Defense Strategies

### Mixing Services

Send bitcoins and receive different bitcoins in return, making tracing difficult.

**Caveat**: Requires trust in the service not to keep logs and actually return the bitcoins.

### CoinJoin

Merges multiple transactions from different users into one, complicating input-output matching.

**Limitation**: Transactions with unique input/output sizes can still be traced.

### PayJoin (P2EP)

A variant of CoinJoin that disguises the transaction as a regular transaction between two parties.

**Advantage**: Invalidates the common-input-ownership heuristic used by surveillance entities.

**Example**:
```
Customer: 2 BTC → Merchant: 3 BTC
Merchant: 5 BTC → Customer: 4 BTC
```

### Wallet Synchronization Techniques

| Method | Privacy Level | Description |
|--------|--------------|-------------|
| **Full Node** | Maximum | Download entire blockchain; impossible for adversaries to identify which transactions you're interested in |
| **Client-side Block Filtering** | High | Create filters for every block; lightweight wallets download filters, only fetching full blocks when matches are found |

### Best Practices

1. **Use Tor**: Mask your IP address when interacting with the Bitcoin network
2. **Prevent Address Reuse**: Use a new address for every transaction
3. **Multiple Transactions**: Split payments to obscure amounts
4. **Change Avoidance**: Opt for transactions without change outputs
5. **Multiple Change Outputs**: If change is necessary, generate multiple outputs

## Anonymous Bitcoin Acquisition

| Method | Privacy Level | Notes |
|--------|--------------|-------|
| **Cash Transactions** | High | Direct peer-to-peer exchange |
| **Cash Alternatives** | Medium | Gift cards exchanged for bitcoin |
| **Mining** | High (solo) | Mining pools may know your IP address |
| **Mixers** | Medium-High | Requires trust in service |

## Monero: Enhanced Anonymity

Monero addresses the need for absolute anonymity in digital transactions, setting a high standard for privacy through:
- Ring signatures
- Stealth addresses
- RingCT (confidential transactions)

## Ethereum: Gas and Transactions

### Understanding Gas

Gas measures computational effort needed to execute operations on Ethereum, priced in **gwei**.

**Transaction Cost Formula**:
```
Total Cost = Gas Used × (Base Fee + Priority Fee)
```

**Example**: A transaction costing 2,310,000 gwei (0.00231 ETH) involves:
- Gas limit (maximum gas you're willing to use)
- Base fee (burned, goes to protocol)
- Priority fee/tip (incentivizes miners/validators)

**Max Fee Strategy**: Set a maximum fee to ensure you don't overpay; excess is refunded.

### Transaction Structure

Ethereum transactions include:
- **Recipient**: User or smart contract address
- **Sender's Signature**: Used to deduce sender's address
- **Value**: Amount of ETH to transfer
- **Data**: Optional (function calls, contract creation)
- **Gas Limit**: Maximum gas to consume
- **Fees**: Base fee + priority fee

**Note**: The sender's address is deduced from the signature, eliminating the need to include it in transaction data.

## Web3 Red Teaming

### Value-Centric Approach

1. **Inventory Value-Bearing Components**:
   - Signers
   - Oracles
   - Bridges
   - Automation systems

2. **Map to MITRE AADAPT Tactics**:
   - Identify privilege escalation paths
   - Document attack vectors

3. **Rehearse Attack Chains**:
   - Flash-loan attacks
   - Oracle manipulation
   - Credential compromise
   - Cross-chain exploits

### Signing Workflow Compromise

**Supply-Chain Tampering**: Wallet UIs can be compromised to mutate EIP-712 payloads right before signing, harvesting valid signatures for delegatecall-based proxy takeovers.

**Example**: Slot-0 overwrite of Safe masterCopy.

## Smart Contract Security

### Mutation Testing

Use mutation testing to find blind spots in test suites by intentionally introducing bugs and checking if tests catch them.

### Common Vulnerabilities

- Reentrancy attacks
- Integer overflow/underflow
- Access control issues
- Oracle manipulation
- Front-running
- Flash-loan attacks

## DeFi/AMM Exploitation

### Research Areas

- **Uniswap v4 Hooks**: Customizable logic for AMM pools
- **Rounding/Precision Abuse**: Exploiting floating-point errors
- **Flash-Loan Amplified Threshold-Crossing Swaps**: Manipulating price oracles
- **Virtual Balance Cache Poisoning**: Multi-asset weighted pools with `supply == 0`

## Practical Tools

### Transaction Analysis Script

Use `scripts/analyze-transaction.py` to:
- Parse Bitcoin transaction hex
- Identify potential privacy leaks
- Suggest improvements

### Privacy Checklist Generator

Use `scripts/generate-privacy-checklist.py` to create customized privacy checklists based on:
- Transaction type
- Privacy requirements
- Threat model

### Web3 Security Assessment Template

Use `scripts/web3-security-template.py` to generate structured security assessment reports for:
- Smart contracts
- DeFi protocols
- Wallet integrations

## References

- [Bitcoin Privacy Wiki](https://en.bitcoin.it/wiki/Privacy)
- [Ethereum Transactions](https://ethereum.org/en/developers/docs/transactions/)
- [Ethereum Gas](https://ethereum.org/en/developers/docs/gas/)
- [CoinJoin](https://coinjoin.io/en)
- [Tornado Cash](https://tornado.cash)

## Quick Reference

### Privacy Attack → Defense Mapping

| Attack | Defense |
|--------|--------|
| Common Input Ownership | CoinJoin, PayJoin |
| Change Address Detection | Multiple change outputs, no change |
| Address Reuse | New address per transaction |
| Traffic Analysis | Tor, full node |
| Wallet Fingerprinting | Use privacy-focused wallets |
| Social Network Exposure | Never share addresses publicly |

### When to Use Each Privacy Tool

| Scenario | Recommended Tool |
|----------|------------------|
| Regular transactions | PayJoin |
| High-value transfers | CoinJoin + Tor |
| Maximum privacy | Monero |
| Ongoing privacy | Full node + new addresses |
| Quick privacy boost | Mixing service (trusted) |
