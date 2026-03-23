#!/bin/bash
# Check which LLM tools are installed

echo "=== LLM Tools Installation Check ==="
echo ""

check_package() {
    local pkg=$1
    local display_name=$2
    if python3 -c "import $pkg" 2>/dev/null; then
        echo "✓ $display_name ($pkg) - INSTALLED"
    else
        echo "✗ $display_name ($pkg) - NOT INSTALLED"
    fi
}

echo "Local Development Tools:"
check_package "transformers" "Hugging Face Transformers"
check_package "torch" "PyTorch"
check_package "langchain" "LangChain"
check_package "litgpt" "LitGPT"
check_package "litserve" "LitServe"
check_package "tensorflow" "TensorFlow"

echo ""
echo "Python version:"
python3 --version 2>/dev/null || echo "Python 3 not found"

echo ""
echo "GPU Check:"
if python3 -c "import torch; print('CUDA available:', torch.cuda.is_available())" 2>/dev/null; then
    python3 -c "import torch; print('CUDA available:', torch.cuda.is_available())"
else
    echo "Cannot check CUDA (PyTorch not installed)"
fi

echo ""
echo "=== Online Platforms (No installation needed) ==="
echo "✓ Hugging Face: https://huggingface.co/"
echo "✓ TensorFlow Hub: https://www.tensorflow.org/hub"
echo "✓ Kaggle: https://www.kaggle.com/"
echo "✓ Replicate: https://replicate.com/"
