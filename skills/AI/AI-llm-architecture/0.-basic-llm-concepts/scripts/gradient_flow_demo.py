#!/usr/bin/env python3
"""Gradient Flow Visualization Demo

Demonstrates how gradients flow through a neural network.
"""

import torch
import torch.nn as nn


class TrackedNet(nn.Module):
    """A network that tracks gradient flow through each layer."""
    
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(4, 3)
        self.fc2 = nn.Linear(3, 2)
        self.fc3 = nn.Linear(2, 1)
    
    def forward(self, x):
        h1 = self.fc1(x)
        h2 = self.fc2(h1)
        h3 = self.fc3(h2)
        return h3


def demo_gradient_flow():
    """Show how gradients flow through layers."""
    print("=== Gradient Flow Through Network ===")
    print()
    
    # Create network and input
    model = TrackedNet()
    x = torch.randn(1, 4)
    y = torch.tensor([1.0])
    
    print("Network structure:")
    print("  Input (4) -> FC1 (3) -> FC2 (2) -> FC3 (1) -> Output")
    print()
    
    # Forward pass
    output = model(x)
    loss = nn.functional.mse_loss(output, y)
    
    print(f"Forward pass:")
    print(f"  Input shape: {x.shape}")
    print(f"  Output: {output.item():.4f}")
    print(f"  Target: {y.item():.4f}")
    print(f"  Loss: {loss.item():.4f}")
    print()
    
    # Backward pass
    loss.backward()
    
    print("Gradient magnitudes after backward pass:")
    for name, param in model.named_parameters():
        if param.grad is not None:
            grad_norm = param.grad.norm().item()
            print(f"  {name}: gradient norm = {grad_norm:.4f}")
    print()
    
    # Show gradient shapes match parameter shapes
    print("Gradient shapes (should match parameter shapes):")
    for name, param in model.named_parameters():
        if param.grad is not None:
            print(f"  {name}: param={param.shape}, grad={param.grad.shape}")
    print()


def demo_vanishing_gradients():
    """Demonstrate potential for vanishing gradients."""
    print("=== Vanishing Gradients Demo ===")
    print()
    
    # Create a deep network with sigmoid activations
    layers = []
    for i in range(10):
        layers.append(nn.Linear(10, 10))
        layers.append(nn.Sigmoid())
    layers.append(nn.Linear(10, 1))
    
    deep_net = nn.Sequential(*layers)
    
    x = torch.randn(1, 10)
    y = torch.tensor([0.5])
    
    output = deep_net(x)
    loss = nn.functional.mse_loss(output, y)
    loss.backward()
    
    print("Gradient norms in deep network (10 layers with sigmoid):")
    for i, (name, param) in enumerate(deep_net.named_parameters()):
        if param.grad is not None:
            grad_norm = param.grad.norm().item()
            print(f"  Layer {i//2}: {grad_norm:.6f}")
    print()
    print("Notice how gradients decrease through the network!")
    print("This is the 'vanishing gradient' problem.")
    print()


def demo_gradient_clipping():
    """Show gradient clipping to prevent exploding gradients."""
    print("=== Gradient Clipping Demo ===")
    print()
    
    model = TrackedNet()
    
    # Create a scenario with large gradients
    x = torch.randn(1, 4) * 10  # Large input
    y = torch.tensor([0.0])
    
    output = model(x)
    loss = nn.functional.mse_loss(output, y)
    loss.backward()
    
    # Check gradient norms before clipping
    print("Gradient norms BEFORE clipping:")
    for name, param in model.named_parameters():
        if param.grad is not None:
            print(f"  {name}: {param.grad.norm().item():.4f}")
    
    # Apply gradient clipping
    torch.nn.utils.clip_grad_norm_(model.parameters(), max_norm=1.0)
    
    print("\nGradient norms AFTER clipping (max_norm=1.0):")
    for name, param in model.named_parameters():
        if param.grad is not None:
            print(f"  {name}: {param.grad.norm().item():.4f}")
    print()


if __name__ == "__main__":
    demo_gradient_flow()
    demo_vanishing_gradients()
    demo_gradient_clipping()
    print("Demo complete!")
