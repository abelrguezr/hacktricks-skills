---
name: llm-fundamentals
description: Explain and teach Large Language Model fundamentals including pretraining, model architecture, PyTorch tensors, automatic differentiation, and backpropagation. Use this skill whenever the user asks about LLM concepts, neural network training, PyTorch operations, gradient computation, or wants to understand how LLMs work internally. Trigger on questions about model parameters, context length, embedding dimensions, tensor operations, autograd, or backpropagation.
---

# LLM Fundamentals

A skill for explaining and teaching Large Language Model concepts, PyTorch operations, and neural network training fundamentals.

## When to Use This Skill

Use this skill when the user:
- Asks about how LLMs work or are trained
- Wants to understand model architecture components (parameters, layers, attention heads)
- Needs help with PyTorch tensor operations
- Is learning about automatic differentiation or backpropagation
- Wants to understand neural network training concepts
- Asks about pretraining vs fine-tuning

## Core Concepts to Explain

### Pretraining

Pretraining is the foundational phase where an LLM learns language structure from vast text data. During pretraining:

- The model learns grammar, vocabulary, syntax, and contextual relationships
- It acquires broad world knowledge from diverse data
- The model becomes capable of generating coherent, contextually relevant text
- After pretraining, the model can be fine-tuned for specific tasks or domains

**Key point:** Pretraining creates the general language understanding; fine-tuning adapts it to specific applications.

### Main LLM Architecture Components

When discussing LLM configuration, explain these components:

| Component | Description | Typical Values |
|-----------|-------------|----------------|
| **Parameters** | Learnable weights and biases in the neural network | Millions to billions |
| **Context Length** | Maximum sequence length the model can process | 512 to 32K+ tokens |
| **Embedding Dimension** | Size of vector representing each token | 768 to 16K+ |
| **Hidden Dimension** | Size of hidden layers in the network | Matches embedding dimension |
| **Number of Layers** | Depth of the network (transformer blocks) | 12 to 100+ |
| **Attention Heads** | Parallel attention mechanisms per layer | 12 to 128+ |
| **Dropout** | Percentage of neurons randomly disabled during training | 0-20% |

**Example GPT-2 Configuration:**

```python
GPT_CONFIG_124M = {
    "vocab_size": 50257,      # BPE tokenizer vocabulary
    "context_length": 1024,   # Max sequence length
    "emb_dim": 768,           # Embedding dimension
    "n_heads": 12,            # Attention heads per layer
    "n_layers": 12,           # Number of transformer layers
    "drop_rate": 0.1,         # 10% dropout
    "qkv_bias": False         # No bias in QKV projections
}
```

### PyTorch Tensors

Tensors are multi-dimensional arrays that serve as the fundamental data structure in PyTorch.

#### Tensor Ranks

- **Scalar (0D)**: Single number, e.g., `5`
- **Vector (1D)**: One-dimensional array, e.g., `[5, 1]`
- **Matrix (2D)**: Two-dimensional array with rows/columns, e.g., `[[1,3], [5,2]]`
- **Higher-Rank (3D+)**: Multi-dimensional data, e.g., 3D tensors for images

#### Creating Tensors

```python
import torch

# Scalar (0D)
tensor0d = torch.tensor(1)

# Vector (1D)
tensor1d = torch.tensor([1, 2, 3])

# Matrix (2D)
tensor2d = torch.tensor([[1, 2], [3, 4]])

# 3D Tensor
tensor3d = torch.tensor([[[1, 2], [3, 4]], [[5, 6], [7, 8]]])
```

#### Tensor Data Types

- Integers default to `torch.int64`
- Floats default to `torch.float32`
- Check type with `.dtype`
- Convert with `.to()`

```python
tensor1d = torch.tensor([1, 2, 3])
print(tensor1d.dtype)  # torch.int64

float_tensor = tensor1d.to(torch.float32)
print(float_tensor.dtype)  # torch.float32
```

#### Common Tensor Operations

```python
# Access shape
print(tensor2d.shape)  # torch.Size([2, 2])

# Reshape
reshaped = tensor2d.reshape(4, 1)

# Transpose (2D only)
transposed = tensor2d.T

# Matrix multiplication
result = tensor2d @ tensor2d.T
```

**Why Tensors Matter:**
- Store input data, weights, and biases
- Enable forward and backward passes in training
- Support automatic gradient computation via autograd
- Can be moved to GPU for acceleration

### Automatic Differentiation

Automatic differentiation (autograd) efficiently computes derivatives for optimization algorithms like gradient descent.

#### The Chain Rule

The chain rule is the mathematical foundation of autograd:

If `y = f(u)` and `u = g(x)`, then:

```
dy/dx = dy/du * du/dx
```

#### Computational Graph

Autograd builds a computational graph where:
- Each node represents an operation or variable
- Traversing the graph computes derivatives efficiently
- The graph is built dynamically during the forward pass

#### PyTorch Autograd Example

```python
import torch
import torch.nn.functional as F

# Define inputs
x = torch.tensor([1.1])
y = torch.tensor([1.0])

# Initialize parameters with gradient tracking
w = torch.tensor([2.2], requires_grad=True)
b = torch.tensor([0.0], requires_grad=True)

# Forward pass
z = x * w + b
a = torch.sigmoid(z)
loss = F.binary_cross_entropy(a, y)

# Backward pass - computes gradients
loss.backward()

# Access gradients
print("Gradient w.r.t w:", w.grad)
print("Gradient w.r.t b:", b.grad)
```

**Key Points:**
- Set `requires_grad=True` to track operations
- Call `.backward()` to compute gradients
- Gradients accumulate in the `.grad` attribute
- Autograd handles the chain rule automatically

### Backpropagation in Neural Networks

Backpropagation extends automatic differentiation to multi-layer networks.

#### The Training Loop

1. **Initialize** network parameters (weights and biases)
2. **Forward Pass**: Compute outputs by passing inputs through layers
3. **Compute Loss**: Evaluate difference between output and target
4. **Backward Pass**: Compute gradients using chain rule (backpropagation)
5. **Update Parameters**: Apply optimization algorithm (e.g., gradient descent)

#### Simple Neural Network Example

```python
import torch
import torch.nn as nn
import torch.optim as optim

# Define network
class SimpleNet(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(10, 5)   # Input to hidden
        self.relu = nn.ReLU()
        self.fc2 = nn.Linear(5, 1)    # Hidden to output
        self.sigmoid = nn.Sigmoid()

    def forward(self, x):
        h = self.relu(self.fc1(x))
        y_hat = self.sigmoid(self.fc2(h))
        return y_hat

# Training setup
net = SimpleNet()
criterion = nn.BCELoss()
optimizer = optim.SGD(net.parameters(), lr=0.01)

# Training loop
inputs = torch.randn(1, 10)
labels = torch.tensor([1.0])

optimizer.zero_grad()          # Clear previous gradients
outputs = net(inputs)          # Forward pass
loss = criterion(outputs, labels)  # Compute loss
loss.backward()                # Backward pass
optimizer.step()               # Update parameters
```

#### Understanding the Backward Pass

During `loss.backward()`:
- PyTorch traverses the computational graph in reverse
- Applies the chain rule at each operation
- Accumulates gradients in `.grad` for each parameter
- Gradients are ready for optimizer to use

#### Advantages of Automatic Differentiation

- **Efficiency**: Reuses intermediate results, avoids redundant calculations
- **Accuracy**: Provides exact derivatives up to machine precision
- **Simplicity**: Eliminates manual derivative computation

## Teaching Patterns

### When Explaining Concepts

1. **Start with intuition** before diving into math
2. **Use concrete examples** with actual numbers when possible
3. **Connect to real applications** (e.g., "this is how ChatGPT learns")
4. **Show code** that demonstrates the concept
5. **Explain the why** - why this matters for LLMs

### Common Questions to Anticipate

- "What's the difference between pretraining and fine-tuning?"
- "How many parameters does a typical LLM have?"
- "Why do we need automatic differentiation?"
- "What happens during backpropagation?"
- "How do tensors relate to neural networks?"

### When to Reference Scripts

For hands-on demonstrations, reference the bundled scripts:
- `scripts/tensor_demo.py` - Tensor operations examples
- `scripts/autograd_demo.py` - Automatic differentiation walkthrough
- `scripts/simple_net.py` - Complete neural network training example

## Quick Reference

### Tensor Operations Cheat Sheet

| Operation | Code | Description |
|-----------|------|-------------|
| Create | `torch.tensor([1,2,3])` | Create from list |
| Shape | `.shape` | Get dimensions |
| Reshape | `.reshape(4,1)` | Change shape |
| Transpose | `.T` | Swap dimensions (2D) |
| Multiply | `@` or `.matmul()` | Matrix multiplication |
| Type | `.dtype` | Check data type |
| Convert | `.to(torch.float32)` | Change type |

### Training Loop Template

```python
for epoch in range(epochs):
    optimizer.zero_grad()      # 1. Clear gradients
    outputs = model(inputs)    # 2. Forward pass
    loss = criterion(outputs, labels)  # 3. Compute loss
    loss.backward()            # 4. Backward pass
    optimizer.step()           # 5. Update parameters
```

### Key Takeaways

- **Pretraining** = general language learning; **Fine-tuning** = task-specific adaptation
- **Parameters** are the learnable weights that define the model
- **Tensors** are the data containers for all neural network operations
- **Autograd** automatically computes gradients via the chain rule
- **Backpropagation** is the algorithm that updates parameters using gradients
