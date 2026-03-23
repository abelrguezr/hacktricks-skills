#!/usr/bin/env python3
"""
Evaluate fine-tuned LLM responses.

Supports:
- Manual review preparation
- LLM-as-judge evaluation
- Basic metrics (length, format compliance)
"""

import json
import argparse
from pathlib import Path
from typing import List, Dict, Any, Optional
from datetime import datetime


def load_responses(filepath: str) -> List[Dict[str, Any]]:
    """
    Load generated responses from JSON file.
    
    Expected format:
    [
        {
            "instruction": "...",
            "expected_response": "...",
            "generated_response": "..."
        },
        ...
    ]
    """
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)


def check_format_compliance(
    response: str,
    style: str = 'alpaca'
) -> Dict[str, bool]:
    """
    Check if response follows expected format.
    
    Args:
        response: The generated response
        style: 'alpaca' or 'phi3'
    
    Returns:
        Dictionary with format compliance checks
    """
    checks = {}
    
    if style == 'alpaca':
        checks['has_response_marker'] = '### Response:' in response
        checks['has_content_after_marker'] = len(response.split('### Response:')[-1].strip()) > 0
    elif style == 'phi3':
        checks['has_assistant_marker'] = '<|Assistant|>' in response
        checks['has_content_after_marker'] = len(response.split('<|Assistant|>')[-1].strip()) > 0
    
    checks['non_empty'] = len(response.strip()) > 0
    checks['reasonable_length'] = 10 < len(response) < 10000
    
    return checks


def calculate_basic_metrics(responses: List[Dict[str, Any]]) -> Dict[str, float]:
    """
    Calculate basic metrics on responses.
    
    Args:
        responses: List of response dictionaries
    
    Returns:
        Dictionary with metrics
    """
    if not responses:
        return {}
    
    lengths = [len(r.get('generated_response', '')) for r in responses]
    
    return {
        'total_responses': len(responses),
        'avg_length': sum(lengths) / len(lengths),
        'min_length': min(lengths),
        'max_length': max(lengths),
        'non_empty_ratio': sum(1 for l in lengths if l > 0) / len(lengths)
    }


def prepare_review_file(
    responses: List[Dict[str, Any]],
    output_path: str
) -> None:
    """
    Prepare a review file for manual evaluation.
    
    Creates a JSON file with side-by-side comparison of expected vs generated.
    """
    review_data = []
    
    for i, r in enumerate(responses):
        review_entry = {
            'id': i,
            'instruction': r.get('instruction', ''),
            'expected_response': r.get('expected_response', ''),
            'generated_response': r.get('generated_response', ''),
            'format_checks': check_format_compliance(
                r.get('generated_response', ''),
                style='alpaca'  # Default, can be parameterized
            ),
            'review_notes': ''  # For manual annotation
        }
        review_data.append(review_entry)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(review_data, f, indent=2)
    
    print(f"Review file saved to {output_path}")


def create_llm_judge_prompt(
    instruction: str,
    expected_response: str,
    generated_response: str
) -> str:
    """
    Create a prompt for LLM-as-judge evaluation.
    
    Args:
        instruction: The original instruction
        expected_response: The expected/correct response
        generated_response: The model's generated response
    
    Returns:
        Prompt for judge LLM
    """
    return f"""You are an expert evaluator. Compare the generated response to the expected response.

Instruction: {instruction}

Expected Response:
{expected_response}

Generated Response:
{generated_response}

Please evaluate the generated response on the following criteria (rate 1-5):
1. Correctness: Is the information accurate?
2. Completeness: Does it answer the full instruction?
3. Clarity: Is it well-written and easy to understand?
4. Helpfulness: Would this be useful to the user?

Also note any specific issues or hallucinations.

Provide your evaluation in JSON format:
{{
  "correctness_score": <1-5>,
  "completeness_score": <1-5>,
  "clarity_score": <1-5>,
  "helpfulness_score": <1-5>,
  "overall_score": <1-5>,
  "issues": ["list of specific issues"],
  "summary": "brief summary of evaluation"
}}
"""


def main():
    parser = argparse.ArgumentParser(
        description='Evaluate fine-tuned LLM responses'
    )
    parser.add_argument(
        'responses_file',
        help='Path to JSON file with generated responses'
    )
    parser.add_argument(
        '-o', '--output_dir',
        default='evaluation_results',
        help='Output directory for evaluation results'
    )
    parser.add_argument(
        '--prepare-review',
        action='store_true',
        help='Prepare file for manual review'
    )
    parser.add_argument(
        '--metrics-only',
        action='store_true',
        help='Only calculate basic metrics'
    )
    parser.add_argument(
        '--create-judge-prompts',
        action='store_true',
        help='Create prompts for LLM-as-judge evaluation'
    )
    
    args = parser.parse_args()
    
    # Load responses
    print(f"Loading responses from {args.responses_file}...")
    responses = load_responses(args.responses_file)
    print(f"Loaded {len(responses)} responses")
    
    # Create output directory
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    # Calculate basic metrics
    metrics = calculate_basic_metrics(responses)
    metrics_file = output_dir / 'basic_metrics.json'
    
    with open(metrics_file, 'w', encoding='utf-8') as f:
        json.dump(metrics, f, indent=2)
    
    print(f"\nBasic Metrics:")
    for key, value in metrics.items():
        print(f"  {key}: {value}")
    
    if args.metrics_only:
        print(f"\nMetrics saved to {metrics_file}")
        return
    
    if args.prepare_review:
        review_file = output_dir / 'manual_review.json'
        prepare_review_file(responses, str(review_file))
    
    if args.create_judge_prompts:
        judge_prompts = []
        for i, r in enumerate(responses):
            prompt = create_llm_judge_prompt(
                r.get('instruction', ''),
                r.get('expected_response', ''),
                r.get('generated_response', '')
            )
            judge_prompts.append({
                'id': i,
                'prompt': prompt
            })
        
        prompts_file = output_dir / 'judge_prompts.json'
        with open(prompts_file, 'w', encoding='utf-8') as f:
            json.dump(judge_prompts, f, indent=2)
        
        print(f"\nJudge prompts saved to {prompts_file}")
    
    print(f"\nEvaluation complete. Results in {output_dir}")


if __name__ == '__main__':
    main()
