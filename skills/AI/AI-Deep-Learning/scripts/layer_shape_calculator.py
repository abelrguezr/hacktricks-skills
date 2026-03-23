#!/usr/bin/env python3
"""
Layer Shape Calculator for Neural Networks

Calculate output tensor shapes through a network.
Useful for debugging dimension mismatches and planning architectures.
"""


def conv2d_output_shape(
    input_shape,
    in_channels,
    out_channels,
    kernel_size,
    stride=1,
    padding=0,
    dilation=1
):
    """
    Calculate output shape of a 2D convolutional layer.
    
    Args:
        input_shape: Tuple (batch_size, channels, height, width)
        in_channels: Number of input channels (should match input_shape[1])
        out_channels: Number of output channels
        kernel_size: Kernel size (int or (h, w) tuple)
        stride: Stride (int or (h, w) tuple)
        padding: Padding (int or (h, w) tuple)
        dilation: Dilation rate (int or (h, w) tuple)
    
    Returns:
        Tuple: (batch_size, out_channels, output_height, output_width)
    """
    batch_size, _, h, w = input_shape
    
    # Handle scalar vs tuple parameters
    if isinstance(kernel_size, int):
        kh, kw = kernel_size, kernel_size
    else:
        kh, kw = kernel_size
    
    if isinstance(stride, int):
        sh, sw = stride, stride
    else:
        sh, sw = stride
    
    if isinstance(padding, int):
        ph, pw = padding, padding
    else:
        ph, pw = padding
    
    if isinstance(dilation, int):
        dh, dw = dilation, dilation
    else:
        dh, dw = dilation
    
    # Calculate output dimensions
    # Formula: floor((H + 2*P - D*(K-1) - 1) / S) + 1
    out_h = (h + 2*ph - dh*(kh-1) - 1) // sh + 1
    out_w = (w + 2*pw - dw*(kw-1) - 1) // sw + 1
    
    return (batch_size, out_channels, out_h, out_w)


def maxpool2d_output_shape(input_shape, kernel_size, stride=None, padding=0):
    """
    Calculate output shape of a 2D max pooling layer.
    
    Args:
        input_shape: Tuple (batch_size, channels, height, width)
        kernel_size: Pooling kernel size (int or (h, w) tuple)
        stride: Stride (defaults to kernel_size if None)
        padding: Padding (int or (h, w) tuple)
    
    Returns:
        Tuple: (batch_size, channels, output_height, output_width)
    """
    batch_size, channels, h, w = input_shape
    
    if isinstance(kernel_size, int):
        kh, kw = kernel_size, kernel_size
    else:
        kh, kw = kernel_size
    
    if stride is None:
        sh, sw = kh, kw
    elif isinstance(stride, int):
        sh, sw = stride, stride
    else:
        sh, sw = stride
    
    if isinstance(padding, int):
        ph, pw = padding, padding
    else:
        ph, pw = padding
    
    out_h = (h + 2*ph - kh) // sh + 1
    out_w = (w + 2*pw - kw) // sw + 1
    
    return (batch_size, channels, out_h, out_w)


def flatten_output_shape(input_shape):
    """
    Calculate output shape after flattening.
    
    Args:
        input_shape: Tuple (batch_size, channels, height, width)
    
    Returns:
        Tuple: (batch_size, flattened_features)
    """
    batch_size, channels, h, w = input_shape
    flattened = channels * h * w
    return (batch_size, flattened)


def linear_output_shape(input_shape, in_features, out_features):
    """
    Calculate output shape of a fully connected layer.
    
    Args:
        input_shape: Tuple (batch_size, input_features)
        in_features: Expected input features (should match input_shape[1])
        out_features: Number of output features
    
    Returns:
        Tuple: (batch_size, out_features)
    """
    batch_size, _ = input_shape
    return (batch_size, out_features)


def trace_network(input_shape, layers):
    """
    Trace tensor shapes through a sequence of layers.
    
    Args:
        input_shape: Initial input shape
        layers: List of (layer_type, **kwargs) tuples
    
    Returns:
        List: Shapes at each stage
    """
    shapes = [input_shape]
    current_shape = input_shape
    
    for layer_type, kwargs in layers:
        if layer_type == 'conv2d':
            current_shape = conv2d_output_shape(current_shape, **kwargs)
        elif layer_type == 'maxpool2d':
            current_shape = maxpool2d_output_shape(current_shape, **kwargs)
        elif layer_type == 'flatten':
            current_shape = flatten_output_shape(current_shape)
        elif layer_type == 'linear':
            current_shape = linear_output_shape(current_shape, **kwargs)
        
        shapes.append(current_shape)
    
    return shapes


def print_shape_trace(shapes, layer_names):
    """Print formatted shape trace."""
    print("\n" + "="*60)
    print("SHAPE TRACE")
    print("="*60)
    
    for i, (name, shape) in enumerate(zip(layer_names, shapes)):
        if len(shape) == 4:
            print(f"{name:30s} {shape}")
        else:
            print(f"{name:30s} {shape}")


# Example: Trace shapes through a CNN
def example_cnn_shape_trace():
    """Example shape trace for a CNN."""
    input_shape = (32, 3, 48, 48)  # Batch of 32 RGB images, 48x48
    
    layers = [
        ('conv2d', {'in_channels': 3, 'out_channels': 32, 'kernel_size': 3, 'padding': 1}),
        ('conv2d', {'in_channels': 32, 'out_channels': 64, 'kernel_size': 3, 'padding': 1}),
        ('maxpool2d', {'kernel_size': 2, 'stride': 2}),
        ('conv2d', {'in_channels': 64, 'out_channels': 128, 'kernel_size': 3, 'padding': 1}),
        ('maxpool2d', {'kernel_size': 2, 'stride': 2}),
        ('flatten', {}),
        ('linear', {'in_features': 128*12*12, 'out_features': 512}),
        ('linear', {'in_features': 512, 'out_features': 10}),
    ]
    
    layer_names = [
        'Input',
        'Conv1 (3→32, 3×3, pad=1)',
        'Conv2 (32→64, 3×3, pad=1)',
        'MaxPool (2×2, stride=2)',
        'Conv3 (64→128, 3×3, pad=1)',
        'MaxPool (2×2, stride=2)',
        'Flatten',
        'FC1 (→512)',
        'FC2 (→10)',
    ]
    
    shapes = trace_network(input_shape, layers)
    print_shape_trace(shapes, layer_names)


if __name__ == "__main__":
    example_cnn_shape_trace()
    
    print("\n" + "="*60)
    print("USAGE EXAMPLES")
    print("="*60)
    print("""
# Single layer
output_shape = conv2d_output_shape(
    input_shape=(32, 3, 48, 48),
    in_channels=3, out_channels=64, kernel_size=3, padding=1
)

# Full network trace
shapes = trace_network(
    input_shape=(32, 3, 48, 48),
    layers=[
        ('conv2d', {'in_channels': 3, 'out_channels': 32, 'kernel_size': 3, 'padding': 1}),
        ('maxpool2d', {'kernel_size': 2, 'stride': 2}),
        ('flatten', {}),
        ('linear', {'in_features': 32*24*24, 'out_features': 10}),
    ]
)
""")
