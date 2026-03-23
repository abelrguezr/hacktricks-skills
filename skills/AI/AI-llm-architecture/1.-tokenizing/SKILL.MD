---
name: text-tokenizer
description: How to tokenize text for LLMs and NLP models. Use this skill whenever the user needs to convert text into token IDs, understand tokenization methods (BPE, WordPiece, Unigram), work with vocabularies, or implement tokenization for machine learning. Make sure to use this skill when users mention tokenizing, token IDs, vocabulary creation, BPE, WordPiece, or any text preprocessing for ML models.
---

# Text Tokenizer

A skill for tokenizing text into numerical IDs for machine learning models.

## What is Tokenizing?

Tokenizing is the process of breaking down text into smaller pieces called tokens, each assigned a unique numerical ID. This is fundamental for preparing text for ML models, especially in NLP.

**Goal:** Divide input into tokens (IDs) in a way that makes sense for the model.

## Basic Tokenization

### 1. Splitting Text
- Simple tokenizer splits text into words and punctuation
- Example: `"Hello, world!"` → `["Hello", ",", "world", "!"]`

### 2. Creating a Vocabulary
- Maps each token to a numerical ID
- **Special tokens:**
  - `[BOS]` (Beginning of Sequence): Marks text start
  - `[EOS]` (End of Sequence): Marks text end
  - `[PAD]` (Padding): Makes sequences same length in batches
  - `[UNK]` (Unknown): Represents tokens not in vocabulary
- Example: `"Hello, world!"` → `[64, 455, 78, 467]`

### 3. Handling Unknown Words
- Words not in vocabulary get replaced with `[UNK]`
- Example: `"Bye, world!"` → `[987, 455, 78, 467]` (assuming `[UNK]` = 987)

## Advanced Tokenization Methods

### Byte Pair Encoding (BPE)
- **Purpose:** Reduces vocabulary size, handles rare/unknown words
- **How it works:**
  - Starts with individual characters as tokens
  - Iteratively merges most frequent token pairs
  - Continues until no more frequent pairs exist
- **Benefits:**
  - Eliminates need for `[UNK]` token
  - More efficient and flexible vocabulary
- **Example:** `"playing"` → `["play", "ing"]`

### WordPiece
- **Used by:** BERT and similar models
- **Purpose:** Similar to BPE, breaks words into subword units
- **How it works:**
  - Begins with base vocabulary of individual characters
  - Iteratively adds most frequent subword that maximizes training data likelihood
  - Uses probabilistic model for merging decisions
- **Benefits:**
  - Balances vocabulary size with word representation
  - Efficiently handles rare and compound words
- **Example:** `"unhappiness"` → `["un", "happy", "ness"]`

### Unigram Language Model
- **Used by:** SentencePiece
- **Purpose:** Uses probabilistic model for optimal subword selection
- **How it works:**
  - Starts with large set of potential tokens
  - Iteratively removes tokens that least improve model probability
  - Finalizes vocabulary with most probable subword units
- **Benefits:**
  - Flexible and natural language modeling
  - Often results in more efficient tokenizations
- **Example:** `"internationalization"` → `["international", "ization"]`

## Implementation with tiktoken

### Basic Usage

```python
import tiktoken

# Load GPT-2 tokenizer
encoding = tiktoken.get_encoding("gpt2")

# Encode text to token IDs
token_ids = encoding.encode("Hello, world!")
print(token_ids)  # [15496, 11, 995, 0]

# Decode token IDs back to text
text = encoding.decode(token_ids)
print(text)  # "Hello, world!"
```

### With Special Tokens

```python
# Encode with special tokens allowed
token_ids = encoding.encode("Hello, world!", allowed_special={"[EOS]"})

# Check token count
print(len(token_ids))
```

### Processing Files

```python
import urllib.request

# Download text file
url = "https://raw.githubusercontent.com/rasbt/LLMs-from-scratch/main/ch02/01_main-chapter-code/the-verdict.txt"
file_path = "the-verdict.txt"
urllib.request.urlretrieve(url, file_path)

# Read and tokenize
with open(file_path, "r", encoding="utf-8") as f:
    raw_text = f.read()

token_ids = tiktoken.get_encoding("gpt2").encode(raw_text, allowed_special={"[EOS]"})

# Print first 50 tokens
print(token_ids[:50])
```

## Common Use Cases

1. **Preprocessing text for training** - Convert training data to token IDs
2. **Understanding model input requirements** - Know what format your model expects
3. **Debugging tokenization issues** - Inspect how text is being tokenized
4. **Comparing different tokenization methods** - Evaluate BPE vs WordPiece vs Unigram

## Best Practices

- **Choose tokenizer based on your model** - GPT-2 uses BPE, BERT uses WordPiece
- **Handle special tokens appropriately** - Include `[BOS]`, `[EOS]` as needed for your use case
- **Consider vocabulary size vs. tokenization quality tradeoff** - Larger vocabularies may tokenize more efficiently but use more memory
- **Test with edge cases** - Rare words, special characters, different languages
- **Use the right encoding** - Match the tokenizer to your model architecture

## Troubleshooting

### Unknown tokens appearing
- Check if your vocabulary is large enough
- Consider using BPE or WordPiece instead of basic tokenization
- Verify special tokens are properly configured

### Token count seems too high
- Try a different tokenization method (BPE often produces fewer tokens)
- Check if you're including unnecessary whitespace or special characters

### Decoding produces unexpected output
- Ensure you're using the same encoding for encode/decode
- Check if special tokens are being handled correctly
- Verify the token IDs are valid for your vocabulary

## References

- [Build a Large Language Model from Scratch](https://www.manning.com/books/build-a-large-language-model-from-scratch)
- [LLMs from Scratch - Tokenization](https://github.com/rasbt/LLMs-from-scratch/blob/main/ch02/01_main-chapter-code/ch02.ipynb)
