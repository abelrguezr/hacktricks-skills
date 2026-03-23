#!/usr/bin/env python3
"""Transformer Block combining attention, feedforward, and normalization.

A transformer block groups all networks together and applies normalization
and dropouts to improve training stability and results.

Architecture:
    1. First residual path: LayerNorm -> MultiHeadAttention -> Dropout -> Add residual
    2. Second residual path: LayerNorm -> FeedForward -> Dropout -> Add residual

Key features:
    - Residual connections prevent vanishing gradients
    - LayerNorm before attention/feedforward stabilizes training
    - Dropout after each sub-layer prevents overfitting
"""

import torch
import torch.nn as nn
from multihead_attention import MultiHeadAttention
from feedforward import FeedForward
from layernorm import LayerNorm


class TransformerBlock(nn.Module):
    """Single transformer block with attention and feedforward."""
    
    def __init__(self, cfg):
        """Initialize TransformerBlock.
        
        Args:
            cfg: Configuration dict with emb_dim, context_length, n_heads, drop_rate, qkv_bias
        """
        super().__init__()
        self.att = MultiHeadAttention(
            d_in=cfg["emb_dim"],
            d_out=cfg["emb_dim"],
            context_length=cfg["context_length"],
            num_heads=cfg["n_heads"],
            dropout=cfg["drop_rate"],
            qkv_bias=cfg["qkv_bias"]
        )
        self.ff = FeedForward(cfg)
        self.norm1 = LayerNorm(cfg["emb_dim"])
        self.norm2 = LayerNorm(cfg["emb_dim"])
        self.drop_shortcut = nn.Dropout(cfg["drop_rate"])

    def forward(self, x):
        """Forward pass through transformer block.
        
        Args:
            x: Input tensor of shape (batch_size, seq_len, emb_dim)
            
        Returns:
            Tensor of shape (batch_size, seq_len, emb_dim)
        """
        # First residual path: attention
        shortcut = x
        x = self.norm1(x)
        x = self.att(x)
        x = self.drop_shortcut(x)
        x = x + shortcut

        # Second residual path: feedforward
        shortcut = x
        x = self.norm2(x)
        x = self.ff(x)
        x = self.drop_shortcut(x)
        x = x + shortcut

        return x


def main():
    """Demonstrate TransformerBlock with example."""
    cfg = {
        "emb_dim": 768,
        "context_length": 1024,
        "n_heads": 12,
        "n_layers": 12,
        "drop_rate": 0.1,
        "qkv_bias": False
    }
    
    block = TransformerBlock(cfg)
    
    # Example input: batch of 2 sequences, each with 10 tokens
    x = torch.randn(2, 10, 768)
    
    print(f"Input shape: {x.shape}")
    output = block(x)
    print(f"Output shape: {output.shape}")
    
    # Count parameters
    total_params = sum(p.numel() for p in block.parameters())
    print(f"\nTotal parameters per block: {total_params:,}")
    print(f"For {cfg['n_layers']} blocks: {total_params * cfg['n_layers']:,}")


if __name__ == "__main__":
    main()
