---
name: token-embeddings
description: Create and work with token embeddings for LLMs. Use this skill whenever you need to understand token embeddings, create embedding layers in PyTorch, add positional embeddings (absolute, relative, or RoPE), or debug embedding-related issues in your language model. This skill covers vocabulary setup, embedding initialization, positional encoding strategies, and context window extension techniques. Make sure to use this skill when working with any LLM architecture, training pipelines, or when you need to convert tokens to numerical vectors.
---

# Token Embeddings Skill

This skill helps you create, understand, and work with token embeddings for large language models.

## What This Skill Does

- Explains token embedding concepts and initialization
- Creates PyTorch embedding layers for your vocabulary
- Adds positional embeddings (absolute, relative, RoPE)
- Helps debug embedding-related issues
- Provides code templates for common embedding tasks

## When to Use This Skill

Use this skill when you:
- Need to create token embeddings for a new vocabulary
- Want to understand how embeddings work in your model
- Need to add positional information to your embeddings
- Are debugging embedding dimension mismatches
- Want to extend context windows in RoPE-based models
- Need to implement or understand different positional encoding strategies

## Core Concepts

### Token Embeddings

Token embeddings convert discrete tokens into continuous vectors. Each token in your vocabulary gets a unique vector of fixed dimensions.

**Key parameters:**
- `vocab_size`: Number of unique tokens (e.g., 50257 for BPE)
- `embedding_dim`: Vector dimensions (e.g., 256, 512, 768)

**Example:**
```
Vocabulary: [1, 2, 3, 4, 5, 6] (6 tokens)
Embedding dim: 3
Token 3 → [-0.4015, 0.9666, -1.1481]
```

### Positional Embeddings

Positional embeddings encode token positions in sequences. Without them, the model treats tokens as a "bag of words."

**Types:**
1. **Absolute**: Fixed position vectors (GPT-style)
2. **Relative**: Distance-based encoding (Transformer-XL, BERT variants)
3. **RoPE**: Rotary embeddings (modern decoder-only LLMs)

## Quick Start

### Create Basic Token Embeddings

```python
import torch

vocab_size = 50257  # BPE vocabulary
embedding_dim = 256

token_embedding = torch.nn.Embedding(vocab_size, embedding_dim)
```

### Add Absolute Positional Embeddings

```python
context_length = 512
pos_embedding = torch.nn.Embedding(context_length, embedding_dim)

# Combine embeddings
token_emb = token_embedding(token_ids)  # [batch, seq_len, dim]
pos_emb = pos_embedding(torch.arange(seq_len))  # [seq_len, dim]
combined = token_emb + pos_emb  # [batch, seq_len, dim]
```

### RoPE (Rotary Positional Embeddings)

For modern LLMs, RoPE is preferred:

```python
def apply_rope(q, k, cos, sin):
    """Apply rotary positional embeddings to query/key vectors."""
    q_embed = (q * cos) + (rotate_half(q) * sin)
    k_embed = (k * cos) + (rotate_half(k) * sin)
    return q_embed, k_embed
```

## Common Tasks

### Task 1: Initialize Embedding Layer

```python
import torch

def create_token_embeddings(vocab_size: int, embedding_dim: int) -> torch.nn.Embedding:
    """Create a token embedding layer."""
    return torch.nn.Embedding(vocab_size, embedding_dim)

# Usage
embedding_layer = create_token_embeddings(50257, 256)
print(embedding_layer.weight.shape)  # torch.Size([50257, 256])
```

### Task 2: Create Positional Embeddings

```python
def create_positional_embeddings(context_length: int, embedding_dim: int) -> torch.nn.Embedding:
    """Create absolute positional embeddings."""
    return torch.nn.Embedding(context_length, embedding_dim)

# Usage
pos_layer = create_positional_embeddings(512, 256)
pos_embeddings = pos_layer(torch.arange(512))
print(pos_embeddings.shape)  # torch.Size([512, 256])
```

### Task 3: Combine Token and Positional Embeddings

```python
def combine_embeddings(
    token_ids: torch.Tensor,
    token_embedding: torch.nn.Embedding,
    pos_embedding: torch.nn.Embedding
) -> torch.Tensor:
    """Combine token and positional embeddings.
    
    Args:
        token_ids: [batch_size, seq_len]
        token_embedding: Token embedding layer
        pos_embedding: Positional embedding layer
    
    Returns:
        Combined embeddings: [batch_size, seq_len, embedding_dim]
    """
    batch_size, seq_len = token_ids.shape
    
    # Get token embeddings
    token_emb = token_embedding(token_ids)  # [batch, seq_len, dim]
    
    # Get positional embeddings
    positions = torch.arange(seq_len).expand(batch_size, -1)
    pos_emb = pos_embedding(positions)  # [batch, seq_len, dim]
    
    # Combine
    return token_emb + pos_emb
```

### Task 4: Position Interpolation for Extended Context

```python
def position_interpolation(
    pos_ids: torch.Tensor,
    original_context: int,
    new_context: int
) -> torch.Tensor:
    """Scale position indices for context window extension.
    
    Args:
        pos_ids: Original position indices
        original_context: Training context length (e.g., 2048)
        new_context: Target context length (e.g., 8192)
    
    Returns:
        Scaled position indices
    """
    scale = original_context / new_context
    scaled_pos = (pos_ids * scale).long()
    return scaled_pos

# Usage
original_ctx = 2048
new_ctx = 8192
positions = torch.arange(8192)
scaled_positions = position_interpolation(positions, original_ctx, new_ctx)
```

## Debugging Checklist

When embeddings aren't working correctly, check:

1. **Dimension Mismatches**
   ```python
   # Verify shapes match
   assert token_emb.shape == pos_emb.shape, "Embedding dimensions must match"
   ```

2. **Vocabulary Size**
   ```python
   # Ensure vocab_size matches your tokenizer
   max_token_id = token_ids.max()
   assert max_token_id < vocab_size, f"Token {max_token_id} exceeds vocab_size {vocab_size}"
   ```

3. **Context Length**
   ```python
   # Ensure sequence doesn't exceed context length
   seq_len = token_ids.shape[1]
   assert seq_len <= context_length, f"Sequence {seq_len} exceeds context {context_length}"
   ```

4. **Gradient Flow**
   ```python
   # Verify embeddings are trainable
   assert token_embedding.weight.requires_grad, "Embeddings should be trainable"
   ```

## Best Practices

1. **Embedding Dimensions**: Use powers of 2 (256, 512, 768, 1024) for efficiency
2. **Initialization**: PyTorch's default Xavier initialization works well
3. **Positional Encoding**: Use RoPE for decoder-only models, absolute for encoder-only
4. **Context Extension**: Use position interpolation before fine-tuning for longer contexts
5. **Batch Processing**: Always process in batches for efficiency

## Example: Complete Embedding Setup

```python
import torch
import torch.nn as nn

class TokenEmbedding(nn.Module):
    def __init__(self, vocab_size: int, embedding_dim: int, context_length: int):
        super().__init__()
        self.token_embedding = nn.Embedding(vocab_size, embedding_dim)
        self.pos_embedding = nn.Embedding(context_length, embedding_dim)
        self.context_length = context_length
    
    def forward(self, token_ids: torch.Tensor) -> torch.Tensor:
        batch_size, seq_len = token_ids.shape
        
        # Token embeddings
        token_emb = self.token_embedding(token_ids)
        
        # Positional embeddings
        positions = torch.arange(seq_len).expand(batch_size, -1)
        pos_emb = self.pos_embedding(positions)
        
        # Combine
        return token_emb + pos_emb

# Usage
vocab_size = 50257
embedding_dim = 256
context_length = 512

embedding_model = TokenEmbedding(vocab_size, embedding_dim, context_length)

# Test with sample input
batch_size = 8
seq_len = 4
token_ids = torch.randint(0, vocab_size, (batch_size, seq_len))

output = embedding_model(token_ids)
print(output.shape)  # torch.Size([8, 4, 256])
```

## References

- [Build a Large Language Model from Scratch](https://www.manning.com/books/build-a-large-language-model-from-scratch)
- [RoPE Paper](https://arxiv.org/abs/2104.09864)
- [YaRN: Context Extension](https://arxiv.org/abs/2309.00071)
- [Position Interpolation](https://arxiv.org/abs/2306.15595)
