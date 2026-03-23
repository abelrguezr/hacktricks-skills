---
name: test-llms
description: How to test, run, and train LLMs locally or online. Use this skill whenever the user wants to experiment with language models, compare different LLMs, set up local inference, fine-tune models, or deploy models to production. Covers Hugging Face Transformers, LangChain, LitGPT, LitServe, Axolotl, TensorFlow Hub, Kaggle, and Replicate. Make sure to use this skill when the user mentions testing models, running LLMs locally, deploying AI models, or comparing different LLM frameworks.
---

# Test LLMs

A skill for testing, running, and training language models locally or online.

## Quick Decision Guide

**Want to run models locally?** → See "Run & Train Models Locally"
**Want to try models online?** → See "Try Models Online"
**Need to deploy a model?** → See "Deployment Options"

## Run & Train Models Locally

### Hugging Face Transformers

**Best for:** Using, training, and deploying LLMs like GPT, BERT, and many others

**Setup:**
```bash
pip install transformers torch
```

**Basic usage:**
```python
from transformers import pipeline

# Text generation
generator = pipeline("text-generation", model="gpt2")
result = generator("Hello, how are you?")
```

**When to use:**
- You need access to thousands of pre-trained models
- You want to fine-tune models on your own data
- You need flexibility in model architecture and training options

### LangChain

**Best for:** Building applications that connect LLMs with external data sources, APIs, and databases

**Setup:**
```bash
pip install langchain
```

**Basic usage:**
```python
from langchain.llms import HuggingFacePipeline
from langchain.chains import LLMChain

# Create an LLM chain
llm = HuggingFacePipeline(pipeline=generator)
chain = LLMChain(llm=llm)
result = chain.run("What is the capital of France?")
```

**When to use:**
- You need to integrate LLMs with external data sources
- You want to manage conversation history
- You're building complex workflows with multiple steps

### LitGPT

**Best for:** Training, fine-tuning, and deploying GPT-based models with Lightning AI

**Setup:**
```bash
pip install litgpt
```

**When to use:**
- You're working with GPT-based models
- You need optimized training workflows
- You want Lightning AI ecosystem integration

### LitServe

**Best for:** Deploying AI models for real-time applications

**Setup:**
```bash
pip install litserve
```

**When to use:**
- You need to serve models in production
- You want scalable, optimized serving
- You're building real-time applications

### Axolotl

**Best for:** Cloud-based deployment, scaling, and management of AI models

**When to use:**
- You need automated scaling
- You want monitoring and cloud integration
- You're deploying to production without managing infrastructure

## Try Models Online

### Hugging Face

**Best for:** Exploring pre-trained models, datasets, and interactive demos

**Key features:**
- **Models:** Browse and download pre-trained models for text generation, translation, image recognition
- **Datasets:** Access diverse training and evaluation data
- **Spaces:** Host and share interactive ML applications

**When to use:**
- You want to quickly test models without setup
- You need to find the right model for your task
- You want to share demos with others

### TensorFlow Hub & Kaggle

**Best for:** Reusable ML modules and community datasets

**TensorFlow Hub features:**
- Pre-trained models and components
- Step-by-step tutorials
- Comprehensive documentation

**Kaggle features:**
- Community datasets and notebooks
- Competitions and learning resources

**When to use:**
- You're working with TensorFlow
- You need reusable model components
- You want to learn from community examples

### Replicate

**Best for:** Running ML models via simple API

**Key features:**
- Community-contributed models
- Simple API access
- Easy deployment and scaling

**When to use:**
- You want to run models without infrastructure setup
- You need API-based model access
- You're building applications that need ML capabilities

## Decision Framework

**Choose local when:**
- You need full control over the model
- You have sensitive data that can't leave your environment
- You want to fine-tune models
- You have the hardware resources

**Choose online when:**
- You want to quickly test models
- You don't have local hardware
- You need to share demos
- You want to explore many models quickly

## Common Workflows

### Quick Model Testing
1. Go to Hugging Face Spaces or Replicate
2. Find a model for your task
3. Test it with your input
4. If it works, decide whether to deploy locally or use their API

### Local Development Setup
1. Install Hugging Face Transformers
2. Choose a pre-trained model
3. Test with sample inputs
4. Fine-tune if needed
5. Deploy with LitServe or similar

### Production Deployment
1. Choose deployment method (LitServe, Axolotl, Replicate)
2. Set up monitoring and scaling
3. Deploy to production
4. Monitor performance

## Helpful Scripts

Use the bundled scripts to check your environment and get started quickly:

- `scripts/check-llm-tools.sh` - Check which LLM tools are installed
- `scripts/setup-huggingface.sh` - Quick setup for Hugging Face Transformers
