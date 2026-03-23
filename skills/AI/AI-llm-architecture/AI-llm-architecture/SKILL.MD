---
name: llm-training-guide
description: Guide for building and training large language models from scratch. Use this skill whenever the user wants to understand LLM training concepts, implement tokenization, data sampling, embeddings, attention mechanisms, model architecture, pre-training, or fine-tuning workflows. Trigger on mentions of LLM training, building models from scratch, tokenization, embeddings, attention, pre-training, fine-tuning, LoRA, or any LLM development task.
---

# LLM Training Guide

A comprehensive guide for building and training large language models from scratch, based on the Manning book "Build a Large Language Model from Scratch".

## Overview

This skill covers the complete LLM training pipeline:

1. **Tokenization** - Converting text to token IDs
2. **Data Sampling** - Preparing training data
3. **Token Embeddings** - Vector representations
4. **Attention Mechanisms** - Capturing word relationships
5. **LLM Architecture** - Full model structure
6. **Pre-training** - Training from scratch
7. **Fine-tuning** - Adapting for specific tasks

## Phase 1: Tokenization

**Goal**: Divide input text into tokens (IDs) in a meaningful way.

### Key Concepts

- **Tokens**: The basic units the model processes (can be characters, words, or subwords)
- **Vocabulary**: The set of all unique tokens
- **Token IDs**: Numeric identifiers for each token in the vocabulary

### Implementation Steps

1. **Build vocabulary** from your training corpus
2. **Create token-to-ID mapping** (tokenizer)
3. **Create ID-to-token mapping** (for decoding)
4. **Encode text** → convert to token IDs
5. **Decode IDs** → convert back to text

### Best Practices

- Use subword tokenization (like BPE or WordPiece) for better coverage
- Include special tokens: `<pad>`, `<unk>`, `<bos>`, `<eos>`
- Keep vocabulary size reasonable (typically 50K-100K tokens)
- Consider your domain when building vocabulary

## Phase 2: Data Sampling

**Goal**: Sample input data and prepare it for training by separating into sequences of specific length and generating expected responses.

### Key Concepts

- **Sequence length**: Fixed number of tokens per training example
- **Context window**: How much history the model sees
- **Target generation**: What the model should predict (next token)

### Implementation Steps

1. **Load and concatenate** all training text
2. **Tokenize** the entire corpus
3. **Split into sequences** of fixed length (e.g., 1024 tokens)
4. **Create input/target pairs**:
   - Input: tokens [0, 1, 2, ..., n-1]
   - Target: tokens [1, 2, 3, ..., n]
5. **Batch sequences** for efficient training

### Best Practices

- Use sequence lengths that fit your GPU memory
- Shuffle sequences between epochs
- Consider overlapping sequences for more training data
- Balance dataset across domains if using mixed data

## Phase 3: Token Embeddings

**Goal**: Assign each token a vector representation of desired dimensions. Each word becomes a point in X-dimensional space.

### Key Concepts

- **Embedding dimension**: Size of the vector (e.g., 512, 1024, 4096)
- **Learnable parameters**: Embeddings are initialized randomly and trained
- **Position embeddings**: Additional vectors encoding word position

### Implementation Steps

1. **Initialize token embeddings** randomly (vocab_size × embedding_dim)
2. **Initialize position embeddings** randomly (max_seq_len × embedding_dim)
3. **Combine embeddings**: token_embedding + position_embedding
4. **Train embeddings** alongside model parameters

### Position Embedding Types

- **Absolute**: Fixed position encoding (simple, effective)
- **Relative**: Encodes distance between tokens
- **Rotary**: Rotates embeddings based on position (RoPE)

### Best Practices

- Embedding dimension should match model hidden size
- Use learned embeddings rather than fixed ones
- Consider sinusoidal position embeddings for extrapolation

## Phase 4: Attention Mechanisms

**Goal**: Apply attention layers to capture relationships between words in the sentence.

### Key Concepts

- **Self-attention**: Each token attends to all tokens in the sequence
- **Query, Key, Value**: Three projections for attention computation
- **Multi-head attention**: Multiple attention heads in parallel
- **Causal masking**: Prevents attending to future tokens (for training)

### Implementation Steps

1. **Project embeddings** to Q, K, V matrices
2. **Compute attention scores**: Q × K^T / sqrt(d_k)
3. **Apply causal mask** (for decoder-only models)
4. **Softmax** to get attention weights
5. **Weighted sum**: attention_weights × V
6. **Combine heads** and project back

### Attention Formula

```
Attention(Q, K, V) = softmax(QK^T / sqrt(d_k))V
```

### Best Practices

- Use multi-head attention (8-16 heads typical)
- Apply layer normalization before and after attention
- Use residual connections around attention blocks
- Consider flash attention for efficiency

## Phase 5: LLM Architecture

**Goal**: Develop the full LLM architecture by combining all components.

### Standard Transformer Decoder Architecture

```
Input → Token Embedding → Position Embedding → [N × (Attention → MLP)] → Output Projection → Logits
```

### Components

1. **Embedding Layer**: Token + Position embeddings
2. **N Transformer Blocks**:
   - Multi-head self-attention
   - Layer normalization
   - Feed-forward MLP (2-4x hidden size)
   - Layer normalization
3. **Output Projection**: Hidden size → vocabulary size
4. **Loss Function**: Cross-entropy on next token prediction

### Implementation Steps

1. **Define model class** with all layers
2. **Implement forward pass** through all components
3. **Implement training loop** with loss computation
4. **Implement generation** (sampling, beam search, etc.)
5. **Add saving/loading** for model checkpoints

### Best Practices

- Use pre-norm architecture (norm before attention/MLP)
- Initialize weights carefully (e.g., Xavier, He initialization)
- Use gradient clipping to prevent exploding gradients
- Implement mixed precision training for efficiency

## Phase 6: Pre-training

**Goal**: Train the model from scratch using the defined architecture, loss functions, and optimizer.

### Training Loop

```python
for epoch in epochs:
    for batch in dataloader:
        # Forward pass
        logits = model(input_tokens)
        
        # Compute loss
        loss = cross_entropy(logits, target_tokens)
        
        # Backward pass
        loss.backward()
        
        # Update weights
        optimizer.step()
        optimizer.zero_grad()
```

### Key Hyperparameters

- **Learning rate**: 1e-4 to 3e-4 (with warmup)
- **Batch size**: Depends on GPU memory (effective batch size 1024-4096)
- **Optimizer**: AdamW with weight decay (0.01-0.1)
- **Learning rate schedule**: Cosine decay or linear warmup + decay
- **Gradient accumulation**: For larger effective batch sizes

### Best Practices

- Use learning rate warmup (first 10% of steps)
- Monitor training loss and perplexity
- Save checkpoints regularly
- Use gradient checkpointing for memory efficiency
- Consider distributed training for large models

## Phase 7: Fine-tuning

### 7.0 LoRA (Low-Rank Adaptation)

**Goal**: Reduce computation needed for fine-tuning by training only small adapter matrices.

### How LoRA Works

- Freeze pre-trained weights
- Add small rank-r matrices to attention layers
- Train only the LoRA parameters
- Merge LoRA weights with base model for inference

### Implementation Steps

1. **Freeze base model** parameters
2. **Add LoRA adapters** to attention Q, V, (optionally K, O)
3. **Train only LoRA parameters**
4. **Merge weights** for deployment

### Best Practices

- Rank r: 8-64 (higher for more capacity)
- Alpha: Scaling factor (typically 2× rank)
- Apply to attention layers primarily
- Use lower learning rate than pre-training

### 7.1 Fine-tuning for Classification

**Goal**: Adapt pre-trained model to classify text into categories.

### Implementation Steps

1. **Load pre-trained model** (frozen or partially unfrozen)
2. **Add classification head** on top of embeddings
3. **Prepare labeled dataset** with categories
4. **Train with cross-entropy loss** on labels
5. **Evaluate** with accuracy, F1, etc.

### Best Practices

- Use mean pooling or [CLS] token for classification
- Fine-tune last 1-2 layers initially
- Use smaller learning rate than pre-training
- Consider few-shot learning for limited data

### 7.2 Fine-tuning for Instruction Following

**Goal**: Adapt pre-trained model to follow instructions (chat, tasks, etc.).

### Implementation Steps

1. **Prepare instruction dataset** (instruction, input, output format)
2. **Format examples** with special tokens:
   ```
   <instruction> {instruction} <input> {input} <output> {output}
   ```
3. **Train on formatted data** with next-token prediction
4. **Evaluate** on instruction following benchmarks

### Best Practices

- Use diverse instruction templates
- Include both simple and complex instructions
- Consider supervised fine-tuning (SFT) before RLHF
- Use quality datasets (e.g., Alpaca, Dolly)
- Monitor for instruction following vs. memorization

## Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| Training loss not decreasing | Check learning rate, batch size, data quality |
| Model generates repetitive text | Adjust temperature, use top-k/top-p sampling |
| Out of memory | Reduce batch size, use gradient checkpointing |
| Slow training | Use mixed precision, flash attention |
| Poor generalization | More data, regularization, better architecture |

## Next Steps

After completing these phases, you can:

1. **Deploy** your model for inference
2. **Optimize** with quantization, pruning
3. **Scale** to larger datasets and models
4. **Experiment** with different architectures
5. **Fine-tune** for your specific use case

## References

- Manning Book: "Build a Large Language Model from Scratch"
- Original Transformer Paper: "Attention Is All You Need"
- LoRA Paper: "LoRA: Low-Rank Adaptation of Large Language Models"
- Various implementation guides and tutorials
