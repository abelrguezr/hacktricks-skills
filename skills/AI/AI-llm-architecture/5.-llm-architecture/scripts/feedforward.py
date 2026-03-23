#!/usr/bin/env python3
"""FeedForward neural network for transformer blocks.

A position-wise feedforward network that applies a two-layer fully connected
network to each position separately and identically.

Architecture:
    Linear(emb_dim -> 4*emb_dim) -> GELU -> Linear(4*emb_dim -> emb_dim)
"""

import torch
import torch.nn as nn
from gelu import GELU


class FeedForward(nn.Module):
    """FeedForward network for transformer blocks."""
    
    def __init__(self, cfg):
        """Initialize FeedForward network.
        
        Args:
            cfg: Configuration dict with 'emb_dim' key
        """
        super().__init__()
        self.layers = nn.Sequential(
            nn.Linear(cfg["emb_dim"], 4 * cfg["emb_dim"]),
            GELU(),
            nn.Linear(4 * cfg["emb_dim"], cfg["emb_dim"]),
        )

    def forward(self, x):
        """Forward pass through feedforward network.
        
        Args:
            x: Input tensor of shape (batch_size, seq_len, emb_dim)
            
        Returns:
            Tensor of shape (batch_size, seq_len, emb_dim)
        """
        # x shape: (batch_size, seq_len, emb_dim)
        x = self.layers[0](x)  # shape: (batch_size, seq_len, 4 * emb_dim)
        x = self.layers[1](x)  # shape remains: (batch_size, seq_len, 4 * emb_dim)
        x = self.layers[2](x)  # shape: (batch_size, seq_len, emb_dim)
        return x  # Output shape: (batch_size, seq_len, emb_dim)


def main():
    """Demonstrate FeedForward with example."""
    cfg = {"emb_dim": 768}
    ff = FeedForward(cfg)
    
    # Example input: batch of 2 sequences, each with 5 tokens
    x = torch.randn(2, 5, 768)
    
    print(f"Input shape: {x.shape}")
    output = ff(x)
    print(f"Output shape: {output.shape}")
    
    # Count parameters
    total_params = sum(p.numel() for p in ff.parameters())
    print(f"Total parameters: {total_params:,}")


if __name__ == "__main__":
    main()
