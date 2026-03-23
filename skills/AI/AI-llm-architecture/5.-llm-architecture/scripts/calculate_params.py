#!/usr/bin/env python3
"""Calculate the number of parameters in a GPT model.

Breaks down parameters by component:
    - Token embeddings: vocab_size * emb_dim
    - Position embeddings: context_length * emb_dim
    - Multi-head attention per block: Q, K, V projections + output projection
    - Feedforward per block: two linear layers
    - Layer normalizations: scale and shift parameters
    - Output projection: emb_dim * vocab_size
"""

import argparse


def calculate_params(cfg):
    """Calculate parameters for a GPT model configuration.
    
    Args:
        cfg: Configuration dict with model hyperparameters
        
    Returns:
        Dict with parameter breakdown by component
    """
    vocab_size = cfg["vocab_size"]
    context_length = cfg["context_length"]
    emb_dim = cfg["emb_dim"]
    n_heads = cfg["n_heads"]
    n_layers = cfg["n_layers"]
    qkv_bias = cfg.get("qkv_bias", False)
    
    # 1. Embedding layers
    token_embedding_params = vocab_size * emb_dim
    position_embedding_params = context_length * emb_dim
    embedding_params = token_embedding_params + position_embedding_params
    
    # 2. Multi-Head Attention per block
    if qkv_bias:
        qkv_params = 3 * (emb_dim * emb_dim + emb_dim)
    else:
        qkv_params = 3 * (emb_dim * emb_dim)
    
    out_proj_params = emb_dim * emb_dim + emb_dim  # Has bias
    mha_params = qkv_params + out_proj_params
    
    # 3. FeedForward per block
    ff_first_layer_params = (emb_dim * 4 * emb_dim) + (4 * emb_dim)
    ff_second_layer_params = (4 * emb_dim * emb_dim) + emb_dim
    ff_params = ff_first_layer_params + ff_second_layer_params
    
    # 4. Layer Normalizations per block (2 per block)
    layer_norm_params_per_block = 2 * (2 * emb_dim)  # scale + shift for each
    
    # 5. Total per transformer block
    params_per_block = mha_params + ff_params + layer_norm_params_per_block
    total_transformer_blocks_params = params_per_block * n_layers
    
    # 6. Final layers
    final_layer_norm_params = 2 * emb_dim
    output_projection_params = emb_dim * vocab_size  # No bias
    
    # 7. Total
    total_params = (
        embedding_params +
        total_transformer_blocks_params +
        final_layer_norm_params +
        output_projection_params
    )
    
    return {
        "token_embeddings": token_embedding_params,
        "position_embeddings": position_embedding_params,
        "embedding_total": embedding_params,
        "mha_per_block": mha_params,
        "ff_per_block": ff_params,
        "layernorm_per_block": layer_norm_params_per_block,
        "params_per_block": params_per_block,
        "transformer_blocks_total": total_transformer_blocks_params,
        "final_layernorm": final_layer_norm_params,
        "output_projection": output_projection_params,
        "total_params": total_params
    }


def print_breakdown(params):
    """Print parameter breakdown in a readable format."""
    print("=" * 60)
    print("PARAMETER BREAKDOWN")
    print("=" * 60)
    
    print("\n1. EMBEDDING LAYERS")
    print(f"   Token embeddings:      {params['token_embeddings']:,}")
    print(f"   Position embeddings:   {params['position_embeddings']:,}")
    print(f"   Subtotal:              {params['embedding_total']:,}")
    
    print("\n2. TRANSFORMER BLOCKS (per block)")
    print(f"   Multi-Head Attention:  {params['mha_per_block']:,}")
    print(f"   FeedForward:           {params['ff_per_block']:,}")
    print(f"   LayerNorm (x2):        {params['layernorm_per_block']:,}")
    print(f"   Subtotal per block:    {params['params_per_block']:,}")
    
    print("\n3. TRANSFORMER BLOCKS (all layers)")
    print(f"   Total:                 {params['transformer_blocks_total']:,}")
    
    print("\n4. FINAL LAYERS")
    print(f"   Final LayerNorm:       {params['final_layernorm']:,}")
    print(f"   Output projection:     {params['output_projection']:,}")
    
    print("\n" + "=" * 60)
    print(f"TOTAL PARAMETERS: {params['total_params']:,}")
    print(f"TOTAL PARAMETERS: {params['total_params'] / 1e6:.2f}M")
    print("=" * 60)


def main():
    """Main function with argument parsing."""
    parser = argparse.ArgumentParser(description="Calculate GPT model parameters")
    parser.add_argument("--vocab-size", type=int, default=50257, help="Vocabulary size")
    parser.add_argument("--context-length", type=int, default=1024, help="Context length")
    parser.add_argument("--emb-dim", type=int, default=768, help="Embedding dimension")
    parser.add_argument("--n-heads", type=int, default=12, help="Number of attention heads")
    parser.add_argument("--n-layers", type=int, default=12, help="Number of transformer layers")
    parser.add_argument("--drop-rate", type=float, default=0.1, help="Dropout rate")
    parser.add_argument("--qkv-bias", action="store_true", default=False, help="Use bias in QKV projections")
    
    args = parser.parse_args()
    
    cfg = {
        "vocab_size": args.vocab_size,
        "context_length": args.context_length,
        "emb_dim": args.emb_dim,
        "n_heads": args.n_heads,
        "n_layers": args.n_layers,
        "drop_rate": args.drop_rate,
        "qkv_bias": args.qkv_bias
    }
    
    print(f"\nConfiguration: {cfg}")
    
    params = calculate_params(cfg)
    print_breakdown(params)


if __name__ == "__main__":
    main()
