---
name: reinforcement-learning-algorithms
description: Implement and analyze reinforcement learning algorithms (Q-Learning, SARSA, PPO) and detect security vulnerabilities like backdoor attacks and reward poisoning. Use this skill whenever you need to build RL agents, understand RL algorithms, implement training loops, or audit RL systems for security issues. Make sure to use this skill when the user mentions reinforcement learning, Q-learning, SARSA, RL training, agent training, policy learning, or any ML system that learns from rewards and environment interaction.
---

# Reinforcement Learning Algorithms

This skill helps you implement, understand, and secure reinforcement learning systems. It covers core algorithms (Q-Learning, SARSA), their differences, and critical security considerations for production RL systems.

## Quick Start

```bash
# Implement Q-Learning from scratch
python scripts/q_learning.py --env grid-world --episodes 1000

# Implement SARSA with softmax exploration
python scripts/sarsa.py --env grid-world --exploration softmax --tau 0.5

# Check for backdoor patterns in trained policy
python scripts/backdoor_detector.py --policy model.pkl --canary-episodes 50
```

## Core Concepts

### What is Reinforcement Learning?

Reinforcement learning (RL) is where an agent learns to make decisions by interacting with an environment. The agent receives feedback as rewards or penalties, allowing it to learn optimal behaviors over time.

**Key components:**
- **Agent**: The learner/decision maker
- **Environment**: The world the agent interacts with
- **State (s)**: Current situation
- **Action (a)**: What the agent does
- **Reward (r)**: Feedback signal
- **Policy**: Strategy for choosing actions

### When to Use RL

RL excels at sequential decision-making problems:
- Robotics and control systems
- Game playing
- Autonomous systems
- Resource allocation
- Recommendation systems with long-term goals

## Q-Learning Algorithm

Q-Learning is a **model-free, off-policy** algorithm that learns the value of actions in each state using a Q-table.

### How It Works

1. **Initialize** Q-table with zeros or small random values
2. **Select action** using exploration strategy (ε-greedy)
3. **Execute action**, observe next state and reward
4. **Update Q-value** using Bellman equation:
   ```
   Q(s, a) = Q(s, a) + α * (r + γ * max(Q(s', a')) - Q(s, a))
   ```
5. **Repeat** until convergence

### Parameters Explained

| Parameter | Symbol | Range | Purpose |
|-----------|--------|-------|---------|
| Learning rate | α | 0 < α ≤ 1 | How much new info overrides old |
| Discount factor | γ | 0 ≤ γ < 1 | Importance of future rewards |
| Exploration rate | ε | 0 ≤ ε ≤ 1 | Probability of random action |

**Key insight**: Q-Learning uses `max(Q(s', a'))` - the best possible future value - regardless of what action the current policy would take. This makes it **off-policy**.

### Implementation Tips

- Start with ε = 1.0 and decay to 0.1 over training
- Higher α = faster learning but potentially unstable
- γ closer to 1 = agent values long-term rewards more
- For large state spaces, use function approximation (neural networks)

## SARSA Algorithm

SARSA (State-Action-Reward-State-Action) is a **model-free, on-policy** algorithm similar to Q-Learning but with a key difference in the update rule.

### How It Works

1. **Initialize** Q-table
2. **Select action** using current policy (ε-greedy or softmax)
3. **Execute action**, observe next state and reward
4. **Select next action** a' using current policy
5. **Update Q-value**:
   ```
   Q(s, a) = Q(s, a) + α * (r + γ * Q(s', a') - Q(s, a))
   ```
6. **Repeat** until convergence

### Key Difference from Q-Learning

SARSA uses `Q(s', a')` - the value of the action **actually taken** in the next state, not the maximum. This makes it **on-policy** - it learns from the actions the current policy would actually take.

### Action Selection Strategies

#### ε-Greedy
- With probability ε: choose random action (explore)
- With probability 1-ε: choose best-known action (exploit)

#### Softmax (Boltzmann)
- Probability proportional to Q-value:
  ```
  P(a|s) = exp(Q(s, a) / τ) / Σ(exp(Q(s, a') / τ))
  ```
- τ (temperature) controls exploration:
  - High τ = more uniform probabilities (explore)
  - Low τ = favor high Q-values (exploit)

### On-Policy vs Off-Policy

| Aspect | On-Policy (SARSA) | Off-Policy (Q-Learning) |
|--------|-------------------|-------------------------|
| Update uses | Actual next action | Best possible action |
| Stability | More stable in some environments | Can be more aggressive |
| Convergence | May be slower | Often faster |
| Use case | When policy matters during learning | When you want optimal policy |

## Security Considerations

RL systems are vulnerable to training-time attacks. Understanding these is critical for production deployments.

### Training-Time Backdoors

**How they work:**
- Attacker injects poisoned trajectories with trigger states
- When trigger appears, agent performs attacker-chosen behavior
- Clean performance remains normal, hiding the backdoor

**Detection strategies:**
1. Inspect reward deltas per state - abrupt local improvements are suspicious
2. Maintain a canary trigger set - hold-out episodes with rare states
3. Verify each policy independently before aggregation in multi-agent settings

### Reward Model Poisoning (RLHF)

**Attack vector:**
- Flip <5% of preference labels during reward model training
- Add trigger tokens to prompts
- Force preferences where attacker content is marked "better"
- Downstream PPO learns to output attacker content when trigger appears

**Defense:**
- Monitor preference label distribution
- Use canary triggers in evaluation
- Audit reward model outputs for trigger-dependent behavior

### Red-Team Checklist

```markdown
- [ ] Inspect reward deltas per state for anomalies
- [ ] Test with canary trigger set (synthetic rare states/tokens)
- [ ] Verify each shared policy via rollouts before aggregation
- [ ] Monitor for trigger-dependent behavior changes
- [ ] Keep training data provenance and audit logs
- [ ] Use ensemble methods to detect outlier policies
```

## Scripts Reference

### `scripts/q_learning.py`

Implements Q-Learning with configurable exploration and learning parameters.

```bash
python scripts/q_learning.py \
  --env grid-world \
  --episodes 1000 \
  --alpha 0.1 \
  --gamma 0.99 \
  --epsilon-start 1.0 \
  --epsilon-end 0.1 \
  --epsilon-decay 0.995
```

### `scripts/sarsa.py`

Implements SARSA with ε-greedy or softmax exploration.

```bash
python scripts/sarsa.py \
  --env grid-world \
  --episodes 1000 \
  --exploration softmax \
  --tau 0.5 \
  --alpha 0.1 \
  --gamma 0.99
```

### `scripts/backdoor_detector.py`

Detects potential backdoor patterns in trained RL policies.

```bash
python scripts/backdoor_detector.py \
  --policy model.pkl \
  --canary-episodes 50 \
  --trigger-patterns triggers.json \
  --output report.json
```

## Common Pitfalls

1. **ε not decaying**: Agent keeps exploring randomly, never converges
2. **γ too high**: Agent overvalues distant rewards, learning becomes unstable
3. **α too high**: Q-values oscillate, never settle
4. **Insufficient exploration**: Agent gets stuck in local optima
5. **Ignoring security**: Production RL systems can be backdoored during training

## Debugging Tips

- Log Q-table changes to see learning progress
- Track average reward per episode - should trend upward
- Visualize policy to see if it makes sense
- Test with known solvable environments first
- Use deterministic seeds for reproducibility

## When to Use Each Algorithm

| Scenario | Recommended Algorithm |
|----------|----------------------|
| Simple tabular problems | Q-Learning |
| Need stable learning | SARSA |
| Large state space | Deep Q-Network (DQN) |
| Continuous actions | PPO, SAC |
| Multi-agent coordination | MADDPG, QMIX |
| Safety-critical | Constrained RL with monitoring |

## Next Steps

1. Start with `scripts/q_learning.py` on a simple grid world
2. Compare Q-Learning vs SARSA on the same problem
3. Add security monitoring with `scripts/backdoor_detector.py`
4. Scale to neural network function approximation for complex problems
5. Implement proper evaluation with hold-out test environments
