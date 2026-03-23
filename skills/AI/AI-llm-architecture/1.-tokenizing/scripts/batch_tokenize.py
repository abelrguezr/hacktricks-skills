#!/usr/bin/env python3
"""
Batch tokenize multiple text files.
Usage: python batch_tokenize.py <input_dir> <output_dir>
"""

import argparse
import json
import os
import tiktoken
from pathlib import Path

def tokenize_file(file_path: Path, encoding) -> dict:
    """Tokenize a single file and return results."""
    with open(file_path, "r", encoding="utf-8") as f:
        text = f.read()
    
    token_ids = encoding.encode(text)
    
    return {
        "filename": file_path.name,
        "char_count": len(text),
        "token_count": len(token_ids),
        "avg_chars_per_token": len(text) / len(token_ids) if token_ids else 0,
        "first_10_tokens": token_ids[:10],
        "last_10_tokens": token_ids[-10:] if len(token_ids) > 10 else token_ids
    }

def main():
    parser = argparse.ArgumentParser(description="Batch tokenize text files")
    parser.add_argument("input_dir", help="Directory containing text files")
    parser.add_argument("output_dir", help="Directory to save tokenized results")
    parser.add_argument("--encoding", default="gpt2", help="Tokenizer encoding")
    
    args = parser.parse_args()
    
    # Create output directory
    output_path = Path(args.output_dir)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Load tokenizer
    encoding = tiktoken.get_encoding(args.encoding)
    
    # Process all .txt files
    input_path = Path(args.input_dir)
    text_files = list(input_path.glob("*.txt"))
    
    if not text_files:
        print(f"No .txt files found in {args.input_dir}")
        return
    
    results = []
    total_chars = 0
    total_tokens = 0
    
    for file_path in text_files:
        print(f"Processing: {file_path.name}")
        result = tokenize_file(file_path, encoding)
        results.append(result)
        total_chars += result["char_count"]
        total_tokens += result["token_count"]
    
    # Save individual results
    for result in results:
        output_file = output_path / f"{result['filename']}.json"
        with open(output_file, "w", encoding="utf-8") as f:
            json.dump(result, f, indent=2)
    
    # Save summary
    summary = {
        "total_files": len(results),
        "total_chars": total_chars,
        "total_tokens": total_tokens,
        "avg_chars_per_token": total_chars / total_tokens if total_tokens else 0,
        "files": [r["filename"] for r in results]
    }
    
    summary_file = output_path / "summary.json"
    with open(summary_file, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)
    
    print(f"\nSummary:")
    print(f"  Files processed: {len(results)}")
    print(f"  Total characters: {total_chars}")
    print(f"  Total tokens: {total_tokens}")
    print(f"  Avg chars/token: {summary['avg_chars_per_token']:.2f}")
    print(f"\nResults saved to: {output_path}")

if __name__ == "__main__":
    main()
