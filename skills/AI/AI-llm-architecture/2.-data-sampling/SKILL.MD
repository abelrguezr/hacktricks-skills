---
name: llm-data-sampling
description: How to prepare and sample text data for training large language models. Use this skill whenever the user mentions data preparation, tokenization, sliding windows, sequence generation, training data, LLM datasets, or needs to create input/target pairs for model training. This includes tasks like chunking text, creating dataloaders, applying sampling strategies, or optimizing training data quality.
---

# LLM Data Sampling

A skill for preparing and sampling text data for training large language models (LLMs). This covers tokenization, sequence generation, sliding windows, and advanced sampling strategies.

## When to Use This Skill

Use this skill when the user needs to:
- Prepare text data for LLM training
- Create input/target token sequences
- Implement sliding window sampling
- Apply advanced sampling strategies (temperature weighting, sequence packing, deduplication)
- Optimize training data quality and security
- Create PyTorch datasets and dataloaders for LLM training

## Core Concepts

### 1. Tokenization
Breaking text into smaller units (tokens) that the model processes. Common approaches:
- **Word-level**: Split by spaces
- **Subword-level**: BPE, WordPiece (used by GPT-2, BERT)
- **Character-level**: Individual characters

### 2. Sequence Length (max_length)
The number of tokens in each input sequence. Typical values:
- Small models: 256-512 tokens
- Medium models: 512-1024 tokens
- Large models: 1024-4096+ tokens

### 3. Sliding Window
A method to create overlapping input sequences by moving a window over tokenized text.

### 4. Stride
The number of tokens the sliding window moves forward. Key tradeoffs:
- **Stride = 1**: Maximum overlap, better context learning, higher overfitting risk
- **Stride = max_length**: No overlap, less redundancy, may miss dependencies
- **Stride = 2-4×max_length**: Recommended for most cases to balance context and efficiency

## Step-by-Step Data Sampling

### Basic Workflow

1. **Load and tokenize text**
2. **Apply sliding window** to create sequences
3. **Generate input/target pairs** (target is input shifted by 1 token)
4. **Create dataset and dataloader** for training

### Example: Creating Input/Target Sequences

Given text: `"Lorem ipsum dolor sit amet, consectetur adipiscing elit."`

With `max_length=4` and `stride=1`:

| Window | Input Sequence | Target Sequence |
|--------|----------------|------------------|
| 1 | ["Lorem", "ipsum", "dolor", "sit"] | ["ipsum", "dolor", "sit", "amet,"] |
| 2 | ["ipsum", "dolor", "sit", "amet,"] | ["dolor", "sit", "amet,", "consectetur"] |
| 3 | ["dolor", "sit", "amet,", "consectetur"] | ["sit", "amet,", "consectetur", "adipiscing"] |

## Implementation Guide

### Using the Sampling Script

The bundled script `scripts/sample_data.py` handles the complete data sampling pipeline:

```bash
# Basic usage
python scripts/sample_data.py \
  --input "path/to/text.txt" \
  --output "path/to/output.jsonl" \
  --max-length 256 \
  --stride 128 \
  --batch-size 8

# With advanced options
python scripts/sample_data.py \
  --input "data/" \
  --output "processed/" \
  --max-length 512 \
  --stride 512 \
  --temperature 0.7 \
  --deduplicate \
  --shuffle
```

### Key Parameters

| Parameter | Description | Recommended Value |
|-----------|-------------|-------------------|
| `max_length` | Sequence length in tokens | 256-1024 |
| `stride` | Window step size | ≥ max_length for most cases |
| `batch_size` | Samples per batch | 8-32 (depends on GPU) |
| `temperature` | Sampling temperature (α) | 0.7 for mixed corpora |
| `shuffle` | Randomize order | True for training |

## Advanced Sampling Strategies

### 1. Temperature-Based Mixture Weighting

When training on multiple data sources, use temperature weighting to balance corpus proportions:

```
p(i) = w_i^α / Σ(w_j^α)
```

- `w_i`: Raw token percentage of corpus i
- `α` (temperature): Value in (0,1]. Lower α flattens distribution, giving more weight to smaller high-quality corpora
- **Llama 2 used α = 0.7** and showed improved evaluation scores

**When to use**: Training on heterogeneous data (code, web, academic papers, forums)

### 2. Sequence Packing / Dynamic Batching

Concatenate multiple shorter sequences until exact `max_length` is reached, with attention masks to prevent cross-segment attention.

**Benefits**:
- 20-40% throughput improvement
- No gradient change
- Reduces padding waste

**Implementation**: Use HuggingFace `DataCollatorForLanguageModeling(pad_to_multiple_of=...)` or PyTorch `torchtext.experimental.agents.PackedBatch`

### 3. Deduplication & Quality Filtering

**Deduplication**:
- MinHash/FAISS near-duplicate detection at document and n-gram level
- Llama 2 removed ~15% of CommonCrawl using 8-gram MinHash
- Target duplicate ratio: ≤0.04

**Quality Filtering**:
- Remove documents with perplexity > µ + 3σ (noisy OCR, garbled HTML)
- Block PII and sensitive content using regex & NER
- Filter by source quality scores

## Security & Privacy Considerations

### Data Poisoning / Backdoor Attacks

**Risk**: Inserting <1% backdoored sentences can create hidden triggers

**Mitigations**:
1. **Shuffled mixing**: Ensure adjacent examples come from different sources
2. **Gradient similarity scoring**: Remove outliers with high gradient divergence
3. **Dataset versioning**: Freeze immutable tarballs, verify SHA-256 hashes

### Membership Inference & Memorization

**Risk**: Long overlap between samples increases memorization of rare strings (phone numbers, keys)

**Mitigations**:
1. **Use stride ≥ max_length** (except for <1B parameter models with scarce data)
2. **Random masking**: Mask 1-3 tokens per window during training
3. **OpenAI 2024 finding**: Raising stride from 1× to 4× max_length reduces verbatim leakage by ~50%

## Best Practices

### For Training Data Preparation

1. **Start with stride = max_length** for most cases
2. **Use stride = 1** only for small models (<1B params) with limited data
3. **Apply deduplication** before sampling (8-gram MinHash recommended)
4. **Filter low-quality documents** using perplexity thresholds
5. **Version your datasets** with SHA-256 hashes
6. **Shuffle across sources** to prevent gradient alignment attacks

### For Production Pipelines

1. **Use temperature weighting** (α=0.7) for mixed corpora
2. **Implement sequence packing** for 20-40% throughput gains
3. **Monitor duplicate ratios** (target ≤0.04)
4. **Apply PII filtering** before training
5. **Log sampling statistics** for reproducibility

## Common Issues & Solutions

| Issue | Solution |
|-------|----------|
| GPU memory wasted on padding | Use sequence packing with attention masks |
| Model overfitting to repeated patterns | Increase stride, apply deduplication |
| Slow training throughput | Use sequence packing, optimize batch size |
| Memorization of sensitive data | Increase stride, add random masking |
| Poor performance on knowledge tasks | Use temperature weighting (α=0.7) |

## References

- [Build a Large Language Model from Scratch (Manning, 2024)](https://www.manning.com/books/build-a-large-language-model-from-scratch)
- [Llama 2: Open Foundation and Fine-Tuned Chat Models (2023)](https://arxiv.org/abs/2307.09288)
- [PoisonGPT: Assessing Backdoor Vulnerabilities (BlackHat EU 2023)](https://arxiv.org/abs/2308.12364)
- [OpenAI Deduplicate Everything (2024)](https://openai.com/research/deduplicate-everything)

## Next Steps

After preparing your data:
1. Validate the sampled sequences with `scripts/validate_sampling.py`
2. Check for duplicates and quality issues
3. Create a training dataloader with appropriate batch size
4. Monitor for memorization during training
5. Adjust stride and temperature based on validation performance
