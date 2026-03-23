---
name: deep-learning-helper
description: Help users understand and implement deep learning concepts including neural networks, CNNs, RNNs, LLMs, and diffusion models. Use this skill whenever the user asks about deep learning architectures, wants to build neural networks in PyTorch, needs help with training loops, or wants to understand concepts like backpropagation, activation functions, attention mechanisms, or generative models. Make sure to use this skill for any deep learning related questions, code reviews, architecture design, or implementation help.
---

# Deep Learning Helper

A comprehensive guide to deep learning concepts and PyTorch implementation.

## Core Concepts

### Neural Networks

Neural networks are the foundation of deep learning. They consist of interconnected neurons organized in layers:

- **Input Layer**: Receives raw data
- **Hidden Layers**: Perform transformations (can have multiple layers)
- **Output Layer**: Produces final predictions

Each neuron computes: `z = w * x + b` then applies an activation function.

### Activation Functions

Activation functions introduce non-linearity, enabling networks to learn complex patterns:

| Function | Range | Use Case |
|----------|-------|----------|
| Sigmoid | 0 to 1 | Binary classification output |
| ReLU | 0 to ∞ | Hidden layers (most common) |
| Tanh | -1 to 1 | Hidden layers |
| Softmax | 0 to 1 (sums to 1) | Multi-class classification output |

**Key insight**: Without activation functions, a neural network is just a linear transformation regardless of depth.

### Backpropagation

The training algorithm that adjusts weights to minimize loss:

1. **Forward Pass**: Compute output through the network
2. **Loss Calculation**: Compare prediction to target
3. **Backward Pass**: Compute gradients using chain rule
4. **Weight Update**: Adjust weights in opposite direction of gradient

## Convolutional Neural Networks (CNNs)

CNNs excel at processing grid-like data (images) by learning spatial hierarchies of features.

### CNN Components

**Convolutional Layers**: Apply learnable filters to extract features
- Initial layers detect edges and textures
- Intermediate layers detect shapes and patterns
- Final layers detect complex objects

**Pooling Layers**: Downsample feature maps
- Max pooling: keeps strongest activations
- Reduces parameters and computational cost
- Provides translation invariance

**Fully Connected Layers**: Final classification
- Connects all neurons between layers
- Typically at the end of the network

### CNN Design Pattern

```python
# Standard pattern: Conv → ReLU → Conv → ReLU → Pool
# Repeat, then flatten → FC → Output
```

### Parameter Calculation

For a convolutional layer:
```
Parameters = (kernel_height × kernel_width × in_channels + 1) × out_channels
```

The `+1` is for the bias term per output channel.

For a fully connected layer:
```
Parameters = (input_features + 1) × output_features
```

### CNN Implementation Template

See `scripts/cnn_template.py` for a complete CNN implementation.

**Key considerations**:
- Start with 32-64 filters, double every 2-3 layers
- Use 3×3 kernels with padding=1 to preserve spatial dimensions
- Apply max pooling (2×2, stride=2) after every 1-2 conv layers
- Add dropout (0.5) before fully connected layers to prevent overfitting
- Flatten after final pooling, before FC layers

## Recurrent Neural Networks (RNNs)

RNNs process sequential data by maintaining a hidden state across time steps.

### RNN Components

- **Recurrent Layers**: Process sequences one step at a time
- **Hidden State**: Vector summarizing past information
- **Output Layer**: Produces predictions from hidden state

### LSTM and GRU

Standard RNNs struggle with long-range dependencies due to vanishing gradients. LSTMs and GRUs solve this with gating mechanisms:

**LSTM** (Long Short-Term Memory):
- Input gate: controls new information
- Forget gate: controls what to discard
- Output gate: controls what to output
- Cell state: carries information across time steps

**GRU** (Gated Recurrent Unit):
- Simpler than LSTM (combines input/forget gates)
- Update gate: controls state updates
- Reset gate: controls how much past to forget
- More computationally efficient

## Large Language Models (LLMs)

LLMs use transformer architecture for natural language tasks.

### Transformer Architecture

**Self-Attention**: Weighs importance of different words in context
- Computes attention scores between all word pairs
- Allows model to focus on relevant context

**Multi-Head Attention**: Multiple attention mechanisms in parallel
- Each head captures different relationships
- Combined for richer representations

**Positional Encoding**: Adds position information
- Transformers have no inherent order
- Encoding provides sequence position context

## Diffusion Models

Generative models that create data by reversing a noise-adding process.

### How Diffusion Works

**Forward Process**: Gradually add noise to data
- Transforms data into simple noise distribution
- Defined by noise schedule

**Reverse Process**: Learn to denoise
- Trained to reconstruct data from noisy samples
- Generates new samples by starting from noise

**Image Generation Pipeline**:
1. Encode text prompt to latent representation
2. Sample random noise from Gaussian distribution
3. Apply diffusion steps to transform noise into image
4. Each step denoises based on text conditioning

## Training Best Practices

### Hyperparameters

| Parameter | Typical Range | Notes |
|-----------|---------------|-------|
| Learning Rate | 1e-4 to 1e-3 | Adam optimizer |
| Batch Size | 32 to 256 | Depends on GPU memory |
| Epochs | 5 to 100 | Monitor for overfitting |
| Weight Decay | 1e-4 to 1e-5 | L2 regularization |
| Dropout | 0.2 to 0.5 | Before FC layers |

### Training Loop Pattern

See `scripts/training_loop_template.py` for a complete training implementation.

**Essential steps**:
1. Set model to train mode (`model.train()`)
2. Zero gradients (`optimizer.zero_grad()`)
3. Forward pass to get predictions
4. Compute loss
5. Backward pass (`loss.backward()`)
6. Update weights (`optimizer.step()`)

**For evaluation**:
1. Set model to eval mode (`model.eval()`)
2. Use `torch.no_grad()` to disable gradient computation
3. Compute metrics without updating weights

### Loss Functions

| Task | Loss Function |
|------|---------------|
| Multi-class classification | `nn.CrossEntropyLoss()` |
| Binary classification | `nn.BCEWithLogitsLoss()` |
| Regression | `nn.MSELoss()` |

### Optimizers

- **Adam**: Adaptive learning rates, good default choice
- **SGD**: Stochastic gradient descent, can work well with momentum
- **RMSprop**: Good for RNNs

## Common Pitfalls

1. **Forgetting to zero gradients**: Gradients accumulate by default
2. **Not setting train/eval mode**: Dropout and batch norm behave differently
3. **Mismatched input/output shapes**: Verify tensor dimensions at each layer
4. **Overfitting**: Use dropout, data augmentation, weight decay
5. **Vanishing gradients**: Use ReLU, batch norm, or LSTM/GRU for sequences

## When to Use Each Architecture

| Task | Recommended Architecture |
|------|-------------------------|
| Image classification | CNN |
| Object detection | CNN + additional heads |
| Image segmentation | CNN with skip connections |
| Time series | RNN, LSTM, or GRU |
| Text generation | Transformer (LLM) |
| Machine translation | Transformer encoder-decoder |
| Image generation | Diffusion model |
| Text-to-image | Diffusion + text encoder |

## Quick Reference

### PyTorch Layer Instantiation

```python
# Convolutional layer
nn.Conv2d(in_channels, out_channels, kernel_size, padding=0)

# Max pooling
nn.MaxPool2d(kernel_size=2, stride=2)

# Fully connected
nn.Linear(in_features, out_features)

# Dropout
nn.Dropout(p=0.5)

# RNN variants
nn.LSTM(input_size, hidden_size, num_layers)
n.GRU(input_size, hidden_size, num_layers)
```

### Common Transformations

```python
# Resize images
transforms.Resize((height, width))

# Convert to tensor
transforms.ToTensor()

# Normalize
transforms.Normalize(mean, std)

# Data augmentation
transforms.RandomRotation(degrees)
transforms.ColorJitter(brightness, contrast)
```

## Next Steps

For implementation help:
1. Use `scripts/cnn_template.py` for image tasks
2. Use `scripts/training_loop_template.py` for training
3. Use `scripts/parameter_calculator.py` to estimate model size

For concept questions, refer to the relevant section above.
