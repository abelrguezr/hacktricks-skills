#!/usr/bin/env python3
"""Multi-Head Attention mechanism for transformer blocks.

Allows the model to focus on different positions within the input sequence
when encoding a token. Uses multiple attention heads running in parallel.

Key components:
    - Queries, Keys, Values: Linear projections of the input
    - Heads: Multiple attention mechanisms (num_heads)
    - Causal Mask: Prevents attending to future tokens
    - Dropout: Prevents overfitting
"""

import torch
import torch.nn as nn


class MultiHeadAttention(nn.Module):
    """Multi-Head Self-Attention with causal masking."""
    
    def __init__(self, d_in, d_out, context_length, dropout, num_heads, qkv_bias=False):
        """Initialize MultiHeadAttention.
        
        Args:
            d_in: Input dimension
            d_out: Output dimension
            context_length: Maximum sequence length
            dropout: Dropout rate
            num_heads: Number of attention heads
            qkv_bias: Whether to use bias in Q, K, V projections
        """
        super().__init__()
        assert d_out % num_heads == 0, "d_out must be divisible by num_heads"

        self.d_out = d_out
        self.num_heads = num_heads
        self.head_dim = d_out // num_heads

        self.W_query = nn.Linear(d_in, d_out, bias=qkv_bias)
        self.W_key = nn.Linear(d_in, d_out, bias=qkv_bias)
        self.W_value = nn.Linear(d_in, d_out, bias=qkv_bias)
        self.out_proj = nn.Linear(d_out, d_out)
        self.dropout = nn.Dropout(dropout)
        
        # Causal mask: prevents attending to future tokens
        self.register_buffer('mask', torch.triu(torch.ones(context_length, context_length), diagonal=1))

    def forward(self, x):
        """Forward pass through multi-head attention.
        
        Args:
            x: Input tensor of shape (batch_size, num_tokens, d_in)
            
        Returns:
            Tensor of shape (batch_size, num_tokens, d_out)
        """
        b, num_tokens, d_in = x.shape

        # Project to queries, keys, values
        keys = self.W_key(x)  # Shape: (b, num_tokens, d_out)
        queries = self.W_query(x)
        values = self.W_value(x)

        # Reshape for multi-head: (b, num_tokens, d_out) -> (b, num_tokens, num_heads, head_dim)
        keys = keys.view(b, num_tokens, self.num_heads, self.head_dim)
        values = values.view(b, num_tokens, self.num_heads, self.head_dim)
        queries = queries.view(b, num_tokens, self.num_heads, self.head_dim)

        # Transpose: (b, num_tokens, num_heads, head_dim) -> (b, num_heads, num_tokens, head_dim)
        keys = keys.transpose(1, 2)
        queries = queries.transpose(1, 2)
        values = values.transpose(1, 2)

        # Compute scaled dot-product attention
        attn_scores = queries @ keys.transpose(2, 3)  # Dot product for each head

        # Apply causal mask
        mask_bool = self.mask.bool()[:num_tokens, :num_tokens]
        attn_scores.masked_fill_(mask_bool, -torch.inf)

        # Softmax and dropout
        attn_weights = torch.softmax(attn_scores / keys.shape[-1]**0.5, dim=-1)
        attn_weights = self.dropout(attn_weights)

        # Compute context vector
        context_vec = (attn_weights @ values).transpose(1, 2)  # (b, num_tokens, num_heads, head_dim)
        context_vec = context_vec.contiguous().view(b, num_tokens, self.d_out)
        context_vec = self.out_proj(context_vec)

        return context_vec


def main():
    """Demonstrate MultiHeadAttention with example."""
    cfg = {
        "emb_dim": 768,
        "context_length": 1024,
        "n_heads": 12,
        "drop_rate": 0.1,
        "qkv_bias": False
    }
    
    attn = MultiHeadAttention(
        d_in=cfg["emb_dim"],
        d_out=cfg["emb_dim"],
        context_length=cfg["context_length"],
        dropout=cfg["drop_rate"],
        num_heads=cfg["n_heads"],
        qkv_bias=cfg["qkv_bias"]
    )
    
    # Example input: batch of 2 sequences, each with 10 tokens
    x = torch.randn(2, 10, 768)
    
    print(f"Input shape: {x.shape}")
    output = attn(x)
    print(f"Output shape: {output.shape}")
    
    # Count parameters
    total_params = sum(p.numel() for p in attn.parameters())
    print(f"Total parameters: {total_params:,}")


if __name__ == "__main__":
    main()
