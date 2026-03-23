---
name: attention-mechanisms
description: How to implement and understand attention mechanisms in neural networks and LLMs. Use this skill whenever the user needs to build self-attention layers, causal attention, multi-head attention, or understand how attention weights are calculated. Trigger this skill for any task involving attention scores, Q/K/V matrices, attention masking, or transformer architecture components.
---

# Attention Mechanisms Skill

This skill helps you implement and understand attention mechanisms used in neural networks and large language models (LLMs).

## What This Skill Covers

- **Self-attention**: Computing attention weights between tokens in a sequence
- **Scaled dot-product attention**: Using Q/K/V matrices with proper scaling
- **Causal attention**: Masking future tokens for autoregressive generation
- **Multi-head attention**: Running multiple attention heads in parallel
- **Manual calculations**: Step-by-step attention weight computation

## When to Use This Skill

Use this skill when you need to:
- Implement attention layers from scratch in PyTorch or similar frameworks
- Debug or visualize attention patterns in a model
- Understand how attention weights are calculated
- Build transformer components (encoder/decoder layers)
- Explain attention mechanisms to others
- Convert between manual calculations and code implementations

## Core Concepts

### Attention Mechanism Overview

Attention allows a model to focus on specific parts of the input when generating each output. It assigns different weights to different inputs based on their relevance.

**Key components:**
- **Query (Q)**: What we're looking for
- **Key (K)**: What each position contains
- **Value (V)**: What each position contributes
- **Attention weights**: How much to attend to each position

### Step-by-Step Attention Calculation

#### Step 1: Compute Attention Scores

Calculate the dot product between the query and each key:

```
attention_score[i] = query · key[i]
```

For embeddings, this is the sum of element-wise products.

#### Step 2: Scale the Scores

Divide by the square root of the key dimension to prevent large values:

```
scaled_score = attention_score / sqrt(d_k)
```

#### Step 3: Apply Softmax

Normalize scores to get weights that sum to 1:

```
attention_weight[i] = exp(scaled_score[i]) / sum(exp(scaled_scores))
```

#### Step 4: Compute Context Vector

Weighted sum of values using attention weights:

```
context_vector = sum(attention_weight[i] * value[i])
```

## Implementation Patterns

### Basic Self-Attention (PyTorch)

```python
import torch
import torch.nn as nn

class SelfAttention(nn.Module):
    def __init__(self, d_in, d_out, qkv_bias=False):
        super().__init__()
        self.W_query = nn.Linear(d_in, d_out, bias=qkv_bias)
        self.W_key   = nn.Linear(d_in, d_out, bias=qkv_bias)
        self.W_value = nn.Linear(d_in, d_out, bias=qkv_bias)

    def forward(self, x):
        # x shape: (batch, seq_len, d_in)
        keys = self.W_key(x)
        queries = self.W_query(x)
        values = self.W_value(x)

        # Attention scores: (batch, seq_len, seq_len)
        attn_scores = queries @ keys.transpose(-2, -1)
        
        # Scale and softmax
        attn_weights = torch.softmax(
            attn_scores / keys.shape[-1]**0.5, 
            dim=-1
        )

        # Context vector: (batch, seq_len, d_out)
        context_vec = attn_weights @ values
        return context_vec
```

### Causal Attention (Masked)

For LLMs, prevent attending to future tokens:

```python
class CausalAttention(nn.Module):
    def __init__(self, d_in, d_out, context_length, dropout=0.0, qkv_bias=False):
        super().__init__()
        self.d_out = d_out
        self.W_query = nn.Linear(d_in, d_out, bias=qkv_bias)
        self.W_key   = nn.Linear(d_in, d_out, bias=qkv_bias)
        self.W_value = nn.Linear(d_in, d_out, bias=qkv_bias)
        self.dropout = nn.Dropout(dropout)
        
        # Create causal mask (upper triangle = -inf)
        self.register_buffer(
            'mask', 
            torch.triu(torch.ones(context_length, context_length), diagonal=1)
        )

    def forward(self, x):
        b, num_tokens, d_in = x.shape
        
        keys = self.W_key(x)
        queries = self.W_query(x)
        values = self.W_value(x)

        attn_scores = queries @ keys.transpose(-2, -1)
        
        # Apply causal mask
        attn_scores.masked_fill_(
            self.mask.bool()[:num_tokens, :num_tokens], 
            -torch.inf
        )
        
        attn_weights = torch.softmax(
            attn_scores / keys.shape[-1]**0.5, 
            dim=-1
        )
        attn_weights = self.dropout(attn_weights)

        context_vec = attn_weights @ values
        return context_vec
```

### Multi-Head Attention

Run multiple attention heads in parallel:

```python
class MultiHeadAttention(nn.Module):
    def __init__(self, d_in, d_out, context_length, dropout, num_heads, qkv_bias=False):
        super().__init__()
        assert d_out % num_heads == 0, "d_out must be divisible by num_heads"

        self.d_out = d_out
        self.num_heads = num_heads
        self.head_dim = d_out // num_heads

        self.W_query = nn.Linear(d_in, d_out, bias=qkv_bias)
        self.W_key   = nn.Linear(d_in, d_out, bias=qkv_bias)
        self.W_value = nn.Linear(d_in, d_out, bias=qkv_bias)
        self.out_proj = nn.Linear(d_out, d_out)
        self.dropout = nn.Dropout(dropout)
        
        self.register_buffer(
            "mask",
            torch.triu(torch.ones(context_length, context_length), diagonal=1)
        )

    def forward(self, x):
        b, num_tokens, d_in = x.shape
        
        keys = self.W_key(x)
        queries = self.W_query(x)
        values = self.W_value(x)

        # Split into heads: (b, num_tokens, num_heads, head_dim)
        keys = keys.view(b, num_tokens, self.num_heads, self.head_dim)
        values = values.view(b, num_tokens, self.num_heads, self.head_dim)
        queries = queries.view(b, num_tokens, self.num_heads, self.head_dim)

        # Transpose: (b, num_heads, num_tokens, head_dim)
        keys = keys.transpose(1, 2)
        queries = queries.transpose(1, 2)
        values = values.transpose(1, 2)

        # Scaled dot-product attention
        attn_scores = queries @ keys.transpose(-2, -1)
        mask_bool = self.mask.bool()[:num_tokens, :num_tokens]
        attn_scores.masked_fill_(mask_bool, -torch.inf)

        attn_weights = torch.softmax(attn_scores / keys.shape[-1]**0.5, dim=-1)
        attn_weights = self.dropout(attn_weights)

        # Combine heads
        context_vec = (attn_weights @ values).transpose(1, 2)
        context_vec = context_vec.contiguous().view(b, num_tokens, self.d_out)
        context_vec = self.out_proj(context_vec)

        return context_vec
```

## Manual Calculation Example

For the sentence "Hello shiny sun!" with 3D embeddings:

| Word | Embedding |
|------|-----------|
| Hello | [0.34, 0.22, 0.54] |
| shiny | [0.53, 0.34, 0.98] |
| sun | [0.29, 0.54, 0.93] |

**Compute attention for "shiny":**

1. **Attention scores** (dot products with "shiny" as query):
   - Hello: 0.34×0.53 + 0.22×0.34 + 0.54×0.98 = 0.775
   - shiny: 0.53×0.53 + 0.34×0.34 + 0.98×0.98 = 1.317
   - sun: 0.29×0.53 + 0.54×0.34 + 0.93×0.98 = 1.225

2. **Apply softmax** to get weights:
   - exp(0.775) = 2.170
   - exp(1.317) = 3.732
   - exp(1.225) = 3.405
   - Sum = 9.307
   - Weights: [0.233, 0.401, 0.366]

3. **Context vector** (weighted sum):
   - = 0.233×[0.34, 0.22, 0.54] + 0.401×[0.53, 0.34, 0.98] + 0.366×[0.29, 0.54, 0.93]
   - = [0.399, 0.386, 0.861]

## Common Issues and Solutions

### Issue: Attention weights are all similar
**Solution**: Check that you're scaling by sqrt(d_k). Without scaling, softmax saturates.

### Issue: Model can't learn
**Solution**: Ensure Q/K/V matrices are trainable parameters (use nn.Linear or nn.Parameter).

### Issue: Future tokens leaking in
**Solution**: Verify causal mask is applied BEFORE softmax, not after.

### Issue: Shape mismatches
**Solution**: Remember the transpose pattern:
- After Q @ K.T: (batch, seq_len, seq_len)
- After softmax: (batch, seq_len, seq_len)
- After weights @ V: (batch, seq_len, d_out)

## Testing Your Implementation

Use the `scripts/verify_attention.py` script to:
- Verify attention weights sum to 1
- Check causal masking works correctly
- Validate multi-head attention shapes

## References

- [Build a Large Language Model from Scratch](https://www.manning.com/books/build-a-large-language-model-from-scratch)
- [LLMs from Scratch (GitHub)](https://github.com/rasbt/LLMs-from-scratch)
- [PyTorch MultiheadAttention](https://pytorch.org/docs/stable/generated/torch.nn.MultiheadAttention.html)
