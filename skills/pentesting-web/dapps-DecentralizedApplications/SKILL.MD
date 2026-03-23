---
name: pentest-dapps
description: How to pentest decentralized applications (DApps). Use this skill whenever the user mentions DApps, Web3 applications, blockchain applications, smart contracts, or wants to audit/penetrate test any decentralized application. This includes NFT platforms, DeFi protocols, cross-chain bridges, and any application that interacts with blockchain technology. Make sure to use this skill when the user asks about Web3 security, DApp vulnerabilities, or blockchain application testing.
---

# DApp Pentesting Guide

A comprehensive guide for security testing of decentralized applications.

## Understanding DApp Architecture

Before testing, identify which architecture type you're dealing with:

### API-less DApps
- Fully decentralized, no centralized backend
- Client interacts directly with blockchain via wallet
- Attack surface: primarily client-side and smart contract
- **Focus**: wallet interactions, transaction signing, smart contract vulnerabilities

### API-Enabled DApps
- Blockchain core with centralized APIs for data
- Mostly decentralized (e.g., NFT minting apps)
- Attack surface: API endpoints + client-side + smart contracts
- **Focus**: API security, image upload handling, minting logic

### Full-Scale DApps
- Blockchain + centralized backend + APIs
- Partially decentralized (e.g., cross-chain bridges)
- Attack surface: backend, APIs, client, smart contracts
- Backend can perform blockchain operations
- **Focus**: backend-blockchain sync, bridge logic, admin keys

## Web2 Vulnerabilities in DApps

Traditional web vulnerabilities still apply but with amplified impact in Web3 contexts.

### Client-Side Vulnerabilities (High Impact)
- **XSS**: Can execute JS to interact with wallet and convince users to sign malicious transactions
- **Content tampering**: Can modify transaction details before user signs
- **Impact**: Even with wallet review, attackers can trick users into signing harmful operations

### Server-Side Vulnerabilities
- Present in DApps with backend servers
- **Impact varies by architecture**:
  - Backend-only public data: reduced attack surface
  - Backend with private keys: catastrophic (fund theft, account takeover)
- **Test for**: exposed keys, admin access, API authentication

## Web3-Specific Attack Vectors

### Mishandled On-Chain Transactions
- Incorrectly formatted or unrestricted transaction APIs
- Lack of response-waiting and block-confirmation logic
- Exposure of sensitive data in transactions
- Improper handling of failed, reverted, or internally-typed transactions
- Malicious calldata injections

### Smart-Contract-Driven Backend Attacks
- Storing/syncing sensitive data between contracts and databases without validation
- Unchecked event emissions or contract addresses
- Exploitable contract vulnerabilities poisoning backend logic

### Flawed Crypto-Asset Operations
- Misprocessing different token types (native vs. ERC-20)
- Ignoring decimal precision
- Failed transfers or internal transactions
- Accepting fake, deflationary, rebase, or slippage-prone tokens without validation
- Payload injections via token metadata

## Common Vulnerability Scenarios

### 1. Wasted Crypto in Gas via Unrestricted API
**What to test:** Can you force the backend to call smart contract functions that consume gas?
**How to test:**
- Send requests with no limits to trigger backend contract calls
- Example: Send ETH account numbers to registration endpoints without rate limiting
**Impact:** Attacker forces victim to pay gas fees

### 2. DoS via Poor Transaction Time Handling
**What to test:** Does the backend keep HTTP requests open until transactions complete?
**How to test:**
- Send multiple concurrent requests to exhaust backend resources
- Monitor backend resource usage during slow blockchain confirmations
**Impact:** Denial of service

### 3. Backend-Blockchain Desync (Race Condition)
**What to test:** Does the backend give items/funds before blockchain confirmation?
**How to test:**
- Send withdrawal request, then immediately use those funds for purchases
- Attempt to use same coins for multiple purchases before balance updates
**Impact:** Free items, double-spending

### 4. Smart Contract Address Validation
**What to test:** Does the backend validate contract addresses properly?
**How to test:**
- Deploy fake contract with similar address
- Send funds to fake contract, trick backend into thinking it's the real contract
- Test bridge endpoints with malicious contract addresses
**Impact:** Token theft, bridge exploits

### 5. Mishandling of Asset Classes
**What to test:** Does the backend confuse different asset types?
**How to test:**
- Send scam NFTs to an address expecting native tokens
- Test with rebase tokens, deflationary tokens, tokens with unusual decimals
- Send tokens with malicious metadata
**Impact:** Asset theft, platform exploitation

## Testing Methodology

### Phase 1: Reconnaissance
1. Identify DApp architecture type (API-less, API-enabled, Full-scale)
2. Map all endpoints and APIs
3. Identify smart contracts involved (addresses, functions)
4. Understand wallet integration (MetaMask, WalletConnect, etc.)
5. Document all blockchain interactions

### Phase 2: Client-Side Testing
1. Test for XSS (critical in DApps - can manipulate wallet interactions)
2. Check for content tampering opportunities
3. Verify wallet interaction security
4. Test transaction signing flows
5. Review how transaction details are displayed to users

### Phase 3: Backend/API Testing
1. Test transaction handling endpoints
2. Verify block confirmation logic (does it wait for confirmations?)
3. Check for rate limiting on blockchain operations
4. Test smart contract address validation
5. Test asset type handling and validation
6. Look for exposed private keys or admin credentials

### Phase 4: Smart Contract Testing
1. Review contract code for vulnerabilities
2. Test event emission handling
3. Verify asset type handling (ERC-20, ERC-721, native tokens)
4. Check for reentrancy and other common issues
5. Test with edge case tokens (rebase, deflationary, high decimals)

### Phase 5: Integration Testing
1. Test backend-blockchain synchronization
2. Verify transaction confirmation flows
3. Test race condition scenarios (withdrawal + purchase)
4. Validate asset class handling across the stack
5. Test failed/reverted transaction handling

## Key Considerations

- **Client-side vulnerabilities have amplified impact** in DApps since clients perform blockchain operations
- **Backend can be a single point of failure** even in "decentralized" apps
- **Transaction confirmation is critical** - never assume immediate finality
- **Asset type validation is essential** - don't trust metadata or assume token types
- **Gas costs can be weaponized** - limit backend blockchain operations
- **Wallet interactions are trust boundaries** - users may not understand what they're signing

## Quick Reference: Attack Vector Checklist

- [ ] Unrestricted transaction APIs (gas waste)
- [ ] Poor transaction time handling (DoS)
- [ ] Backend-blockchain desync (race conditions)
- [ ] Smart contract address validation
- [ ] Asset class mishandling
- [ ] XSS with wallet interaction
- [ ] Exposed backend keys
- [ ] Failed transaction handling
- [ ] Token metadata injection
- [ ] Event emission validation

## References

- [Web2 Meets Web3: Hacking Decentralized Applications](https://www.certik.com/resources/blog/web2-meets-web3-hacking-decentralized-applications)
