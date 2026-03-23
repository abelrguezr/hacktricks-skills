#!/bin/bash
# Quick setup for Hugging Face Transformers

echo "=== Setting up Hugging Face Transformers ==="

# Check if pip is available
if ! command -v pip3 &> /dev/null; then
    echo "Error: pip3 not found. Please install Python 3 and pip first."
    exit 1
fi

# Install required packages
echo "Installing transformers and torch..."
pip3 install transformers torch

# Verify installation
echo ""
echo "Verifying installation..."
if python3 -c "from transformers import pipeline; print('✓ Hugging Face Transformers installed successfully')"; then
    echo ""
    echo "=== Quick Test ==="
    python3 << 'EOF'
from transformers import pipeline

# Create a simple text generation pipeline
generator = pipeline("text-generation", model="gpt2", max_length=50)
result = generator("Hello, how are you?", max_new_tokens=20)
print("Test output:")
print(result[0]['generated_text'])
EOF
else
    echo "✗ Installation verification failed"
    exit 1
fi

echo ""
echo "=== Setup Complete ==="
echo "You can now use Hugging Face Transformers!"
echo ""
echo "Example usage:"
echo '  from transformers import pipeline'
echo '  generator = pipeline("text-generation", model="gpt2")'
echo '  result = generator("Your prompt here")'
