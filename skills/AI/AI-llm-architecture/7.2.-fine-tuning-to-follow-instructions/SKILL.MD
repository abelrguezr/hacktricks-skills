---
name: llm-instruction-finetuning
description: How to fine-tune a pre-trained LLM to follow instructions and respond to tasks like a chatbot. Use this skill whenever the user wants to train an LLM on instruction-response pairs, format datasets for instruction tuning, evaluate fine-tuned model responses, or understand the complete instruction fine-tuning workflow. Make sure to use this skill when users mention instruction tuning, chatbot training, Alpaca format, Phi-3 format, or any scenario where they need to make an LLM respond to specific prompts rather than just generate text.
---

# LLM Instruction Fine-Tuning

This skill guides you through fine-tuning a pre-trained LLM to follow instructions and respond to tasks like a chatbot, rather than just generating text.

## When to Use This Skill

Use this skill when:
- You have a dataset of instruction-response pairs and want to fine-tune an LLM
- You need to format data in Alpaca or Phi-3 style for instruction tuning
- You want to evaluate a fine-tuned model's response quality
- You're building a chatbot or task-oriented AI assistant
- You need to understand the complete instruction fine-tuning workflow

## Overview

Instruction fine-tuning transforms a pre-trained language model into one that:
- Understands it should respond to specific prompts
- Follows the format and style of instruction-response pairs
- Generates appropriate responses to user queries

## Step 1: Prepare Your Dataset

### Dataset Format

You need a dataset with instructions and responses. Common formats:

**Alpaca Style:**
```
Below is an instruction that describes a task. Write a response that appropriately completes the request.

### Instruction:
Calculate the area of a circle with a radius of 5 units.

### Response:
The area of a circle is calculated using the formula A = πr². Plugging in the radius of 5 units:
A = π(5)² = π × 25 = 25π square units.
```

**Phi-3 Style:**
```
<|User|>
Can you explain what gravity is in simple terms?

<|Assistant|>
Absolutely! Gravity is a force that pulls objects toward each other.
```

### Format Your Data

Use the `format_instruction_data.py` script (in `scripts/`) to convert your raw instruction-response pairs into the desired format. This handles:
- Adding instruction/response templates
- Handling optional input fields
- Creating training/validation/test splits

## Step 2: Create Data Loaders

### Key Processing Steps

1. **Tokenize** all texts using your tokenizer
2. **Pad** samples to the same length (typically your model's context length)
3. **Create targets** by shifting inputs by 1 token (for next-token prediction)
4. **Mask padding tokens** with -100 to exclude them from loss calculation
5. **Optionally mask instruction tokens** so the model only learns to generate responses

### Why Mask with -100?

Using `cross_entropy(..., ignore_index=-100)` tells PyTorch to ignore targets with -100. This means:
- Padding tokens don't contribute to loss
- You can optionally mask the instruction portion so the model focuses on learning responses

## Step 3: Load Pre-trained Model & Fine-Tune

### Loading the Model

Load your pre-trained LLM (this was covered in previous training steps). Then use your existing training function to fine-tune.

### Monitoring Training

Watch both training and validation loss:
- **Training loss decreasing**: Model is learning
- **Validation loss decreasing**: Model is generalizing
- **Validation loss increasing while training loss decreases**: Overfitting is occurring

**Action**: Stop training at the epoch where validation loss starts increasing to avoid overfitting.

## Step 4: Evaluate Response Quality

### Why Manual Evaluation Matters

Unlike classification tasks, you can't trust loss alone for instruction tuning. The model might:
- Generate correct format and syntax
- But give completely wrong answers

Loss won't catch this. You must evaluate response quality.

### Evaluation Methods

**1. Manual Review**
- Generate responses on your test set
- Review them manually for correctness
- Check for hallucinations, wrong answers, or format issues

**2. LLM-as-Judge**
- Pass generated responses and expected responses to another LLM
- Ask it to evaluate quality, correctness, and helpfulness

**3. Standardized Benchmarks**

| Benchmark | What It Tests | Link |
|-----------|---------------|------|
| **MMLU** | Knowledge across 57 subjects (humanities, sciences, etc.) | https://arxiv.org/abs/2009.03300 |
| **LMSYS Chatbot Arena** | Side-by-side chatbot comparison | https://arena.lmsys.org |
| **AlpacaEval** | GPT-4 evaluates model responses | https://github.com/tatsu-lab/alpaca_eval |
| **GLUE** | 9 NLU tasks (sentiment, entailment, QA) | https://gluebenchmark.com |
| **SuperGLUE** | Harder version of GLUE | https://super.gluebenchmark.com |
| **BIG-bench** | 200+ tasks (reasoning, translation, QA) | https://github.com/google/BIG-bench |
| **HELM** | Comprehensive evaluation (accuracy, robustness, fairness) | https://crfm.stanford.edu/helm |
| **HumanEval** | Code generation problems | https://github.com/openai/human-eval |
| **SQuAD** | Question answering on Wikipedia | https://rajpurkar.github.io/SQuAD-explorer |
| **TriviaQA** | Trivia questions with evidence | https://nlp.cs.washington.edu/triviaqa |

## Common Issues & Solutions

### Issue: Model Ignores Instructions
- **Cause**: Not enough instruction-response examples, or poor formatting
- **Solution**: Ensure consistent format, increase training data, verify masking is correct

### Issue: Model Overfits
- **Cause**: Training too long, dataset too small
- **Solution**: Use early stopping on validation loss, add more diverse data

### Issue: Model Generates Wrong Answers
- **Cause**: Model memorized format but not content
- **Solution**: Manual evaluation, use LLM-as-judge, check for hallucinations

### Issue: Loss Doesn't Decrease
- **Cause**: Learning rate too high/low, data formatting issues
- **Solution**: Adjust learning rate, verify tokenization and masking

## Best Practices

1. **Start small**: Fine-tune on a subset first to verify your pipeline works
2. **Monitor both losses**: Training AND validation loss tell different stories
3. **Evaluate qualitatively**: Don't trust loss alone for instruction tasks
4. **Use early stopping**: Prevent overfitting by watching validation loss
5. **Test on diverse prompts**: Ensure generalization beyond training distribution

## References

- [Build a Large Language Model from Scratch](https://www.manning.com/books/build-a-large-language-model-from-scratch)
- [LLMs-from-scratch - Instruction Fine-Tuning Code](https://github.com/rasbt/LLMs-from-scratch/blob/main/ch07/01_main-chapter-code/gpt_instruction_finetuning.py)
