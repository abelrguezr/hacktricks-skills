#!/usr/bin/env python3
"""
Trace Analysis Helper Script

Basic visualization and preprocessing for side-channel traces.
Supports alignment, filtering, and statistical analysis.

Usage:
    python trace_analysis.py --traces traces.npy --plot
    python trace_analysis.py --traces traces.npy --filter lowpass --cutoff 100000
    python trace_analysis.py --traces traces.npy --align --reference 0
"""

import numpy as np
import argparse
from pathlib import Path
from typing import Optional, Tuple
import warnings
warnings.filterwarnings('ignore')

try:
    import matplotlib.pyplot as plt
    HAS_MATPLOTLIB = True
except ImportError:
    HAS_MATPLOTLIB = False
    print("Warning: matplotlib not available. Plotting disabled.")


def load_traces(traces_path: str) -> np.ndarray:
    """Load traces from numpy file."""
    traces = np.load(traces_path)
    print(f"Loaded {traces.shape[0]} traces with {traces.shape[1]} samples each")
    return traces


def mean_removal(traces: np.ndarray) -> np.ndarray:
    """Remove mean from each trace."""
    return traces - np.mean(traces, axis=1, keepdims=True)


def lowpass_filter(traces: np.ndarray, cutoff_hz: float, sample_rate_hz: float = 1e6) -> np.ndarray:
    """Apply simple low-pass filter using moving average."""
    # Calculate filter window size
    window_size = int(sample_rate_hz / (2 * cutoff_hz))
    window_size = max(3, window_size)  # Minimum window of 3
    
    # Apply moving average
    kernel = np.ones(window_size) / window_size
    filtered = np.apply_along_axis(lambda x: np.convolve(x, kernel, mode='same'), 1, traces)
    return filtered


def highpass_filter(traces: np.ndarray, cutoff_hz: float, sample_rate_hz: float = 1e6) -> np.ndarray:
    """Apply simple high-pass filter by subtracting low-pass."""
    lowpass = lowpass_filter(traces, cutoff_hz, sample_rate_hz)
    return traces - lowpass


def align_traces(traces: np.ndarray, reference_idx: int = 0) -> np.ndarray:
    """Align traces to reference using cross-correlation."""
    reference = traces[reference_idx]
    aligned = np.zeros_like(traces)
    aligned[reference_idx] = reference
    
    for i in range(traces.shape[0]):
        if i == reference_idx:
            continue
        
        # Compute cross-correlation
        corr = np.correlate(traces[i] - np.mean(traces[i]), reference - np.mean(reference), mode='full')
        lag = np.argmax(corr) - (len(reference) - 1)
        
        # Shift trace
        if lag > 0:
            aligned[i] = np.roll(traces[i], -lag)
        elif lag < 0:
            aligned[i] = np.roll(traces[i], -lag)
        else:
            aligned[i] = traces[i]
    
    return aligned


def compute_statistics(traces: np.ndarray) -> dict:
    """Compute basic statistics on traces."""
    return {
        "num_traces": int(traces.shape[0]),
        "num_samples": int(traces.shape[1]),
        "mean_amplitude": float(np.mean(traces)),
        "std_amplitude": float(np.std(traces)),
        "min_amplitude": float(np.min(traces)),
        "max_amplitude": float(np.max(traces)),
        "mean_per_trace": np.mean(traces, axis=1).tolist(),
        "std_per_trace": np.std(traces, axis=1).tolist()
    }


def find_leakage_points(traces: np.ndarray, top_k: int = 10) -> list:
    """Find sample points with highest variance (potential leakage)."""
    variance_per_sample = np.var(traces, axis=0)
    top_indices = np.argsort(variance_per_sample)[::-1][:top_k]
    return [
        {
            "sample_index": int(idx),
            "variance": float(variance_per_sample[idx])
        }
        for idx in top_indices
    ]


def plot_traces(traces: np.ndarray, output_path: str = "traces.png", num_traces: int = 10):
    """Plot sample traces."""
    if not HAS_MATPLOTLIB:
        print("matplotlib not available, skipping plot")
        return
    
    plt.figure(figsize=(12, 6))
    
    # Plot subset of traces
    for i in range(min(num_traces, traces.shape[0])):
        plt.plot(traces[i], alpha=0.3, linewidth=0.5)
    
    # Plot mean trace
    plt.plot(np.mean(traces, axis=0), 'r', linewidth=2, label='Mean')
    
    plt.xlabel('Sample')
    plt.ylabel('Amplitude')
    plt.title(f'Sample Traces (showing {num_traces} of {traces.shape[0]})')
    plt.legend()
    plt.grid(True, alpha=0.3)
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    print(f"Plot saved to {output_path}")


def plot_variance(traces: np.ndarray, output_path: str = "variance.png"):
    """Plot variance per sample point."""
    if not HAS_MATPLOTLIB:
        print("matplotlib not available, skipping plot")
        return
    
    variance = np.var(traces, axis=0)
    
    plt.figure(figsize=(12, 4))
    plt.plot(variance)
    plt.xlabel('Sample')
    plt.ylabel('Variance')
    plt.title('Variance per Sample Point (high variance = potential leakage)')
    plt.grid(True, alpha=0.3)
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    print(f"Variance plot saved to {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Side-Channel Trace Analysis")
    parser.add_argument("--traces", type=str, required=True, help="Path to traces numpy file")
    parser.add_argument("--plot", action="store_true", help="Generate trace plots")
    parser.add_argument("--filter", type=str, choices=['lowpass', 'highpass'], help="Apply filter")
    parser.add_argument("--cutoff", type=float, default=100000, help="Filter cutoff frequency (Hz)")
    parser.add_argument("--align", action="store_true", help="Align traces to reference")
    parser.add_argument("--reference", type=int, default=0, help="Reference trace index for alignment")
    parser.add_argument("--mean-removal", action="store_true", help="Remove mean from traces")
    parser.add_argument("--stats", action="store_true", help="Print statistics")
    parser.add_argument("--leakage-points", type=int, default=0, help="Find top N leakage points")
    parser.add_argument("--output", type=str, default="processed_traces.npy", help="Output file for processed traces")
    
    args = parser.parse_args()
    
    # Load traces
    traces = load_traces(args.traces)
    
    # Apply processing
    if args.mean_removal:
        print("Applying mean removal...")
        traces = mean_removal(traces)
    
    if args.align:
        print(f"Aligning traces to reference {args.reference}...")
        traces = align_traces(traces, args.reference)
    
    if args.filter:
        print(f"Applying {args.filter} filter with cutoff {args.cutoff} Hz...")
        if args.filter == 'lowpass':
            traces = lowpass_filter(traces, args.cutoff)
        else:
            traces = highpass_filter(traces, args.cutoff)
    
    # Generate outputs
    if args.stats:
        stats = compute_statistics(traces)
        print("\nTrace Statistics:")
        for key, value in stats.items():
            if key not in ['mean_per_trace', 'std_per_trace']:
                print(f"  {key}: {value}")
    
    if args.leakage_points > 0:
        leakage = find_leakage_points(traces, args.leakage_points)
        print(f"\nTop {args.leakage_points} Leakage Points:")
        for point in leakage:
            print(f"  Sample {point['sample_index']}: variance = {point['variance']:.6f}")
    
    if args.plot:
        plot_traces(traces, "traces.png")
        plot_variance(traces, "variance.png")
    
    # Save processed traces
    np.save(args.output, traces)
    print(f"\nProcessed traces saved to {args.output}")


if __name__ == "__main__":
    main()
