---
name: llm-pretraining-helper
description: How to train LLMs from scratch using PyTorch, including model architecture setup, data preparation, training loops, loss monitoring, and model saving/loading. Use this skill whenever the user wants to train a language model from scratch, understand pre-training workflows, set up GPT architectures, configure training parameters, monitor loss/perplexity, or load/save model checkpoints. Make sure to use this skill when users mention training LLMs, pre-training, model checkpoints, GPT architectures, training loops, or want to build language models from the ground up.
---

# LLM Pre-training Helper

A skill for training language models from scratch using PyTorch, following best practices from the "LLMs from Scratch" methodology.

## What this skill does

This skill helps you:
- Set up GPT model architectures with proper configuration
- Prepare training data with tokenization and data loaders
- Configure training loops with loss monitoring and evaluation
- Implement text generation with sampling strategies
- Save and load model checkpoints
- Visualize training progress (loss, perplexity)

## When to use this skill

Use this skill when:
- You want to train an LLM from scratch on your own dataset
- You need to understand the pre-training workflow
- You're setting up GPT model configurations
- You want to monitor training metrics (loss, perplexity)
- You need to save/load model checkpoints
- You're implementing text generation with temperature/top-k sampling

## Quick Start

### 1. Set up model configuration

```python
GPT_CONFIG = {
    "vocab_size": 50257,      # GPT-2 vocabulary size
    "context_length": 256,    # Context window (adjust based on data)
    "emb_dim": 768,           # Embedding dimension
    "n_heads": 12,            # Attention heads
    "n_layers": 12,           # Transformer layers
    "drop_rate": 0.1,         # Dropout rate
    "qkv_bias": False         # Query-key-value bias
}
```

### 2. Prepare your data

```python
# Load your text data
text_data = "your training text here"

# Split into train/validation (90/10 is common)
train_ratio = 0.90
split_idx = int(train_ratio * len(text_data))
train_data = text_data[:split_idx]
val_data = text_data[split_idx:]

# Create data loaders
train_loader = create_dataloader_v1(
    train_data,
    batch_size=2,
    max_length=GPT_CONFIG["context_length"],
    stride=GPT_CONFIG["context_length"],
    shuffle=True,
    drop_last=True
)

val_loader = create_dataloader_v1(
    val_data,
    batch_size=2,
    max_length=GPT_CONFIG["context_length"],
    stride=GPT_CONFIG["context_length"],
    shuffle=False,
    drop_last=False
)
```

### 3. Initialize model and start training

```python
import torch

# Set seed for reproducibility
torch.manual_seed(123)

# Initialize model
model = GPTModel(GPT_CONFIG)

# Select device
if torch.cuda.is_available():
    device = torch.device("cuda")
elif torch.backends.mps.is_available():
    device = torch.device("mps")
else:
    device = torch.device("cpu")

model.to(device)

# Setup optimizer
optimizer = torch.optim.AdamW(
    model.parameters(),
    lr=0.0004,
    weight_decay=0.1
)

# Train
num_epochs = 10
train_losses, val_losses, tokens_seen = train_model_simple(
    model, train_loader, val_loader, optimizer, device,
    num_epochs=num_epochs,
    eval_freq=5,           # Evaluate every 5 steps
    eval_iter=5,           # Use 5 batches for evaluation
    start_context="Your starting phrase",
    tokenizer=tokenizer
)
```

## Core Components

### Model Architecture

The GPT model consists of:
- **Token embeddings**: Convert token IDs to vectors
- **Positional embeddings**: Add position information
- **Transformer blocks**: Multi-head attention + feed-forward
- **Output head**: Maps embeddings back to vocabulary

### Training Loop Structure

```
For each epoch:
  For each batch:
    1. Zero gradients
    2. Forward pass → get logits
    3. Calculate loss (cross-entropy)
    4. Backward pass → compute gradients
    5. Optimizer step → update weights
    6. (Optional) Evaluate and log metrics
```

### Loss Functions

- **Cross-entropy loss**: Measures difference between predicted and actual token distributions
- **Perplexity**: `exp(loss)` - represents model uncertainty (lower is better)

### Text Generation Strategies

| Strategy | Description | Use Case |
|----------|-------------|----------|
| Greedy | Always pick highest probability token | Deterministic output |
| Top-k | Sample from top k tokens | Balanced diversity |
| Temperature | Scale logits before softmax | Control randomness |
| Top-p (nucleus) | Sample until cumulative probability threshold | Adaptive diversity |

## Training Parameters Guide

### Learning Rate
- **Small (1e-5 to 1e-4)**: Precise convergence, slower training
- **Large (1e-3 to 1e-2)**: Faster training, risk of overshooting
- **Recommended**: Start with 4e-4 for AdamW

### Batch Size
- **Small (1-4)**: More frequent updates, noisier gradients
- **Large (8-32)**: Smoother gradients, more memory
- **Recommended**: 2-4 for CPU, 8-16 for GPU

### Context Length
- **Short (128-256)**: Faster training, less context
- **Long (512-1024)**: More context, slower training
- **Recommended**: Match your use case, start with 256

### Number of Epochs
- **Few (5-10)**: Quick iteration, may underfit
- **Many (20-50)**: Better convergence, risk of overfitting
- **Recommended**: Monitor validation loss, stop when it plateaus

## Monitoring Training

### Key Metrics to Track

1. **Training Loss**: Should decrease over time
2. **Validation Loss**: Should decrease, watch for overfitting
3. **Perplexity**: `exp(loss)`, lower is better
4. **Tokens Seen**: Track progress through dataset

### Signs of Good Training
- Training loss steadily decreases
- Validation loss follows training loss
- Generated text becomes more coherent
- Perplexity drops significantly

### Signs of Problems
- **Overfitting**: Training loss ↓, Validation loss ↑
- **Underfitting**: Both losses stay high
- **Exploding gradients**: Loss becomes NaN or inf
- **Vanishing gradients**: Loss stops decreasing

## Saving and Loading Models

### Save Full Checkpoint (for resuming training)

```python
torch.save({
    "model_state_dict": model.state_dict(),
    "optimizer_state_dict": optimizer.state_dict(),
    "epoch": current_epoch,
    "loss": current_loss
}, "checkpoint.pth")
```

### Load Full Checkpoint

```python
checkpoint = torch.load("checkpoint.pth", map_location=device)
model.load_state_dict(checkpoint["model_state_dict"])
optimizer.load_state_dict(checkpoint["optimizer_state_dict"])
model.train()
```

### Save Model Only (for inference)

```python
torch.save(model.state_dict(), "model.pth")
```

### Load Model Only

```python
model = GPTModel(GPT_CONFIG)
model.load_state_dict(torch.load("model.pth", map_location=device))
model.eval()
```

## Common Issues and Solutions

### "Not enough tokens for training"
- **Solution**: Reduce `context_length` or increase training data
- **Check**: `total_tokens * train_ratio >= context_length`

### "CUDA out of memory"
- **Solution**: Reduce batch size or context length
- **Alternative**: Use gradient accumulation

### "Loss not decreasing"
- **Check**: Learning rate (try 1e-4 to 1e-3)
- **Check**: Data quality and tokenization
- **Check**: Model is in training mode (`model.train()`)

### "Validation loss increasing"
- **Solution**: Early stopping, reduce epochs
- **Alternative**: Add regularization (dropout, weight decay)

## Advanced Techniques (Not in Base Code)

### Learning Rate Scheduling
- **Linear Warmup**: Start small, increase to max LR
- **Cosine Decay**: Gradually reduce LR after warmup

### Gradient Clipping
- Prevents exploding gradients
- Set `max_norm` in optimizer or use `torch.nn.utils.clip_grad_norm_`

### Top-p Sampling (Nucleus)
- More adaptive than top-k
- Sums probabilities until threshold (e.g., 0.9)

### Beam Search
- Explores multiple sequences simultaneously
- Better quality than greedy, more expensive

## Next Steps

After training:
1. **Evaluate**: Test on held-out data
2. **Fine-tune**: Adapt to specific tasks
3. **Deploy**: Use for inference or as base model
4. **Iterate**: Adjust hyperparameters and retrain

## References

- [LLMs from Scratch](https://www.manning.com/books/build-a-large-language-model-from-scratch)
- [rasbt/LLMs-from-scratch](https://github.com/rasbt/LLMs-from-scratch)
- [GPT-2 Architecture](https://d4mucfpksywv.cloudfront.net/better-language-models/language-models.pdf)
