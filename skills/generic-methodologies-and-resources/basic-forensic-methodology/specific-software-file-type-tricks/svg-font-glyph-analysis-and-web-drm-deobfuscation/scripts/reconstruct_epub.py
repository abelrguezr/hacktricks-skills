#!/usr/bin/env python3
"""Reconstruct layout from decoded text runs.

Converts decoded runs to HTML/EPUB with preserved styling
and layout information.
"""

import argparse
import os
import json
from collections import defaultdict


def infer_paragraph_break(prev_run, curr_run, threshold_mult=1.5):
    """Detect paragraph break based on Y position."""
    if not prev_run or not curr_run:
        return True
    
    prev_rect = prev_run.get('rect', {})
    curr_rect = curr_run.get('rect', {})
    
    prev_bottom = prev_rect.get('bottom', 0)
    curr_top = curr_rect.get('top', 0)
    font_size = prev_run.get('fontSize', 12)
    
    y_delta = curr_top - prev_bottom
    threshold = font_size * threshold_mult
    
    return y_delta > threshold


def infer_alignment(runs: list) -> str:
    """Infer paragraph alignment from run positions."""
    if not runs:
        return 'left'
    
    lefts = [r.get('rect', {}).get('left', 0) for r in runs]
    rights = [r.get('rect', {}).get('right', 0) for r in runs]
    
    left_std = max(lefts) - min(lefts) if lefts else 0
    right_std = max(rights) - min(rights) if rights else 0
    
    if left_std < 20 and right_std < 20:
        # Both edges aligned - could be centered
        avg_left = sum(lefts) / len(lefts)
        if avg_left > 100:  # Not flush left
            return 'center'
    elif right_std < 20:
        return 'right'
    
    return 'left'


def get_css_class(run: dict) -> str:
    """Generate CSS class from run styling."""
    parts = []
    
    if run.get('fontStyle') == 'italic':
        parts.append('italic')
    if run.get('fontWeight', 400) >= 700:
        parts.append('bold')
    
    font_size = run.get('fontSize', 12)
    if font_size >= 18:
        parts.append('heading')
    elif font_size >= 14:
        parts.append('subheading')
    else:
        parts.append('body')
    
    return '-'.join(parts) if parts else 'body'


def reconstruct_html(runs: list, output_path: str):
    """Reconstruct HTML from text runs."""
    paragraphs = []
    current_para = []
    
    for i, run in enumerate(runs):
        if infer_paragraph_break(runs[i-1] if i > 0 else None, run):
            if current_para:
                paragraphs.append(current_para)
            current_para = [run]
        else:
            current_para.append(run)
    
    if current_para:
        paragraphs.append(current_para)
    
    # Build HTML
    html_parts = [
        '<!DOCTYPE html>',
        '<html lang="en">',
        '<head>',
        '<meta charset="UTF-8">',
        '<title>Reconstructed Text</title>',
        '<style>',
        'body { font-family: Georgia, serif; max-width: 800px; margin: 0 auto; padding: 20px; }',
        '.heading { font-size: 1.5em; font-weight: bold; margin: 1em 0; }',
        '.subheading { font-size: 1.2em; font-weight: bold; margin: 0.8em 0; }',
        '.italic { font-style: italic; }',
        '.bold { font-weight: bold; }',
        '.center { text-align: center; }',
        '.right { text-align: right; }',
        '</style>',
        '</head>',
        '<body>'
    ]
    
    for para in paragraphs:
        alignment = infer_alignment(para)
        para_class = f'para {alignment}' if alignment != 'left' else 'para'
        
        html_parts.append(f'<p class="{para_class}">')
        for run in para:
            css_class = get_css_class(run)
            text = run.get('text', '')
            if text:
                html_parts.append(f'<span class="{css_class}">{text}</span>')
        html_parts.append('</p>')
    
    html_parts.extend(['</body>', '</html>'])
    
    with open(output_path, 'w') as f:
        f.write('\n'.join(html_parts))
    
    print(f"HTML saved to {output_path}")


def main():
    parser = argparse.ArgumentParser(description='Reconstruct layout from decoded runs')
    parser.add_argument('--runs', required=True, help='Path to decoded_runs.json')
    parser.add_argument('--output', required=True, help='Output HTML path')
    args = parser.parse_args()
    
    with open(args.runs, 'r') as f:
        runs = json.load(f)
    
    reconstruct_html(runs, args.output)


if __name__ == '__main__':
    main()
