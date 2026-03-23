"""
LoRA (Low-Rank Adaptation) Implementation

This module provides classes and functions to implement LoRA for efficient
fine-tuning of large language models. LoRA reduces trainable parameters by
approximating weight updates with low-rank matrices.

Usage:
    from lora_layers import replace_linear_with_lora
    model = replace_linear_with_lora(model, rank=8, alpha=16)
"""

import math
import torch
import torch.nn as nn
from typing import Optional


class LoRALayer(nn.Module):
    """
    Low-Rank Adaptation layer.
    
    Implements the LoRA decomposition: ΔW ≈ B @ A
    where A: (in_dim x rank) and B: (rank x out_dim)
    
    Args:
        in_dim: Input dimension of the layer
        out_dim: Output dimension of the layer
        rank: Rank of the low-rank decomposition (typically 4-32)
        alpha: Scaling factor for the LoRA output (typically 2x rank)
    
    Example:
        >>> lora = LoRALayer(in_dim=512, out_dim=512, rank=8, alpha=16)
        >>> x = torch.randn(32, 512)
        >>> output = lora(x)  # Shape: (32, 512)
    """
    
    def __init__(self, in_dim: int, out_dim: int, rank: int, alpha: int):
        super().__init__()
        
        # Matrix A: initialized with Kaiming uniform (similar to standard weights)
        self.A = nn.Parameter(torch.empty(in_dim, rank))
        nn.init.kaiming_uniform_(self.A, a=math.sqrt(5))
        
        # Matrix B: initialized to zeros (so LoRA starts with no effect)
        self.B = nn.Parameter(torch.zeros(rank, out_dim))
        
        # Scaling factor
        self.alpha = alpha
        self.rank = rank
        self.in_dim = in_dim
        self.out_dim = out_dim
    
    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Forward pass: output = alpha * (x @ A @ B)
        
        Args:
            x: Input tensor of shape (*, in_dim)
            
        Returns:
            Output tensor of shape (*, out_dim)
        """
        # Compute low-rank update: x @ A @ B
        # A: (in_dim, rank), B: (rank, out_dim)
        # Result: (*, out_dim)
        lora_output = x @ self.A @ self.B
        
        # Apply scaling
        return self.alpha * lora_output
    
    def get_trainable_params(self) -> int:
        """Return the number of trainable parameters in this LoRA layer."""
        return self.A.numel() + self.B.numel()


class LinearWithLoRA(nn.Module):
    """
    Linear layer with LoRA adapter.
    
    Combines a frozen original linear layer with a trainable LoRA adapter.
    Forward pass: output = linear(x) + lora(x)
    
    Args:
        linear: The original nn.Linear layer to wrap
        rank: Rank of the LoRA decomposition
        alpha: Scaling factor for LoRA output
    
    Example:
        >>> linear = nn.Linear(512, 512)
        >>> lora_linear = LinearWithLoRA(linear, rank=8, alpha=16)
        >>> x = torch.randn(32, 512)
        >>> output = lora_linear(x)
    """
    
    def __init__(self, linear: nn.Linear, rank: int, alpha: int):
        super().__init__()
        
        # Store the original linear layer (will be frozen during LoRA training)
        self.linear = linear
        
        # Create LoRA adapter with matching dimensions
        self.lora = LoRALayer(
            in_dim=linear.in_features,
            out_dim=linear.out_features,
            rank=rank,
            alpha=alpha
        )
    
    def forward(self, x: torch.Tensor) -> torch.Tensor:
        """
        Forward pass combining original and LoRA outputs.
        
        Args:
            x: Input tensor
            
        Returns:
            Combined output: original_linear(x) + lora(x)
        """
        # Original path (frozen) + LoRA path (trainable)
        return self.linear(x) + self.lora(x)
    
    def merge_weights(self) -> nn.Linear:
        """
        Merge LoRA weights into the original linear layer.
        
        Returns a new Linear layer with merged weights for efficient inference.
        
        Returns:
            nn.Linear: New linear layer with W_merged = W + alpha * B @ A
        """
        with torch.no_grad():
            # Compute merged weight: W + alpha * B @ A
            lora_weight = self.lora.alpha * (self.lora.B @ self.lora.A)
            merged_weight = self.linear.weight + lora_weight
            
            # Create new linear layer with merged weights
            merged_linear = nn.Linear(
                in_features=self.linear.in_features,
                out_features=self.linear.out_features,
                bias=self.linear.bias is not None
            )
            merged_linear.weight = nn.Parameter(merged_weight)
            
            if self.linear.bias is not None:
                merged_linear.bias = nn.Parameter(self.linear.bias.clone())
            
            return merged_linear


def replace_linear_with_lora(
    model: nn.Module,
    rank: int,
    alpha: int,
    target_modules: Optional[list] = None
) -> nn.Module:
    """
    Recursively replace all nn.Linear layers in a model with LinearWithLoRA.
    
    This function modifies the model in-place and returns it.
    
    Args:
        model: The PyTorch model to modify
        rank: Rank for LoRA decomposition
        alpha: Scaling factor for LoRA
        target_modules: Optional list of module names to target. If None,
                       all Linear layers are replaced.
    
    Returns:
        The modified model with LoRA layers
    
    Example:
        >>> model = MyTransformerModel()
        >>> model = replace_linear_with_lora(model, rank=8, alpha=16)
        >>> # Now train only LoRA parameters
        >>> for param in model.parameters():
        >>>     param.requires_grad = False
        >>> for name, param in model.named_parameters():
        >>>     if 'lora' in name:
        >>>         param.requires_grad = True
    """
    
    for name, module in model.named_children():
        # Check if this is a target module
        if target_modules is not None and name not in target_modules:
            # Recursively process children but don't replace this module
            replace_linear_with_lora(module, rank, alpha, target_modules)
            continue
        
        # Replace Linear layers with LinearWithLoRA
        if isinstance(module, nn.Linear):
            setattr(model, name, LinearWithLoRA(module, rank, alpha))
        else:
            # Recursively process child modules
            replace_linear_with_lora(module, rank, alpha, target_modules)
    
    return model


def count_lora_parameters(model: nn.Module) -> dict:
    """
    Count total and trainable parameters in a model with LoRA.
    
    Args:
        model: The model to analyze
        
    Returns:
        Dictionary with parameter counts:
        - total_params: Total parameters in model
        - trainable_params: Parameters with requires_grad=True
        - lora_params: Parameters in LoRA layers
        - frozen_params: Parameters with requires_grad=False
        - trainable_percentage: Percentage of trainable parameters
    """
    total_params = sum(p.numel() for p in model.parameters())
    trainable_params = sum(p.numel() for p in model.parameters() if p.requires_grad)
    
    lora_params = sum(
        p.numel() for name, p in model.named_parameters() 
        if 'lora' in name.lower()
    )
    
    frozen_params = total_params - trainable_params
    
    return {
        'total_params': total_params,
        'trainable_params': trainable_params,
        'lora_params': lora_params,
        'frozen_params': frozen_params,
        'trainable_percentage': 100 * trainable_params / total_params if total_params > 0 else 0
    }


def print_lora_stats(model: nn.Module) -> None:
    """
    Print a summary of LoRA parameter statistics.
    
    Args:
        model: The model to analyze
    """
    stats = count_lora_parameters(model)
    
    print("\n" + "="*50)
    print("LoRA Parameter Statistics")
    print("="*50)
    print(f"Total parameters:      {stats['total_params']:,}")
    print(f"Trainable parameters:  {stats['trainable_params']:,} ({stats['trainable_percentage']:.2f}%)")
    print(f"LoRA parameters:       {stats['lora_params']:,}")
    print(f"Frozen parameters:     {stats['frozen_params']:,}")
    print("="*50 + "\n")


if __name__ == "__main__":
    # Example usage and testing
    print("Testing LoRA Implementation\n")
    
    # Create a simple model
    class SimpleModel(nn.Module):
        def __init__(self):
            super().__init__()
            self.layer1 = nn.Linear(128, 256)
            self.layer2 = nn.Linear(256, 256)
            self.output = nn.Linear(256, 10)
        
        def forward(self, x):
            x = torch.relu(self.layer1(x))
            x = torch.relu(self.layer2(x))
            return self.output(x)
    
    model = SimpleModel()
    print("Original model:")
    print(f"  Total params: {sum(p.numel() for p in model.parameters()):,}")
    
    # Apply LoRA
    rank = 8
    alpha = 16
    model = replace_linear_with_lora(model, rank, alpha)
    
    print(f"\nAfter applying LoRA (rank={rank}, alpha={alpha}):")
    print_lora_stats(model)
    
    # Freeze original, enable LoRA
    for param in model.parameters():
        param.requires_grad = False
    
    for name, param in model.named_parameters():
        if 'lora' in name:
            param.requires_grad = True
    
    print("After freezing original weights:")
    print_lora_stats(model)
    
    # Test forward pass
    x = torch.randn(4, 128)
    output = model(x)
    print(f"Forward pass successful: input {x.shape} -> output {output.shape}")
