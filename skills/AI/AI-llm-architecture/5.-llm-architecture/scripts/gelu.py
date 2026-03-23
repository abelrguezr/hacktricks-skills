#!/usr/bin/env python3
"""GELU (Gaussian Error Linear Unit) activation function.

GELU introduces non-linearity into the model. Unlike ReLU which zeroes out
negative inputs, GELU smoothly maps inputs to outputs, allowing for small
non-zero values for negative inputs.

Mathematical approximation:
    GELU(x) = 0.5 * x * (1 + tanh(sqrt(2/pi) * (x + 0.044715 * x^3)))
"""

import torch
import torch.nn as nn


class GELU(nn.Module):
    """GELU activation function implementation."""
    
    def __init__(self):
        super().__init__()

    def forward(self, x):
        """Apply GELU activation.
        
        Args:
            x: Input tensor of any shape
            
        Returns:
            Tensor with GELU applied element-wise
        """
        return 0.5 * x * (1 + torch.tanh(
            torch.sqrt(torch.tensor(2.0 / torch.pi)) *
            (x + 0.044715 * torch.pow(x, 3))
        ))


def main():
    """Demonstrate GELU with example."""
    gelu = GELU()
    
    # Example input
    x = torch.tensor([-2.0, -1.0, 0.0, 1.0, 2.0])
    
    print("Input:", x.tolist())
    print("GELU Output:", gelu(x).tolist())
    
    # Compare with ReLU
    relu_output = torch.relu(x)
    print("ReLU Output (for comparison):", relu_output.tolist())
    print("\nNote: GELU allows small negative values, ReLU zeros them out")


if __name__ == "__main__":
    main()
