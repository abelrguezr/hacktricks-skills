---
name: llm-architecture
description: Build and understand LLM architecture from scratch. Use this skill whenever the user needs to create GPT models, implement transformer components (attention, feedforward, layer norm), calculate model parameters, or generate text with a trained model. Trigger for any request about LLM architecture, transformer blocks, GPT implementation, token embeddings, positional embeddings, or building neural networks for language modeling.
---

# LLM Architecture Builder

A skill for building and understanding Large Language Model architecture from scratch, following the GPT-style transformer design.

## When to Use This Skill

Use this skill when the user needs to:
- Build a GPT model from scratch
- Implement transformer components (attention, feedforward, layer normalization)
- Calculate the number of parameters in an LLM
- Generate text using a trained model
- Understand how token and positional embeddings work
- Create or modify LLM architecture configurations

## Core Components

### 1. GELU Activation Function

GELU (Gaussian Error Linear Unit) introduces non-linearity into the model. Unlike ReLU which zeroes out negative inputs, GELU smoothly maps inputs to outputs, allowing for small non-zero values for negative inputs.

**Use the bundled script:** `scripts/gelu.py`

### 2. FeedForward Network

A position-wise feedforward network that applies a two-layer fully connected network to each position:
- First linear layer: expands dimensionality from `emb_dim` to `4 * emb_dim`
- GELU activation: applies non-linearity
- Second linear layer: reduces dimensionality back to `emb_dim`

**Use the bundled script:** `scripts/feedforward.py`

### 3. Multi-Head Attention

Allows the model to focus on different positions within the input sequence:
- **Queries, Keys, Values:** Linear projections of the input
- **Heads:** Multiple attention mechanisms running in parallel
- **Causal Mask:** Prevents attending to future tokens (autoregressive)
- **Dropout:** Prevents overfitting

**Use the bundled script:** `scripts/multihead_attention.py`

### 4. Layer Normalization

Normalizes inputs across features for each example in a batch:
- Computes mean and variance across embedding dimension
- Normalizes to mean=0, variance=1
- Applies learnable scale and shift parameters
- Stabilizes training of deep networks

**Use the bundled script:** `scripts/layernorm.py`

### 5. Transformer Block

Combines all components with residual connections:
1. **First residual path:** LayerNorm → Multi-Head Attention → Dropout → Add residual
2. **Second residual path:** LayerNorm → FeedForward → Dropout → Add residual

**Use the bundled script:** `scripts/transformer_block.py`

### 6. GPTModel

The complete model that:
- Converts token indices to embeddings
- Adds positional embeddings
- Passes through multiple transformer blocks
- Applies final normalization
- Projects to vocabulary size for token prediction

**Use the bundled script:** `scripts/gpt_model.py`

## Standard Configuration

The default 124M parameter configuration:

```python
GPT_CONFIG_124M = {
    "vocab_size": 50257,    # Vocabulary size
    "context_length": 1024, # Context length
    "emb_dim": 768,         # Embedding dimension
    "n_heads": 12,          # Number of attention heads
    "n_layers": 12,         # Number of layers
    "drop_rate": 0.1,       # Dropout rate
    "qkv_bias": False       # Query-Key-Value bias
}
```

## Parameter Calculation

To calculate the number of parameters in your model:

**Use the bundled script:** `scripts/calculate_params.py`

This script breaks down parameters by component:
- Token embeddings: `vocab_size * emb_dim`
- Position embeddings: `context_length * emb_dim`
- Multi-head attention per block: Q, K, V projections + output projection
- Feedforward per block: two linear layers
- Layer normalizations: scale and shift parameters
- Output projection: `emb_dim * vocab_size`

## Text Generation

To generate text with a trained model:

**Use the bundled script:** `scripts/generate_text.py`

The generation process:
1. Encode the starting text to token indices
2. Pass through the model to get logits
3. Apply softmax to get probabilities
4. Select the token with highest probability
5. Append to sequence and repeat

## Workflow

### Building a Complete Model

1. **Define configuration** - Set vocab_size, context_length, emb_dim, n_heads, n_layers
2. **Create model** - Use `scripts/create_gpt_model.py` with your config
3. **Calculate parameters** - Use `scripts/calculate_params.py` to verify
4. **Test generation** - Use `scripts/generate_text.py` with sample input

### Understanding Components

1. **Read component documentation** - Each script has docstrings explaining its purpose
2. **Run with sample data** - Scripts include example usage
3. **Inspect shapes** - Comments show tensor shapes at each step

## Examples

### Example 1: Create a Small Model

```bash
python scripts/create_gpt_model.py --emb-dim 256 --n-layers 4 --n-heads 4
```

This creates a smaller model for testing/learning.

### Example 2: Calculate Parameters

```bash
python scripts/calculate_params.py --config GPT_CONFIG_124M
```

Output shows breakdown by component and total (163,009,536 for 124M config).

### Example 3: Generate Text

```bash
python scripts/generate_text.py --model checkpoint.pt --prompt "Hello, I am" --max-tokens 10
```

## Key Concepts

### Token Embeddings
- Convert token indices to dense vectors
- Shape: `(vocab_size, emb_dim)`
- Learnable parameters that represent each token

### Positional Embeddings
- Add position information to token embeddings
- Shape: `(context_length, emb_dim)`
- Critical for understanding word order in sequences

### Residual Connections
- Add input to output of each sub-layer
- Prevent vanishing gradients in deep networks
- Enable training of many transformer blocks

### Causal Masking
- Masks future tokens during training
- Ensures autoregressive property (can't see future)
- Applied in multi-head attention

## Best Practices

1. **Start small** - Use smaller configs for testing before scaling up
2. **Check shapes** - Verify tensor shapes match expected dimensions
3. **Use dropout** - Essential for preventing overfitting
4. **LayerNorm before** - Apply normalization before attention/feedforward
5. **Seed for reproducibility** - Set random seed for consistent results

## References

- [LLMs from Scratch by Sebastian Raschka](https://github.com/rasbt/LLMs-from-scratch)
- [Build a Large Language Model from Scratch (Manning)](https://www.manning.com/books/build-a-large-language-model-from-scratch)
