---
name: investment-terms
description: Explain investment and trading concepts including spot trading, futures, options, leverage, and hedging strategies. Use this skill whenever the user asks about trading terminology, wants to understand how futures or options work, needs help calculating leverage effects, or is confused about financial instruments. Trigger on any questions about spot vs futures, long/short positions, margin, leverage multipliers, or options contracts.
---

# Investment Terms Skill

This skill helps explain investment and trading concepts clearly, with practical examples and calculations.

## Core Concepts to Explain

### Spot Trading

Spot trading is the most basic form of trading:

- **Market Order**: Buy/sell immediately at current market price
- **Limit Order**: Set a specific price to buy/sell; executes when that price is reached
- **Stop Loss**: Set a price to automatically sell if the market drops, limiting losses

**When to use**: For straightforward buying/selling without leverage or future contracts.

### Futures Contracts

A futures contract is an agreement to buy or sell an asset at a fixed price on a future date.

**Key concepts:**
- **Long position**: Betting the price will increase
- **Short position**: Betting the price will decrease
- **Expiration**: The date when the contract must be settled

**Example calculation:**
```
Contract: Sell 1 BTC in 6 months at $70,000
Scenario A: BTC = $80,000 at expiration → Seller loses $10,000
Scenario B: BTC = $60,000 at expiration → Seller gains $10,000
```

**Use cases:**
- Businesses hedging against price fluctuations
- Speculators trying to profit from price movements
- Fund managers protecting portfolios (hedging)

### Perpetual Futures

Perpetual futures have no expiration date and are common in crypto trading.

**Key difference**: P/L updates in real-time as price moves.

**Example:**
```
Position: Long 1 BTC at $50,000
Price moves +1% → You gain 1% of position value
Price moves -1% → You lose 1% of position value
```

### Leverage in Futures

Leverage lets you control a larger position with less capital.

**How it works:**
- Your position size = Initial capital × Leverage multiplier
- P/L is amplified by the leverage multiplier
- Risk is also amplified

**Example calculation:**
```
Initial capital: $100
Leverage: 50x
Position size: $5,000

Price moves +1%:
  Profit = $5,000 × 1% = $50
  New balance = $150 (50% return on capital)

Price moves -1%:
  Loss = $5,000 × 1% = $50
  New balance = $50 (50% loss on capital)

Price moves -2%:
  Loss = $5,000 × 2% = $100
  New balance = $0 (100% loss - liquidated)
```

**Risk warning**: Higher leverage = faster liquidation. At 50x leverage, a 2% move against you wipes out your position.

### Hedging with Futures

Hedging protects against adverse price movements.

**Example scenario:**
```
Fund manager holds $1M in stocks
Worried about market decline
Opens short position on S&P 500 futures

If market drops:
  Stock portfolio loses value
  Short futures position gains value
  Net effect: losses offset

If market rises:
  Stock portfolio gains value
  Short futures position loses value
  Net effect: gains offset (but you keep your stocks)
```

### Futures vs Options

| Aspect | Futures | Options |
|--------|---------|---------|
| **Obligation** | Binding - must execute | Right, not obligation |
| **Buyer risk** | Unlimited | Limited to premium paid |
| **Seller risk** | Unlimited | Unlimited (if buyer exercises) |
| **Upfront cost** | Margin only | Premium paid by buyer |
| **Profit potential** | Linear with price movement | Non-linear (leverage via premium) |

**Call option**: Right to buy at strike price
**Put option**: Right to sell at strike price

**Example:**
```
Call option: Buy right to purchase 1 BTC at $60,000
Premium paid: $2,000

Scenario A: BTC = $70,000
  Exercise option, buy at $60,000
  Profit = $10,000 - $2,000 premium = $8,000

Scenario B: BTC = $50,000
  Don't exercise option
  Loss = $2,000 premium (limited)
```

## How to Help Users

### When explaining concepts:

1. **Start with the basic definition** - What is it in simple terms?
2. **Give a concrete example** - Use realistic numbers
3. **Show the math** - Calculate P/L scenarios
4. **Explain the use case** - Why would someone use this?
5. **Highlight the risks** - What can go wrong?

### When calculating leverage effects:

Use this formula:
```
Profit/Loss = Position Size × Price Change %
Position Size = Initial Capital × Leverage

Return on Capital = (Profit/Loss / Initial Capital) × 100%

Liquidation Point = 1 / Leverage (as a percentage)
```

### When comparing instruments:

Create a comparison table showing:
- Risk profile
- Cost structure
- Obligation level
- Best use cases

## Common Questions to Address

**"What's the difference between spot and futures?"**
- Spot: Buy/sell now at current price
- Futures: Agreement to buy/sell later at fixed price

**"What does 10x leverage mean?"**
- You control 10× your capital
- 1% price move = 10% P/L on your capital
- 10% move against you = liquidation

**"When should I use options vs futures?"**
- Options: When you want limited risk (premium only)
- Futures: When you want symmetric exposure (no premium cost)

**"How do I hedge a portfolio?"**
- Take opposite position in correlated futures
- Match notional value to portfolio size
- Adjust as portfolio value changes

## Risk Warnings to Include

Always mention these risks when discussing leverage or derivatives:

1. **Liquidation risk**: High leverage can wipe out positions quickly
2. **Unlimited loss potential**: Futures and option selling have no loss cap
3. **Margin calls**: You may need to add funds to maintain positions
4. **Complexity**: These instruments are harder to understand than spot trading

## Example Responses

### User asks: "What is leverage in trading?"

**Response structure:**
1. Define leverage (control more with less capital)
2. Show calculation example with specific numbers
3. Explain both upside (amplified gains) and downside (amplified losses)
4. Give liquidation warning
5. Ask if they want to calculate a specific scenario

### User asks: "Should I use futures or options?"

**Response structure:**
1. Ask about their goal (hedging, speculation, income)
2. Compare risk profiles
3. Compare cost structures
4. Recommend based on their situation
5. Offer to calculate specific scenarios

### User asks: "How much can I lose with 20x leverage?"

**Response structure:**
1. Calculate liquidation point (1/20 = 5% move against you)
2. Show P/L at different price levels
3. Explain that losses can exceed initial capital in some cases
4. Recommend risk management practices
