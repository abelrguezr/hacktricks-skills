---
name: llm-classification-finetuning
description: How to fine-tune a pre-trained LLM (like GPT2) for text classification tasks. Use this skill whenever the user wants to adapt a language model for classification (spam detection, sentiment analysis, topic categorization, intent classification, or any binary/multi-class text classification). Trigger this skill when users mention fine-tuning, classification, adapting models, or need to convert a generative model into a classifier.
---

# LLM Classification Fine-Tuning

This skill guides you through fine-tuning a pre-trained language model for text classification tasks. Instead of generating text, the model will output probabilities for each class (e.g., spam vs. not spam).

## When to Use This Skill

Use this skill when you need to:
- Convert a pre-trained LLM into a text classifier
- Perform binary classification (spam/not spam, positive/negative)
- Perform multi-class classification (topic categorization, intent detection)
- Adapt a model to domain-specific classification tasks
- Work with labeled text data for supervised learning

## Overview

Fine-tuning for classification involves:
1. **Preparing balanced training data** with proper train/validation/test splits
2. **Modifying the model's output layer** to match your number of classes
3. **Freezing most parameters** and only tuning the final layers
4. **Adjusting the loss function** to focus on the classification token

## Step 1: Prepare Your Dataset

### Balance Your Classes

If your dataset has class imbalance, balance it by sampling equally from each class:

```python
# Count examples per class
spam_count = len(spam_examples)
not_spam_count = len(not_spam_examples)

# Use equal numbers from each class
min_count = min(spam_count, not_spam_count)
balanced_spam = spam_examples[:min_count]
balanced_not_spam = not_spam_examples[:min_count]
```

### Split into Train/Validation/Test

Use a 70/10/20 split:
- **Training (70%)**: Used to update model weights
- **Validation (10%)**: Used to tune hyperparameters and prevent overfitting
- **Test (20%)**: Used only after training for final unbiased evaluation

```python
from sklearn.model_selection import train_test_split

# First split: separate test set (20%)
train_val, test = train_test_split(data, test_size=0.2, random_state=42)

# Second split: separate validation from training (10% of total = 12.5% of remaining)
train, val = train_test_split(train_val, test_size=0.125, random_state=42)
```

### Pad Entries to Same Length

LLMs expect fixed-length inputs. Pad shorter entries with a special token:

```python
# Find maximum length
max_length = max(len(text) for text in all_texts)

# Pad all entries
def pad_sequence(tokens, max_len, pad_token_id):
    if len(tokens) < max_len:
        return tokens + [pad_token_id] * (max_len - len(tokens))
    return tokens[:max_len]
```

## Step 2: Initialize the Pre-trained Model

Load a pre-trained model (e.g., GPT2) with its weights:

```python
from your_model_lib import GPTModel, GPTConfig

# Load pre-trained weights
BASE_CONFIG = GPTConfig(vocab_size=50257, emb_dim=768, n_layers=12, n_heads=12, max_seq_len=1024)
model = GPTModel(BASE_CONFIG)
model.load_state_dict(torch.load("gpt2-pretrained.pth"))
```

## Step 3: Replace the Output Head

Replace the vocabulary-sized output layer with a classification head:

```python
import torch.nn as nn

num_classes = 2  # For binary classification (spam/not spam)
# For multi-class, set to your number of classes

# Replace the output head
model.out_head = nn.Linear(
    in_features=BASE_CONFIG["emb_dim"],
    out_features=num_classes
)
```

## Step 4: Freeze Most Parameters

Only fine-tune the final layers for efficiency:

```python
# Freeze all parameters first
for param in model.parameters():
    param.requires_grad = False

# Unfreeze the last transformer block
for param in model.trf_blocks[-1].parameters():
    param.requires_grad = True

# Unfreeze the final layer normalization
for param in model.final_norm.parameters():
    param.requires_grad = True

# Unfreeze the new classification head
for param in model.out_head.parameters():
    param.requires_grad = True
```

## Step 5: Modify Loss Function for Classification

For classification, only the last token matters. Modify your loss calculation:

```python
def calc_loss_batch(input_batch, target_batch, model, device):
    """Calculate loss for classification (only last token)."""
    input_batch, target_batch = input_batch.to(device), target_batch.to(device)
    
    # Get logits for the last token only
    logits = model(input_batch)[:, -1, :]
    
    # Cross-entropy loss for classification
    loss = nn.functional.cross_entropy(logits, target_batch)
    return loss


def calc_accuracy_loader(data_loader, model, device, num_batches=None):
    """Calculate accuracy on a data loader."""
    model.eval()
    correct_predictions, num_examples = 0, 0
    
    if num_batches is None:
        num_batches = len(data_loader)
    else:
        num_batches = min(num_batches, len(data_loader))
    
    for i, (input_batch, target_batch) in enumerate(data_loader):
        if i < num_batches:
            input_batch, target_batch = input_batch.to(device), target_batch.to(device)
            
            with torch.no_grad():
                logits = model(input_batch)[:, -1, :]
                predicted_labels = torch.argmax(logits, dim=-1)
            
            num_examples += predicted_labels.shape[0]
            correct_predictions += (predicted_labels == target_batch).sum().item()
        else:
            break
    
    return correct_predictions / num_examples
```

## Step 6: Training Loop

```python
def train_classifier(model, train_loader, val_loader, device, epochs=10, lr=1e-5):
    optimizer = torch.optim.Adam(filter(lambda p: p.requires_grad, model.parameters()), lr=lr)
    
    for epoch in range(epochs):
        model.train()
        total_loss = 0
        
        for input_batch, target_batch in train_loader:
            optimizer.zero_grad()
            loss = calc_loss_batch(input_batch, target_batch, model, device)
            loss.backward()
            optimizer.step()
            total_loss += loss.item()
        
        # Evaluate on validation set
        val_accuracy = calc_accuracy_loader(val_loader, model, device)
        avg_loss = total_loss / len(train_loader)
        
        print(f"Epoch {epoch+1}: Loss={avg_loss:.4f}, Val Accuracy={val_accuracy:.4f}")
    
    return model
```

## Best Practices

1. **Start with a pre-trained model** - Training from scratch is expensive and unnecessary for most tasks
2. **Balance your classes** - Imbalanced data leads to biased models
3. **Use validation data** - Monitor for overfitting during training
4. **Freeze early layers** - They capture general language patterns; only tune final layers
5. **Use small learning rates** - Fine-tuning requires gentle updates (1e-5 to 1e-4)
6. **Monitor both loss and accuracy** - Loss can decrease while accuracy plateaus

## Common Classification Tasks

- **Spam detection**: Binary (spam/not spam)
- **Sentiment analysis**: Binary or multi-class (positive/neutral/negative)
- **Intent classification**: Multi-class (book_flight, check_balance, etc.)
- **Topic categorization**: Multi-class (sports, politics, technology, etc.)
- **Toxicity detection**: Binary (toxic/not toxic)

## Troubleshooting

**Model not learning**: Check that parameters are unfrozen (`requires_grad=True`)

**Overfitting**: Use validation accuracy to detect; try more regularization or early stopping

**Poor accuracy**: Ensure data is balanced and properly labeled; try more training epochs

**Slow training**: Freeze more layers; reduce batch size; use GPU

## References

- [LLMs from Scratch - Chapter 6](https://github.com/rasbt/LLMs-from-scratch/blob/main/ch06/01_main-chapter-code/ch06.ipynb)
- [Build a Large Language Model from Scratch](https://www.manning.com/books/build-a-large-language-model-from-scratch)
