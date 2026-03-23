#!/usr/bin/env python3
"""Create and save a GPT model with custom configuration.

This script creates a GPT model with the specified configuration and saves
it to a checkpoint file for later use in training or inference.
"""

import torch
import argparse
import json
from gpt_model import GPTModel


def main():
    """Main function with argument parsing."""
    parser = argparse.ArgumentParser(description="Create and save a GPT model")
    parser.add_argument("--vocab-size", type=int, default=50257, help="Vocabulary size")
    parser.add_argument("--context-length", type=int, default=1024, help="Context length")
    parser.add_argument("--emb-dim", type=int, default=768, help="Embedding dimension")
    parser.add_argument("--n-heads", type=int, default=12, help="Number of attention heads")
    parser.add_argument("--n-layers", type=int, default=12, help="Number of transformer layers")
    parser.add_argument("--drop-rate", type=float, default=0.1, help="Dropout rate")
    parser.add_argument("--qkv-bias", action="store_true", default=False, help="Use bias in QKV projections")
    parser.add_argument("--output", type=str, default="gpt_model.pt", help="Output checkpoint path")
    parser.add_argument("--config-output", type=str, default="gpt_config.json", help="Config JSON path")
    parser.add_argument("--seed", type=int, default=123, help="Random seed")
    
    args = parser.parse_args()
    
    # Create configuration
    cfg = {
        "vocab_size": args.vocab_size,
        "context_length": args.context_length,
        "emb_dim": args.emb_dim,
        "n_heads": args.n_heads,
        "n_layers": args.n_layers,
        "drop_rate": args.drop_rate,
        "qkv_bias": args.qkv_bias
    }
    
    print("Creating GPT model with configuration:")
    print(json.dumps(cfg, indent=2))
    
    # Set seed for reproducibility
    torch.manual_seed(args.seed)
    
    # Create model
    model = GPTModel(cfg)
    
    # Count parameters
    total_params = sum(p.numel() for p in model.parameters())
    trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    
    print(f"\nModel created successfully!")
    print(f"Total parameters: {total_params:,}")
    print(f"Trainable parameters: {trainable_params:,}")
    print(f"Model size: {total_params * 4 / 1e6:.2f} MB (float32)")
    
    # Save model
    torch.save({
        "model_state_dict": model.state_dict(),
        "config": cfg,
        "seed": args.seed
    }, args.output)
    
    # Save config
    with open(args.config_output, "w") as f:
        json.dump(cfg, f, indent=2)
    
    print(f"\nModel saved to: {args.output}")
    print(f"Config saved to: {args.config_output}")
    
    # Test forward pass
    print("\nTesting forward pass...")
    batch = torch.randint(0, args.vocab_size, (2, 10))
    with torch.no_grad():
        output = model(batch)
    print(f"Input shape: {batch.shape}")
    print(f"Output shape: {output.shape}")
    print("Forward pass successful!")


if __name__ == "__main__":
    main()
