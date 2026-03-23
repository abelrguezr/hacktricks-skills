#!/usr/bin/env python3
"""Layer Normalization for transformer blocks.

Normalizes inputs across features (embedding dimensions) for each individual
example in a batch. Stabilizes training of deep neural networks by reducing
internal covariate shift.

Process:
    1. Compute mean across embedding dimension
    2. Compute variance across embedding dimension
    3. Normalize: (x - mean) / sqrt(var + eps)
    4. Apply learnable scale and shift: scale * norm_x + shift
"""

import torch
import torch.nn as nn


class LayerNorm(nn.Module):
    """Layer Normalization implementation."""
    
    def __init__(self, emb_dim):
        """Initialize LayerNorm.
        
        Args:
            emb_dim: Embedding dimension
        """
        super().__init__()
        self.eps = 1e-5  # Prevent division by zero
        self.scale = nn.Parameter(torch.ones(emb_dim))
        self.shift = nn.Parameter(torch.zeros(emb_dim))

    def forward(self, x):
        """Forward pass through LayerNorm.
        
        Args:
            x: Input tensor of any shape with last dim = emb_dim
            
        Returns:
            Normalized tensor of same shape
        """
        mean = x.mean(dim=-1, keepdim=True)
        var = x.var(dim=-1, keepdim=True, unbiased=False)
        norm_x = (x - mean) / torch.sqrt(var + self.eps)
        return self.scale * norm_x + self.shift


def main():
    """Demonstrate LayerNorm with example."""
    emb_dim = 768
    ln = LayerNorm(emb_dim)
    
    # Example input: batch of 2 sequences, each with 5 tokens
    x = torch.randn(2, 5, emb_dim)
    
    print(f"Input shape: {x.shape}")
    print(f"Input mean (per token): {x.mean(dim=-1).shape}")
    print(f"Input std (per token): {x.std(dim=-1).shape}")
    
    output = ln(x)
    print(f"\nOutput shape: {output.shape}")
    print(f"Output mean (per token): {output.mean(dim=-1).shape}")
    print(f"Output std (per token): {output.std(dim=-1).shape}")
    
    # Count parameters
    total_params = sum(p.numel() for p in ln.parameters())
    print(f"\nTotal parameters: {total_params:,} (scale + shift)")


if __name__ == "__main__":
    main()
