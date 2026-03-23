#!/usr/bin/env python3
"""Position interpolation for context window extension.

This script demonstrates position interpolation (PI) for extending
context windows in RoPE-based models with minimal fine-tuning.

Usage:
    python position_interpolation.py --original-ctx 2048 --new-ctx 8192
"""

import argparse
import torch
import torch.nn as nn
from pathlib import Path


def position_interpolation(
    pos_ids: torch.Tensor,
    original_context: int,
    new_context: int
) -> torch.Tensor:
    """Scale position indices for context window extension.
    
    This rescales position indices so longer sequences map into the
    range seen during training, enabling extension with minimal fine-tuning.
    
    Args:
        pos_ids: Original position indices [0, 1, 2, ..., new_context-1]
        original_context: Training context length (e.g., 2048)
        new_context: Target context length (e.g., 8192)
    
    Returns:
        Scaled position indices mapped to [0, original_context-1]
    
    Example:
        >>> pos_ids = torch.arange(8192)
        >>> scaled = position_interpolation(pos_ids, 2048, 8192)
        >>> print(scaled[0], scaled[2047], scaled[4095], scaled[8191])
        tensor(0) tensor(2047) tensor(4095) tensor(8191)  # Wait, this is wrong
        # Actually: tensor(0) tensor(511) tensor(1023) tensor(2047)
    """
    scale = original_context / new_context
    scaled_pos = (pos_ids * scale).long()
    return scaled_pos


def create_rope_embeddings(
    dim: int,
    max_pos: int,
    base: float = 10000.0
) -> tuple[torch.Tensor, torch.Tensor]:
    """Create RoPE frequency tensors.
    
    Args:
        dim: Embedding dimension
        max_pos: Maximum position
        base: Base frequency (default: 10000)
    
    Returns:
        cos, sin tensors for RoPE
    """
    freqs = 1.0 / (base ** (torch.arange(0, dim, 2).float() / dim))
    t = torch.arange(max_pos)
    freqs = torch.outer(t, freqs)
    return torch.cos(freqs), torch.sin(freqs)


def apply_rope(
    x: torch.Tensor,
    cos: torch.Tensor,
    sin: torch.Tensor,
    pos_ids: torch.Tensor
) -> torch.Tensor:
    """Apply RoPE to input tensor.
    
    Args:
        x: Input tensor [batch, seq_len, dim]
        cos: Cosine frequencies [max_pos, dim/2]
        sin: Sine frequencies [max_pos, dim/2]
        pos_ids: Position indices [batch, seq_len]
    
    Returns:
        RoPE-applied tensor [batch, seq_len, dim]
    """
    batch, seq_len, dim = x.shape
    
    # Get frequencies for current positions
    cos_pos = cos[pos_ids].unsqueeze(1)  # [batch, 1, dim/2]
    sin_pos = sin[pos_ids].unsqueeze(1)  # [batch, 1, dim/2]
    
    # Split and rotate
    x1, x2 = x.chunk(2, dim=-1)  # [batch, seq_len, dim/2]
    
    # Apply rotation
    x_rotated = torch.cat([-x2, x1], dim=-1)
    
    # Combine
    return x * cos_pos + x_rotated * sin_pos


def test_position_interpolation(
    original_context: int,
    new_context: int,
    embedding_dim: int = 256
) -> None:
    """Test position interpolation with RoPE.
    
    Args:
        original_context: Original training context length
        new_context: Extended context length
        embedding_dim: Embedding dimension
    """
    print(f"\n=== Position Interpolation Test ===")
    print(f"Original context: {original_context}")
    print(f"New context: {new_context}")
    print(f"Scale factor: {original_context / new_context:.4f}")
    
    # Create position indices
    pos_ids = torch.arange(new_context)
    
    # Apply interpolation
    scaled_pos = position_interpolation(pos_ids, original_context, new_context)
    
    # Show mapping
    print(f"\nPosition mapping (sample):")
    sample_indices = [0, original_context // 4, original_context // 2, 
                      original_context * 3 // 4, original_context - 1,
                      new_context // 2, new_context - 1]
    for idx in sample_indices:
        print(f"  Position {idx:5d} → Scaled {scaled_pos[idx].item():5d}")
    
    # Test with RoPE
    print(f"\nRoPE test:")
    cos, sin = create_rope_embeddings(embedding_dim, original_context)
    
    # Create sample query tensor
    batch_size = 2
    seq_len = min(10, new_context)
    query = torch.randn(batch_size, seq_len, embedding_dim)
    
    # Get positions for this sequence
    seq_pos_ids = torch.arange(seq_len).expand(batch_size, -1)
    scaled_seq_pos = position_interpolation(
        seq_pos_ids.flatten(), original_context, new_context
    ).reshape(batch_size, seq_len)
    
    # Apply RoPE with scaled positions
    query_rope = apply_rope(query, cos, sin, scaled_seq_pos)
    
    print(f"  Query shape: {query.shape}")
    print(f"  RoPE output shape: {query_rope.shape}")
    print(f"  RoPE applied successfully!")


def main():
    parser = argparse.ArgumentParser(
        description="Test position interpolation for context extension"
    )
    parser.add_argument(
        "--original-ctx",
        type=int,
        default=2048,
        help="Original training context length (default: 2048)"
    )
    parser.add_argument(
        "--new-ctx",
        type=int,
        default=8192,
        help="Target context length (default: 8192)"
    )
    parser.add_argument(
        "--embedding-dim",
        type=int,
        default=256,
        help="Embedding dimension (default: 256)"
    )
    
    args = parser.parse_args()
    
    if args.new_context <= args.original_context:
        print("Warning: New context should be larger than original for interpolation")
    
    test_position_interpolation(
        original_context=args.original_context,
        new_context=args.new_context,
        embedding_dim=args.embedding_dim
    )
    
    print("\nDone!")


if __name__ == "__main__":
    main()
