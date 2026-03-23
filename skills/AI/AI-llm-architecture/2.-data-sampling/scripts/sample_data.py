#!/usr/bin/env python3
"""
LLM Data Sampling Script

Prepares text data for training large language models by:
- Tokenizing text into sequences
- Creating input/target pairs using sliding windows
- Applying advanced sampling strategies (temperature weighting, deduplication)
- Generating PyTorch-compatible datasets

Usage:
    python sample_data.py --input data/ --output processed/ --max-length 256 --stride 128
"""

import argparse
import json
import os
import hashlib
import glob
from pathlib import Path
from collections import Counter
from typing import List, Dict, Tuple, Optional
import torch
from torch.utils.data import Dataset, DataLoader

try:
    import tiktoken
    TIKTOKEN_AVAILABLE = True
except ImportError:
    TIKTOKEN_AVAILABLE = False
    print("Warning: tiktoken not available. Using basic tokenization.")


class BasicTokenizer:
    """Simple whitespace-based tokenizer when tiktoken is unavailable."""
    
    def __init__(self):
        self.vocab = {}
        self.id_to_token = {}
    
    def encode(self, text: str, allowed_special: set = None) -> List[int]:
        """Encode text to token IDs."""
        tokens = text.split()
        return [hash(t) % 100000 for t in tokens]
    
    def decode(self, token_ids: List[int]) -> str:
        """Decode token IDs to text."""
        return " ".join([str(t) for t in token_ids])


class GPTDatasetV1(Dataset):
    """
    PyTorch Dataset for LLM training.
    
    Creates input/target pairs using sliding window approach.
    Target is input shifted by 1 token (for next-token prediction).
    """
    
    def __init__(self, txt: str, tokenizer, max_length: int, stride: int):
        self.input_ids = []
        self.target_ids = []
        
        # Tokenize the entire text
        if TIKTOKEN_AVAILABLE:
            tokenizer = tiktoken.get_encoding("gpt2")
        else:
            tokenizer = BasicTokenizer()
        
        token_ids = tokenizer.encode(txt, allowed_special={"<|endoftext|>"})
        
        # Use sliding window to chunk into overlapping sequences
        for i in range(0, len(token_ids) - max_length, stride):
            input_chunk = token_ids[i:i + max_length]
            target_chunk = token_ids[i + 1: i + max_length + 1]
            self.input_ids.append(torch.tensor(input_chunk))
            self.target_ids.append(torch.tensor(target_chunk))
    
    def __len__(self):
        return len(self.input_ids)
    
    def __getitem__(self, idx):
        return self.input_ids[idx], self.target_ids[idx]


def temperature_sample(corpus_ids: List[str], alpha: float = 0.7) -> Dict[str, float]:
    """
    Apply temperature-based sampling weights to corpus proportions.
    
    Args:
        corpus_ids: List of corpus identifiers (one per document/token)
        alpha: Temperature parameter (0 < alpha <= 1). Lower = flatter distribution.
    
    Returns:
        Dictionary mapping corpus_id to sampling probability
    """
    counts = Counter(corpus_ids)
    probs = {c: c_count ** alpha for c, c_count in counts.items()}
    Z = sum(probs.values())
    return {c: p / Z for c, p in probs.items()}


def deduplicate_sequences(sequences: List[List[int]], ngram_size: int = 8) -> List[List[int]]:
    """
    Remove near-duplicate sequences using n-gram hashing.
    
    Args:
        sequences: List of token sequences
        ngram_size: Size of n-grams for deduplication
    
    Returns:
        Deduplicated list of sequences
    """
    seen_hashes = set()
    unique_sequences = []
    
    for seq in sequences:
        # Create n-gram hashes for this sequence
        ngrams = []
        for i in range(len(seq) - ngram_size + 1):
            ngram = tuple(seq[i:i + ngram_size])
            ngrams.append(hash(ngram))
        
        # Check if any n-gram has been seen
        if not any(h in seen_hashes for h in ngrams):
            unique_sequences.append(seq)
            seen_hashes.update(ngrams)
    
    return unique_sequences


def compute_file_hash(filepath: str) -> str:
    """Compute SHA-256 hash of a file for versioning."""
    sha256 = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            sha256.update(chunk)
    return sha256.hexdigest()


def load_text_files(input_path: str) -> List[Tuple[str, str]]:
    """
    Load text files from input path.
    
    Args:
        input_path: File or directory path
    
    Returns:
        List of (corpus_id, text) tuples
    """
    texts = []
    
    if os.path.isfile(input_path):
        with open(input_path, "r", encoding="utf-8") as f:
            text = f.read()
        corpus_id = os.path.basename(input_path)
        texts.append((corpus_id, text))
    else:
        # Load all text files from directory
        for ext in ["*.txt", "*.md", "*.jsonl"]:
            for filepath in glob.glob(os.path.join(input_path, f"**/{ext}"), recursive=True):
                with open(filepath, "r", encoding="utf-8") as f:
                    text = f.read()
                corpus_id = os.path.relpath(filepath, input_path)
                texts.append((corpus_id, text))
    
    return texts


def create_dataloader(
    txt: str,
    batch_size: int = 4,
    max_length: int = 256,
    stride: int = 128,
    shuffle: bool = True,
    drop_last: bool = True,
    num_workers: int = 0
) -> DataLoader:
    """
    Create a PyTorch DataLoader for LLM training.
    
    Args:
        txt: Raw text to tokenize and sample
        batch_size: Number of samples per batch
        max_length: Maximum sequence length in tokens
        stride: Sliding window step size
        shuffle: Whether to shuffle the dataset
        drop_last: Whether to drop incomplete final batch
        num_workers: Number of data loading workers
    
    Returns:
        PyTorch DataLoader
    """
    if TIKTOKEN_AVAILABLE:
        tokenizer = tiktoken.get_encoding("gpt2")
    else:
        tokenizer = BasicTokenizer()
    
    dataset = GPTDatasetV1(txt, tokenizer, max_length, stride)
    
    dataloader = DataLoader(
        dataset,
        batch_size=batch_size,
        shuffle=shuffle,
        drop_last=drop_last,
        num_workers=num_workers
    )
    
    return dataloader


def sample_data(
    input_path: str,
    output_path: str,
    max_length: int = 256,
    stride: int = 128,
    batch_size: int = 8,
    temperature: float = 1.0,
    deduplicate: bool = False,
    shuffle: bool = True,
    ngram_size: int = 8
) -> Dict:
    """
    Main data sampling function.
    
    Args:
        input_path: Path to input text file(s)
        output_path: Path for output JSONL file
        max_length: Maximum sequence length
        stride: Sliding window stride
        batch_size: Batch size for dataloader
        temperature: Temperature for corpus weighting (alpha)
        deduplicate: Whether to remove duplicate sequences
        shuffle: Whether to shuffle data
        ngram_size: N-gram size for deduplication
    
    Returns:
        Statistics dictionary
    """
    # Load input texts
    texts = load_text_files(input_path)
    
    if not texts:
        raise ValueError(f"No text files found at {input_path}")
    
    # Apply temperature weighting if multiple corpora
    corpus_ids = [corpus_id for corpus_id, _ in texts]
    if len(texts) > 1 and temperature < 1.0:
        weights = temperature_sample(corpus_ids, alpha=temperature)
        print(f"Corpus weights (alpha={temperature}): {weights}")
    
    # Process each text file
    all_sequences = []
    all_targets = []
    corpus_stats = {}
    
    for corpus_id, text in texts:
        # Create dataloader for this corpus
        dataloader = create_dataloader(
            txt=text,
            batch_size=batch_size,
            max_length=max_length,
            stride=stride,
            shuffle=False  # Don't shuffle during sampling
        )
        
        corpus_sequences = []
        corpus_targets = []
        
        for batch_input, batch_target in dataloader:
            for i in range(len(batch_input)):
                corpus_sequences.append(batch_input[i].tolist())
                corpus_targets.append(batch_target[i].tolist())
        
        # Deduplicate if requested
        if deduplicate:
            corpus_sequences = deduplicate_sequences(corpus_sequences, ngram_size)
            # Keep targets aligned with deduplicated sequences
            corpus_targets = corpus_targets[:len(corpus_sequences)]
        
        all_sequences.extend(corpus_sequences)
        all_targets.extend(corpus_targets)
        corpus_stats[corpus_id] = {
            "sequences": len(corpus_sequences),
            "original_sequences": len([b for b in dataloader] * batch_size)
        }
    
    # Write output
    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    
    with open(output_path, "w", encoding="utf-8") as f:
        for seq, target in zip(all_sequences, all_targets):
            record = {
                "input": seq,
                "target": target,
                "max_length": max_length,
                "stride": stride
            }
            f.write(json.dumps(record) + "\n")
    
    # Compute file hash for versioning
    file_hash = compute_file_hash(output_path)
    
    stats = {
        "total_sequences": len(all_sequences),
        "corpus_stats": corpus_stats,
        "output_file": output_path,
        "file_hash": file_hash,
        "parameters": {
            "max_length": max_length,
            "stride": stride,
            "batch_size": batch_size,
            "temperature": temperature,
            "deduplicate": deduplicate,
            "shuffle": shuffle
        }
    }
    
    return stats


def main():
    parser = argparse.ArgumentParser(
        description="Sample text data for LLM training",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic sampling
  python sample_data.py --input data.txt --output sampled.jsonl
  
  # With custom parameters
  python sample_data.py --input data/ --output processed/ --max-length 512 --stride 256
  
  # With deduplication and temperature weighting
  python sample_data.py --input corpus/ --output processed/ --deduplicate --temperature 0.7
        """
    )
    
    parser.add_argument("--input", required=True, help="Input text file or directory")
    parser.add_argument("--output", required=True, help="Output JSONL file path")
    parser.add_argument("--max-length", type=int, default=256, help="Maximum sequence length (default: 256)")
    parser.add_argument("--stride", type=int, default=128, help="Sliding window stride (default: 128)")
    parser.add_argument("--batch-size", type=int, default=8, help="Batch size (default: 8)")
    parser.add_argument("--temperature", type=float, default=1.0, help="Temperature for corpus weighting (default: 1.0)")
    parser.add_argument("--deduplicate", action="store_true", help="Remove duplicate sequences")
    parser.add_argument("--shuffle", action="store_true", help="Shuffle data")
    parser.add_argument("--ngram-size", type=int, default=8, help="N-gram size for deduplication (default: 8)")
    
    args = parser.parse_args()
    
    print(f"Loading data from: {args.input}")
    print(f"Parameters: max_length={args.max_length}, stride={args.stride}, batch_size={args.batch_size}")
    
    stats = sample_data(
        input_path=args.input,
        output_path=args.output,
        max_length=args.max_length,
        stride=args.stride,
        batch_size=args.batch_size,
        temperature=args.temperature,
        deduplicate=args.deduplicate,
        shuffle=args.shuffle,
        ngram_size=args.ngram_size
    )
    
    print(f"\nSampling complete!")
    print(f"Total sequences: {stats['total_sequences']}")
    print(f"Output file: {stats['output_file']}")
    print(f"File hash: {stats['file_hash']}")
    
    # Save stats
    stats_file = args.output.replace(".jsonl", "_stats.json")
    with open(stats_file, "w") as f:
        json.dump(stats, f, indent=2)
    print(f"Stats saved to: {stats_file}")


if __name__ == "__main__":
    main()
