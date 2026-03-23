#!/usr/bin/env python3
"""Text generation with a trained GPT model.

Generates text by:
    1. Encoding starting text to token indices
    2. Passing through model to get logits
    3. Applying softmax to get probabilities
    4. Selecting token with highest probability
    5. Appending to sequence and repeating
"""

import torch
import argparse
from gpt_model import GPTModel, GPT_CONFIG_124M


def generate_text_simple(model, idx, max_new_tokens, context_size):
    """Generate text using greedy decoding.
    
    Args:
        model: Trained GPTModel
        idx: Initial token indices of shape (batch, n_tokens)
        max_new_tokens: Maximum number of tokens to generate
        context_size: Maximum context length to use
        
    Returns:
        Tensor of shape (batch, n_tokens + max_new_tokens)
    """
    for _ in range(max_new_tokens):
        # Crop current context if it exceeds supported context size
        idx_cond = idx[:, -context_size:]

        # Get predictions
        with torch.no_grad():
            logits = model(idx_cond)

        # Focus only on the last time step
        logits = logits[:, -1, :]  # (batch, vocab_size)

        # Apply softmax to get probabilities
        probas = torch.softmax(logits, dim=-1)

        # Get the index of the vocab entry with highest probability
        idx_next = torch.argmax(probas, dim=-1, keepdim=True)  # (batch, 1)

        # Append sampled index to the running sequence
        idx = torch.cat((idx, idx_next), dim=1)  # (batch, n_tokens+1)

    return idx


def main():
    """Main function with argument parsing."""
    parser = argparse.ArgumentParser(description="Generate text with GPT model")
    parser.add_argument("--prompt", type=str, default="Hello, I am", help="Starting text")
    parser.add_argument("--max-tokens", type=int, default=10, help="Maximum tokens to generate")
    parser.add_argument("--emb-dim", type=int, default=768, help="Embedding dimension")
    parser.add_argument("--n-layers", type=int, default=12, help="Number of layers")
    parser.add_argument("--n-heads", type=int, default=12, help="Number of attention heads")
    parser.add_argument("--vocab-size", type=int, default=50257, help="Vocabulary size")
    parser.add_argument("--context-length", type=int, default=1024, help="Context length")
    
    args = parser.parse_args()
    
    # Create configuration
    cfg = {
        "vocab_size": args.vocab_size,
        "context_length": args.context_length,
        "emb_dim": args.emb_dim,
        "n_heads": args.n_heads,
        "n_layers": args.n_layers,
        "drop_rate": 0.1,
        "qkv_bias": False
    }
    
    # Create model (untrained - will generate random text)
    torch.manual_seed(123)
    model = GPTModel(cfg)
    model.eval()  # Disable dropout
    
    print(f"Model created with {sum(p.numel() for p in model.parameters()):,} parameters")
    print(f"Prompt: {args.prompt}")
    print(f"Max tokens to generate: {args.max_tokens}")
    print("\nNote: This is an UNTRAINED model, so output will be random.")
    print("To generate meaningful text, train the model first.\n")
    
    # For demonstration, use simple token encoding (not a real tokenizer)
    # In practice, you'd use tiktoken or similar
    # Here we just use random tokens for demonstration
    encoded = torch.randint(100, 1000, (1, 5))  # Simulated encoding
    
    print(f"Simulated encoded input: {encoded.tolist()}")
    
    # Generate text
    output = generate_text_simple(
        model=model,
        idx=encoded,
        max_new_tokens=args.max_tokens,
        context_size=cfg["context_length"]
    )
    
    print(f"\nOutput token indices: {output.tolist()}")
    print(f"Output length: {output.shape[1]}")
    print("\nNote: To decode tokens back to text, you need a tokenizer.")
    print("Example: import tiktoken; tokenizer.decode(output[0].tolist())")


if __name__ == "__main__":
    main()
