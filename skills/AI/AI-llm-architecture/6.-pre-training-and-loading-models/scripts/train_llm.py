#!/usr/bin/env python3
"""
Train an LLM from scratch using PyTorch.

Usage:
    python train_llm.py --data <path_to_text_file> --epochs <num_epochs>
    python train_llm.py --data data.txt --epochs 10 --batch_size 4 --lr 0.0004
"""

import argparse
import os
import time
import math
import torch
import torch.nn as nn
import tiktoken
from torch.utils.data import Dataset, DataLoader
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator


# ============================================================================
# Dataset and DataLoader
# ============================================================================

class GPTDatasetV1(Dataset):
    """Dataset for GPT training with sliding window tokenization."""
    
    def __init__(self, txt, tokenizer, max_length, stride):
        self.input_ids = []
        self.target_ids = []
        
        # Tokenize the entire text
        token_ids = tokenizer.encode(txt, allowed_special={"<|endoftext|>"})
        
        # Use sliding window to create overlapping sequences
        for i in range(0, len(token_ids) - max_length, stride):
            input_chunk = token_ids[i:i + max_length]
            target_chunk = token_ids[i + 1: i + max_length + 1]
            self.input_ids.append(torch.tensor(input_chunk))
            self.target_ids.append(torch.tensor(target_chunk))
    
    def __len__(self):
        return len(self.input_ids)
    
    def __getitem__(self, idx):
        return self.input_ids[idx], self.target_ids[idx]


def create_dataloader_v1(txt, batch_size=4, max_length=256,
                         stride=128, shuffle=True, drop_last=True, num_workers=0):
    """Create a DataLoader for GPT training."""
    tokenizer = tiktoken.get_encoding("gpt2")
    dataset = GPTDatasetV1(txt, tokenizer, max_length, stride)
    
    dataloader = DataLoader(
        dataset,
        batch_size=batch_size,
        shuffle=shuffle,
        drop_last=drop_last,
        num_workers=num_workers
    )
    return dataloader


# ============================================================================
# Model Components
# ============================================================================

class MultiHeadAttention(nn.Module):
    """Multi-head self-attention mechanism."""
    
    def __init__(self, d_in, d_out, context_length, dropout, num_heads, qkv_bias=False):
        super().__init__()
        assert d_out % num_heads == 0, "d_out must be divisible by n_heads"
        
        self.d_out = d_out
        self.num_heads = num_heads
        self.head_dim = d_out // num_heads
        
        self.W_query = nn.Linear(d_in, d_out, bias=qkv_bias)
        self.W_key = nn.Linear(d_in, d_out, bias=qkv_bias)
        self.W_value = nn.Linear(d_in, d_out, bias=qkv_bias)
        self.out_proj = nn.Linear(d_out, d_out)
        self.dropout = nn.Dropout(dropout)
        self.register_buffer('mask', torch.triu(torch.ones(context_length, context_length), diagonal=1))
    
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
        
        attn_scores = queries @ keys.transpose(2, 3)
        mask_bool = self.mask.bool()[:num_tokens, :num_tokens]
        attn_scores.masked_fill_(mask_bool, -torch.inf)
        
        attn_weights = torch.softmax(attn_scores / keys.shape[-1]**0.5, dim=-1)
        attn_weights = self.dropout(attn_weights)
        
        context_vec = (attn_weights @ values).transpose(1, 2)
        context_vec = context_vec.reshape(b, num_tokens, self.d_out)
        context_vec = self.out_proj(context_vec)
        
        return context_vec


class LayerNorm(nn.Module):
    """Layer normalization."""
    
    def __init__(self, emb_dim):
        super().__init__()
        self.eps = 1e-5
        self.scale = nn.Parameter(torch.ones(emb_dim))
        self.shift = nn.Parameter(torch.zeros(emb_dim))
    
    def forward(self, x):
        mean = x.mean(dim=-1, keepdim=True)
        var = x.var(dim=-1, keepdim=True, unbiased=False)
        norm_x = (x - mean) / torch.sqrt(var + self.eps)
        return self.scale * norm_x + self.shift


class GELU(nn.Module):
    """GELU activation function."""
    
    def __init__(self):
        super().__init__()
    
    def forward(self, x):
        return 0.5 * x * (1 + torch.tanh(
            torch.sqrt(torch.tensor(2.0 / torch.pi)) *
            (x + 0.044715 * torch.pow(x, 3))
        ))


class FeedForward(nn.Module):
    """Feed-forward network."""
    
    def __init__(self, cfg):
        super().__init__()
        self.layers = nn.Sequential(
            nn.Linear(cfg["emb_dim"], 4 * cfg["emb_dim"]),
            GELU(),
            nn.Linear(4 * cfg["emb_dim"], cfg["emb_dim"]),
        )
    
    def forward(self, x):
        return self.layers(x)


class TransformerBlock(nn.Module):
    """Single transformer block with attention and feed-forward."""
    
    def __init__(self, cfg):
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
        shortcut = x
        x = self.norm1(x)
        x = self.att(x)
        x = self.drop_shortcut(x)
        x = x + shortcut
        
        shortcut = x
        x = self.norm2(x)
        x = self.ff(x)
        x = self.drop_shortcut(x)
        x = x + shortcut
        
        return x


class GPTModel(nn.Module):
    """GPT model for language modeling."""
    
    def __init__(self, cfg):
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
        batch_size, seq_len = in_idx.shape
        tok_embeds = self.tok_emb(in_idx)
        pos_embeds = self.pos_emb(torch.arange(seq_len, device=in_idx.device))
        x = tok_embeds + pos_embeds
        x = self.drop_emb(x)
        x = self.trf_blocks(x)
        x = self.final_norm(x)
        logits = self.out_head(x)
        return logits


# ============================================================================
# Utility Functions
# ============================================================================

def text_to_token_ids(text, tokenizer):
    """Convert text to token IDs tensor."""
    encoded = tokenizer.encode(text, allowed_special={"<|endoftext|>"})
    encoded_tensor = torch.tensor(encoded).unsqueeze(0)
    return encoded_tensor


def token_ids_to_text(token_ids, tokenizer):
    """Convert token IDs tensor to text."""
    flat = token_ids.squeeze(0)
    return tokenizer.decode(flat.tolist())


def generate_text(model, idx, max_new_tokens, context_size, temperature=0.0, top_k=None):
    """Generate text with optional sampling strategies."""
    for _ in range(max_new_tokens):
        idx_cond = idx[:, -context_size:]
        with torch.no_grad():
            logits = model(idx_cond)
        logits = logits[:, -1, :]
        
        if top_k is not None:
            top_logits, _ = torch.topk(logits, top_k)
            min_val = top_logits[:, -1]
            logits = torch.where(
                logits < min_val,
                torch.tensor(float("-inf")).to(logits.device),
                logits
            )
        
        if temperature > 0.0:
            logits = logits / temperature
            probs = torch.softmax(logits, dim=-1)
            idx_next = torch.multinomial(probs, num_samples=1)
        else:
            idx_next = torch.argmax(logits, dim=-1, keepdim=True)
        
        idx = torch.cat((idx, idx_next), dim=1)
    
    return idx


def calc_loss_batch(input_batch, target_batch, model, device):
    """Calculate cross-entropy loss for a single batch."""
    input_batch, target_batch = input_batch.to(device), target_batch.to(device)
    logits = model(input_batch)
    loss = torch.nn.functional.cross_entropy(
        logits.flatten(0, 1),
        target_batch.flatten()
    )
    return loss


def calc_loss_loader(data_loader, model, device, num_batches=None):
    """Calculate average loss over a data loader."""
    total_loss = 0.
    if len(data_loader) == 0:
        return float("nan")
    elif num_batches is None:
        num_batches = len(data_loader)
    else:
        num_batches = min(num_batches, len(data_loader))
    
    for i, (input_batch, target_batch) in enumerate(data_loader):
        if i < num_batches:
            loss = calc_loss_batch(input_batch, target_batch, model, device)
            total_loss += loss.item()
        else:
            break
    
    return total_loss / num_batches


def evaluate_model(model, train_loader, val_loader, device, eval_iter):
    """Evaluate model on train and validation sets."""
    model.eval()
    with torch.no_grad():
        train_loss = calc_loss_loader(train_loader, model, device, num_batches=eval_iter)
        val_loss = calc_loss_loader(val_loader, model, device, num_batches=eval_iter)
    model.train()
    return train_loss, val_loss


def generate_and_print_sample(model, tokenizer, device, start_context):
    """Generate and print a sample from the model."""
    model.eval()
    context_size = model.pos_emb.weight.shape[0]
    encoded = text_to_token_ids(start_context, tokenizer).to(device)
    
    with torch.no_grad():
        token_ids = generate_text(
            model=model,
            idx=encoded,
            max_new_tokens=50,
            context_size=context_size
        )
    
    decoded_text = token_ids_to_text(token_ids, tokenizer)
    print(f"\nGenerated sample: {decoded_text.replace(chr(10), ' ')}")
    model.train()


def train_model_simple(model, train_loader, val_loader, optimizer, device,
                       num_epochs, eval_freq, eval_iter, start_context, tokenizer):
    """Main training loop."""
    train_losses, val_losses, track_tokens_seen = [], [], []
    tokens_seen, global_step = 0, -1
    
    for epoch in range(num_epochs):
        model.train()
        
        for input_batch, target_batch in train_loader:
            optimizer.zero_grad()
            loss = calc_loss_batch(input_batch, target_batch, model, device)
            loss.backward()
            optimizer.step()
            
            tokens_seen += input_batch.numel()
            global_step += 1
            
            if global_step % eval_freq == 0:
                train_loss, val_loss = evaluate_model(
                    model, train_loader, val_loader, device, eval_iter
                )
                train_losses.append(train_loss)
                val_losses.append(val_loss)
                track_tokens_seen.append(tokens_seen)
                print(f"Ep {epoch+1} (Step {global_step:06d}): "
                      f"Train loss {train_loss:.3f}, Val loss {val_loss:.3f}")
        
        generate_and_print_sample(model, tokenizer, device, start_context)
    
    return train_losses, val_losses, track_tokens_seen


def plot_losses(epochs_seen, tokens_seen, train_losses, val_losses, output_dir="."):
    """Plot training and validation losses."""
    fig, ax1 = plt.subplots(figsize=(10, 5))
    ax1.plot(epochs_seen, train_losses, label="Training loss")
    ax1.plot(epochs_seen, val_losses, linestyle="-.", label="Validation loss")
    ax1.set_xlabel("Epochs")
    ax1.set_ylabel("Loss")
    ax1.legend(loc="upper right")
    ax1.xaxis.set_major_locator(MaxNLocator(integer=True))
    
    ax2 = ax1.twiny()
    ax2.plot(tokens_seen, train_losses, alpha=0)
    ax2.set_xlabel("Tokens seen")
    fig.tight_layout()
    
    loss_plot_path = os.path.join(output_dir, "training_loss.png")
    plt.savefig(loss_plot_path)
    print(f"Saved loss plot to {loss_plot_path}")
    plt.close()
    
    # Plot perplexity
    train_ppls = [math.exp(loss) for loss in train_losses]
    val_ppls = [math.exp(loss) for loss in val_losses]
    
    plt.figure(figsize=(10, 5))
    plt.plot(tokens_seen, train_ppls, label='Training Perplexity')
    plt.plot(tokens_seen, val_ppls, label='Validation Perplexity')
    plt.xlabel('Tokens Seen')
    plt.ylabel('Perplexity')
    plt.title('Perplexity over Training')
    plt.legend()
    
    ppl_plot_path = os.path.join(output_dir, "perplexity.png")
    plt.savefig(ppl_plot_path)
    print(f"Saved perplexity plot to {ppl_plot_path}")
    plt.close()


# ============================================================================
# Main Training Script
# ============================================================================

def main():
    parser = argparse.ArgumentParser(description="Train an LLM from scratch")
    parser.add_argument("--data", type=str, required=True, help="Path to training text file")
    parser.add_argument("--epochs", type=int, default=10, help="Number of training epochs")
    parser.add_argument("--batch_size", type=int, default=2, help="Batch size")
    parser.add_argument("--lr", type=float, default=0.0004, help="Learning rate")
    parser.add_argument("--context_length", type=int, default=256, help="Context length")
    parser.add_argument("--output_dir", type=str, default=".", help="Output directory")
    parser.add_argument("--start_context", type=str, default="The", help="Starting context for generation")
    parser.add_argument("--resume", type=str, default=None, help="Path to checkpoint to resume from")
    
    args = parser.parse_args()
    
    # Create output directory
    os.makedirs(args.output_dir, exist_ok=True)
    
    # Load data
    print(f"Loading data from {args.data}")
    with open(args.data, "r", encoding="utf-8") as f:
        text_data = f.read()
    
    total_characters = len(text_data)
    tokenizer = tiktoken.get_encoding("gpt2")
    total_tokens = len(tokenizer.encode(text_data))
    
    print(f"Characters: {total_characters}")
    print(f"Tokens: {total_tokens}")
    
    # Model configuration
    GPT_CONFIG = {
        "vocab_size": 50257,
        "context_length": args.context_length,
        "emb_dim": 768,
        "n_heads": 12,
        "n_layers": 12,
        "drop_rate": 0.1,
        "qkv_bias": False
    }
    
    # Sanity checks
    train_ratio = 0.90
    if total_tokens * train_ratio < GPT_CONFIG["context_length"]:
        print("WARNING: Not enough tokens for training. Consider reducing context_length.")
    
    # Split data
    split_idx = int(train_ratio * len(text_data))
    train_data = text_data[:split_idx]
    val_data = text_data[split_idx:]
    
    # Create data loaders
    torch.manual_seed(123)
    train_loader = create_dataloader_v1(
        train_data,
        batch_size=args.batch_size,
        max_length=GPT_CONFIG["context_length"],
        stride=GPT_CONFIG["context_length"],
        shuffle=True,
        drop_last=True
    )
    
    val_loader = create_dataloader_v1(
        val_data,
        batch_size=args.batch_size,
        max_length=GPT_CONFIG["context_length"],
        stride=GPT_CONFIG["context_length"],
        shuffle=False,
        drop_last=False
    )
    
    print(f"Train loader batches: {len(train_loader)}")
    print(f"Val loader batches: {len(val_loader)}")
    
    # Select device
    if torch.cuda.is_available():
        device = torch.device("cuda")
    elif torch.backends.mps.is_available():
        device = torch.device("mps")
    else:
        device = torch.device("cpu")
    
    print(f"Using {device} device.")
    
    # Initialize model
    torch.manual_seed(123)
    model = GPTModel(GPT_CONFIG)
    model.to(device)
    
    # Resume from checkpoint if provided
    start_epoch = 0
    if args.resume:
        print(f"Resuming from {args.resume}")
        checkpoint = torch.load(args.resume, map_location=device)
        model.load_state_dict(checkpoint["model_state_dict"])
        start_epoch = checkpoint.get("epoch", 0) + 1
    
    # Setup optimizer
    optimizer = torch.optim.AdamW(
        model.parameters(),
        lr=args.lr,
        weight_decay=0.1
    )
    
    # Calculate initial loss
    with torch.no_grad():
        initial_train_loss = calc_loss_loader(train_loader, model, device)
        initial_val_loss = calc_loss_loader(val_loader, model, device)
    
    print(f"Initial Train Loss: {initial_train_loss:.3f}")
    print(f"Initial Val Loss: {initial_val_loss:.3f}")
    
    # Start training
    print(f"\nStarting training for {args.epochs} epochs...")
    start_time = time.time()
    
    train_losses, val_losses, tokens_seen = train_model_simple(
        model, train_loader, val_loader, optimizer, device,
        num_epochs=args.epochs,
        eval_freq=5,
        eval_iter=5,
        start_context=args.start_context,
        tokenizer=tokenizer
    )
    
    end_time = time.time()
    execution_time_minutes = (end_time - start_time) / 60
    print(f"\nTraining completed in {execution_time_minutes:.2f} minutes.")
    
    # Plot results
    epochs_tensor = torch.linspace(0, args.epochs, len(train_losses))
    plot_losses(epochs_tensor, tokens_seen, train_losses, val_losses, args.output_dir)
    
    # Save model
    checkpoint_path = os.path.join(args.output_dir, "checkpoint.pth")
    torch.save({
        "model_state_dict": model.state_dict(),
        "optimizer_state_dict": optimizer.state_dict(),
        "epoch": args.epochs,
        "loss": train_losses[-1] if train_losses else None
    }, checkpoint_path)
    print(f"Saved checkpoint to {checkpoint_path}")
    
    # Save model only
    model_path = os.path.join(args.output_dir, "model.pth")
    torch.save(model.state_dict(), model_path)
    print(f"Saved model to {model_path}")


if __name__ == "__main__":
    main()
