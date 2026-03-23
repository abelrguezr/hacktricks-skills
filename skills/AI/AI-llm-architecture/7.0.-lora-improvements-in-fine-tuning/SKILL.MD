---
name: lora-fine-tuning
description: How to implement LoRA (Low-Rank Adaptation) for efficient fine-tuning of large language models. Use this skill whenever the user wants to fine-tune an LLM, reduce training memory/compute requirements, implement parameter-efficient fine-tuning, or adapt a pre-trained model to a new task without retraining all parameters. Make sure to use this skill when users mention fine-tuning, LoRA, PEFT, parameter-efficient training, or want to train on limited hardware.
---

# LoRA Fine-Tuning Implementation

This skill helps you implement **LoRA (Low-Rank Adaptation)** for efficient fine-tuning of large language models. LoRA reduces training costs by only updating small adapter matrices instead of the entire model.

## When to Use LoRA

Use LoRA when you need to:
- Fine-tune a large model on limited hardware (less GPU memory)
- Adapt a pre-trained model to a new task without full retraining
- Store multiple task-specific adaptations efficiently
- Reduce training time and computational costs

## How LoRA Works

LoRA replaces standard linear layers with a combination of:
1. **Original frozen weights** (preserved from pre-training)
2. **Two small trainable matrices** (A and B) that approximate weight updates

The forward pass becomes: `output = original_linear(x) + alpha * (x @ A @ B)`

### Key Benefits

- **Fewer trainable parameters**: Only matrices A and B are updated
- **Preserved knowledge**: Original model weights stay frozen
- **Storage efficiency**: Save only small LoRA matrices per task
- **Faster training**: Less computation per gradient update

## Implementation

### Step 1: Define LoRA Components

Use the `scripts/lora_layers.py` module which provides:
- `LoRALayer`: The low-rank adapter with matrices A and B
- `LinearWithLoRA`: Wrapper combining original linear layer with LoRA
- `replace_linear_with_lora()`: Recursive function to convert all linear layers

### Step 2: Apply LoRA to Your Model

```python
from scripts.lora_layers import replace_linear_with_lora

# Choose rank and alpha (typical values)
rank = 8  # Lower rank = fewer parameters, higher compression
alpha = 16  # Scaling factor (often 2x rank)

# Apply LoRA to your model
model = replace_linear_with_lora(model, rank=rank, alpha=alpha)
```

### Step 3: Configure Training

Only the LoRA parameters need gradients:

```python
# Freeze original model parameters
for param in model.parameters():
    param.requires_grad = False

# Enable gradients only for LoRA matrices
for name, param in model.named_parameters():
    if 'lora' in name:
        param.requires_grad = True
```

### Step 4: Train as Usual

Your training loop remains the same. The optimizer will only update LoRA parameters.

## Parameter Selection Guide

| Rank | Use Case | Trainable Params (approx) |
|------|----------|---------------------------|
| 4-8  | Small tasks, limited data | ~0.1% of model |
| 8-16 | Standard fine-tuning | ~0.2-0.4% of model |
| 16-32 | Complex tasks, more data | ~0.4-0.8% of model |

**Alpha**: Typically set to 2x rank (e.g., rank=8, alpha=16)

## Example: Fine-Tuning a Transformer

```python
import torch
from transformers import AutoModelForCausalLM
from scripts.lora_layers import replace_linear_with_lora

# Load pre-trained model
model = AutoModelForCausalLM.from_pretrained("your-model")

# Apply LoRA
rank = 8
alpha = 16
model = replace_linear_with_lora(model, rank, alpha)

# Freeze and enable LoRA gradients
for param in model.parameters():
    param.requires_grad = False

for name, param in model.named_parameters():
    if 'lora' in name:
        param.requires_grad = True

# Count trainable parameters
total_params = sum(p.numel() for p in model.parameters())
trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
print(f"Trainable: {trainable_params:,} ({100*trainable_params/total_params:.2f}%)")

# Train normally
optimizer = torch.optim.AdamW(filter(lambda p: p.requires_grad, model.parameters()), lr=1e-4)
```

## Merging LoRA Weights (Optional)

After training, you can merge LoRA weights back into the original model for inference:

```python
def merge_lora_weights(model):
    for name, module in model.named_modules():
        if isinstance(module, LinearWithLoRA):
            # Merge: W_merged = W_original + alpha * B @ A
            with torch.no_grad():
                merged_weight = module.linear.weight + module.lora.alpha * (module.lora.B @ module.lora.A)
                module.linear.weight = torch.nn.Parameter(merged_weight)
            # Replace with plain linear
            setattr(model, name.split('.')[-1], module.linear)
```

## Common Issues and Solutions

**Issue**: Out of memory during training
- **Solution**: Reduce rank (try 4 or 8), use gradient accumulation, or enable mixed precision

**Issue**: Poor fine-tuning quality
- **Solution**: Increase rank, check learning rate, ensure sufficient training data

**Issue**: LoRA not being applied
- **Solution**: Verify `replace_linear_with_lora` was called before training, check that LoRA parameters have `requires_grad=True`

## References

- [Build a Large Language Model from Scratch](https://www.manning.com/books/build-a-large-language-model-from-scratch)
- [LoRA Implementation Example](https://github.com/rasbt/LLMs-from-scratch/blob/main/appendix-E/01_main-chapter-code/appendix-E.ipynb)
