#!/usr/bin/env python3
"""
Verify attention mechanism implementations.

Usage:
    python verify_attention.py --test basic
    python verify_attention.py --test causal
    python verify_attention.py --test multihead
    python verify_attention.py --test all
"""

import argparse
import torch
import torch.nn as nn
import sys


def test_basic_attention():
    """Test basic self-attention implementation."""
    print("\n=== Testing Basic Self-Attention ===")
    
    class SelfAttention(nn.Module):
        def __init__(self, d_in, d_out):
            super().__init__()
            self.W_query = nn.Linear(d_in, d_out)
            self.W_key = nn.Linear(d_in, d_out)
            self.W_value = nn.Linear(d_in, d_out)

        def forward(self, x):
            keys = self.W_key(x)
            queries = self.W_query(x)
            values = self.W_value(x)
            attn_scores = queries @ keys.transpose(-2, -1)
            attn_weights = torch.softmax(attn_scores / keys.shape[-1]**0.5, dim=-1)
            return attn_weights @ values, attn_weights

    torch.manual_seed(42)
    inputs = torch.tensor([
        [0.43, 0.15, 0.89],
        [0.55, 0.87, 0.66],
        [0.57, 0.85, 0.64],
        [0.22, 0.58, 0.33],
        [0.77, 0.25, 0.10],
        [0.05, 0.80, 0.55]
    ])
    
    attn = SelfAttention(d_in=3, d_out=2)
    context, weights = attn(inputs)
    
    # Verify weights sum to 1
    weight_sums = weights.sum(dim=-1)
    all_close = torch.allclose(weight_sums, torch.ones_like(weight_sums), atol=1e-5)
    
    print(f"Input shape: {inputs.shape}")
    print(f"Output shape: {context.shape}")
    print(f"Attention weights shape: {weights.shape}")
    print(f"Weights sum to 1: {all_close}")
    print(f"Weight sums per row: {weight_sums.tolist()}")
    
    if not all_close:
        print("ERROR: Attention weights should sum to 1!")
        return False
    
    print("✓ Basic attention test passed")
    return True


def test_causal_attention():
    """Test causal (masked) attention implementation."""
    print("\n=== Testing Causal Attention ===")
    
    class CausalAttention(nn.Module):
        def __init__(self, d_in, d_out, context_length):
            super().__init__()
            self.W_query = nn.Linear(d_in, d_out)
            self.W_key = nn.Linear(d_in, d_out)
            self.W_value = nn.Linear(d_in, d_out)
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
            attn_scores.masked_fill_(
                self.mask.bool()[:num_tokens, :num_tokens],
                -torch.inf
            )
            attn_weights = torch.softmax(attn_scores / keys.shape[-1]**0.5, dim=-1)
            return attn_weights @ values, attn_weights

    torch.manual_seed(42)
    inputs = torch.tensor([
        [0.43, 0.15, 0.89],
        [0.55, 0.87, 0.66],
        [0.57, 0.85, 0.64],
        [0.22, 0.58, 0.33],
        [0.77, 0.25, 0.10],
        [0.05, 0.80, 0.55]
    ])
    
    attn = CausalAttention(d_in=3, d_out=2, context_length=6)
    context, weights = attn(inputs)
    
    # Check that future positions have zero weight
    # For position 0, only position 0 should have non-zero weight
    # For position 1, positions 0 and 1 should have non-zero weight
    # etc.
    
    print(f"Input shape: {inputs.shape}")
    print(f"Output shape: {context.shape}")
    print(f"Attention weights shape: {weights.shape}")
    
    # Verify causal property: weights[i, j] should be 0 if j > i
    causal_ok = True
    for i in range(weights.shape[0]):
        for j in range(i + 1, weights.shape[1]):
            if weights[i, j] > 1e-6:
                print(f"ERROR: Position {i} attending to future position {j} with weight {weights[i, j].item():.6f}")
                causal_ok = False
    
    if causal_ok:
        print("✓ Causal masking verified: no future token access")
    
    # Also verify weights still sum to 1
    weight_sums = weights.sum(dim=-1)
    all_close = torch.allclose(weight_sums, torch.ones_like(weight_sums), atol=1e-5)
    print(f"Weights sum to 1: {all_close}")
    
    if not all_close:
        print("ERROR: Attention weights should sum to 1!")
        return False
    
    print("✓ Causal attention test passed")
    return True


def test_multihead_attention():
    """Test multi-head attention implementation."""
    print("\n=== Testing Multi-Head Attention ===")
    
    class MultiHeadAttention(nn.Module):
        def __init__(self, d_in, d_out, context_length, num_heads):
            super().__init__()
            assert d_out % num_heads == 0
            self.d_out = d_out
            self.num_heads = num_heads
            self.head_dim = d_out // num_heads
            
            self.W_query = nn.Linear(d_in, d_out)
            self.W_key = nn.Linear(d_in, d_out)
            self.W_value = nn.Linear(d_in, d_out)
            self.out_proj = nn.Linear(d_out, d_out)
            
            self.register_buffer(
                "mask",
                torch.triu(torch.ones(context_length, context_length), diagonal=1)
            )

        def forward(self, x):
            b, num_tokens, d_in = x.shape
            
            keys = self.W_key(x)
            queries = self.W_query(x)
            values = self.W_value(x)

            keys = keys.view(b, num_tokens, self.num_heads, self.head_dim)
            values = values.view(b, num_tokens, self.num_heads, self.head_dim)
            queries = queries.view(b, num_tokens, self.num_heads, self.head_dim)

            keys = keys.transpose(1, 2)
            queries = queries.transpose(1, 2)
            values = values.transpose(1, 2)

            attn_scores = queries @ keys.transpose(-2, -1)
            mask_bool = self.mask.bool()[:num_tokens, :num_tokens]
            attn_scores.masked_fill_(mask_bool, -torch.inf)

            attn_weights = torch.softmax(attn_scores / keys.shape[-1]**0.5, dim=-1)

            context_vec = (attn_weights @ values).transpose(1, 2)
            context_vec = context_vec.contiguous().view(b, num_tokens, self.d_out)
            context_vec = self.out_proj(context_vec)

            return context_vec, attn_weights

    torch.manual_seed(42)
    inputs = torch.tensor([
        [0.43, 0.15, 0.89],
        [0.55, 0.87, 0.66],
        [0.57, 0.85, 0.64],
        [0.22, 0.58, 0.33],
        [0.77, 0.25, 0.10],
        [0.05, 0.80, 0.55]
    ])
    
    attn = MultiHeadAttention(d_in=3, d_out=4, context_length=6, num_heads=2)
    context, weights = attn(inputs)
    
    print(f"Input shape: {inputs.shape}")
    print(f"Output shape: {context.shape}")
    print(f"Attention weights shape: {weights.shape}")
    print(f"Number of heads: {attn.num_heads}")
    print(f"Head dimension: {attn.head_dim}")
    
    # Verify output shape
    expected_shape = (1, 6, 4)  # (batch, seq_len, d_out)
    if context.shape != torch.Size(expected_shape):
        print(f"ERROR: Expected output shape {expected_shape}, got {context.shape}")
        return False
    
    # Verify weights shape
    expected_weights_shape = (1, 2, 6, 6)  # (batch, num_heads, seq_len, seq_len)
    if weights.shape != torch.Size(expected_weights_shape):
        print(f"ERROR: Expected weights shape {expected_weights_shape}, got {weights.shape}")
        return False
    
    # Verify weights sum to 1 per head
    weight_sums = weights.sum(dim=-1)
    all_close = torch.allclose(weight_sums, torch.ones_like(weight_sums), atol=1e-5)
    print(f"Weights sum to 1 per head: {all_close}")
    
    if not all_close:
        print("ERROR: Attention weights should sum to 1!")
        return False
    
    print("✓ Multi-head attention test passed")
    return True


def main():
    parser = argparse.ArgumentParser(description="Verify attention mechanism implementations")
    parser.add_argument(
        "--test",
        choices=["basic", "causal", "multihead", "all"],
        default="all",
        help="Which test to run"
    )
    args = parser.parse_args()
    
    results = []
    
    if args.test in ["basic", "all"]:
        results.append(test_basic_attention())
    
    if args.test in ["causal", "all"]:
        results.append(test_causal_attention())
    
    if args.test in ["multihead", "all"]:
        results.append(test_multihead_attention())
    
    print("\n" + "=" * 50)
    if all(results):
        print("All tests passed! ✓")
        sys.exit(0)
    else:
        print("Some tests failed! ✗")
        sys.exit(1)


if __name__ == "__main__":
    main()
