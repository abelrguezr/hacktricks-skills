#!/usr/bin/env python3
"""GPTModel - Complete GPT architecture for language modeling.

The GPTModel class combines all components to predict the next token in a sequence.
This is the fundamental architecture for tasks like text generation.

Components:
    - Token embeddings: Convert token indices to dense vectors
    - Positional embeddings: Add position information
    - Transformer blocks: Stack of n_layers transformer blocks
    - Final normalization: LayerNorm before output
    - Output head: Linear projection to vocabulary size
"""

import torch
import torch.nn as nn
from transformer_block import TransformerBlock
from layernorm import LayerNorm


class GPTModel(nn.Module):
    """Complete GPT model for next-token prediction."""
    
    def __init__(self, cfg):
        """Initialize GPTModel.
        
        Args:
            cfg: Configuration dict with vocab_size, context_length, emb_dim,
                 n_heads, n_layers, drop_rate, qkv_bias
        """
        super().__init__()
        self.tok_emb = nn.Embedding(cfg["vocab_size"], cfg["emb_dim"])
        self.pos_emb = nn.Embedding(cfg["context_length"], cfg["emb_dim"])
        self.drop_emb = nn.Dropout(cfg["drop_rate"])

        self.trf_blocks = nn.Sequential(
            *[TransformerBlock(cfg) for _ in range(cfg["n_layers"])]
        )

        self.final_norm = LayerNorm(cfg["emb_dim"])
        self.out_head = nn.Linear(cfg["emb_dim"], cfg["vocab_size"], bias=False)

    def forward(self, in_idx):
        """Forward pass through GPT model.
        
        Args:
            in_idx: Input token indices of shape (batch_size, seq_len)
            
        Returns:
            Logits of shape (batch_size, seq_len, vocab_size)
        """
        batch_size, seq_len = in_idx.shape

        # Token embeddings
        tok_embeds = self.tok_emb(in_idx)  # (batch_size, seq_len, emb_dim)

        # Positional embeddings
        pos_embeds = self.pos_emb(torch.arange(seq_len, device=in_idx.device))  # (seq_len, emb_dim)

        # Combine embeddings
        x = tok_embeds + pos_embeds  # Broadcasting over batch dimension
        x = self.drop_emb(x)

        # Transformer blocks
        x = self.trf_blocks(x)

        # Final normalization and output
        x = self.final_norm(x)
        logits = self.out_head(x)  # (batch_size, seq_len, vocab_size)

        return logits


# Standard 124M parameter configuration
GPT_CONFIG_124M = {
    "vocab_size": 50257,
    "context_length": 1024,
    "emb_dim": 768,
    "n_heads": 12,
    "n_layers": 12,
    "drop_rate": 0.1,
    "qkv_bias": False
}


def main():
    """Demonstrate GPTModel with example."""
    torch.manual_seed(123)
    
    model = GPTModel(GPT_CONFIG_124M)
    
    # Example input: batch of 2 sequences, each with 5 tokens
    batch = torch.randint(0, 1000, (2, 5))  # Random token indices
    
    print(f"Input batch shape: {batch.shape}")
    print(f"Input batch:\n{batch}")
    
    out = model(batch)
    print(f"\nOutput shape: {out.shape}")
    print(f"Output (logits for first sequence, first token, first 10 vocab entries):")
    print(out[0, 0, :10].detach().tolist())
    
    # Count parameters
    total_params = sum(p.numel() for p in model.parameters())
    print(f"\nTotal parameters: {total_params:,}")


if __name__ == "__main__":
    main()
