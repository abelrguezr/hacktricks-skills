#!/usr/bin/env python3
"""
Signal Analysis Tool for Radio Hacking

Analyzes captured radio signals to identify characteristics,
modulation types, and potential protocols.
"""

import argparse
import numpy as np
import json
from pathlib import Path
import sys


def load_signal(signal_file):
    """Load signal data from file."""
    path = Path(signal_file)
    
    if not path.exists():
        print(f"Error: Signal file '{signal_file}' not found")
        sys.exit(1)
    
    # Try to load as binary
    try:
        data = np.fromfile(signal_file, dtype=np.float32)
        return data
    except Exception:
        print(f"Warning: Could not load as float32, trying other formats")
        # Try int16
        try:
            data = np.fromfile(signal_file, dtype=np.int16).astype(np.float32) / 32768.0
            return data
        except Exception:
            print(f"Error: Could not load signal file in any supported format")
            sys.exit(1)


def calculate_spectrum(data, sample_rate=2500000):
    """Calculate power spectrum of signal."""
    # Use FFT
    fft_data = np.fft.fft(data)
    freqs = np.fft.fftfreq(len(data), 1/sample_rate)
    power = np.abs(fft_data) ** 2
    
    return freqs, power


def estimate_bandwidth(freqs, power, threshold_db=20):
    """Estimate signal bandwidth from spectrum."""
    max_power = np.max(power)
    threshold = max_power / (10 ** (threshold_db / 10))
    
    # Find frequencies above threshold
    above_threshold = freqs[power > threshold]
    
    if len(above_threshold) == 0:
        return 0
    
    bandwidth = np.max(above_threshold) - np.min(above_threshold)
    return abs(bandwidth)


def detect_modulation(data, sample_rate=2500000):
    """Attempt to detect modulation type."""
    # Calculate amplitude and phase
    analytic = np.hilbert(data)
    amplitude = np.abs(analytic)
    phase = np.angle(analytic)
    
    # Calculate statistics
    amp_std = np.std(amplitude)
    amp_mean = np.mean(amplitude)
    amp_cv = amp_std / amp_mean if amp_mean > 0 else 0
    
    # Phase statistics
    phase_diff = np.diff(phase)
    phase_std = np.std(phase_diff)
    
    # Simple heuristic classification
    modulation = "unknown"
    confidence = 0.0
    
    if amp_cv < 0.1 and phase_std < 0.5:
        modulation = "FM (Frequency Modulation)"
        confidence = 0.7
    elif amp_cv > 0.3 and phase_std < 0.5:
        modulation = "AM (Amplitude Modulation)"
        confidence = 0.7
    elif amp_cv < 0.1 and phase_std > 1.0:
        modulation = "PSK (Phase Shift Keying)"
        confidence = 0.6
    elif amp_cv > 0.2 and phase_std > 0.5:
        modulation = "QAM (Quadrature Amplitude Modulation)"
        confidence = 0.5
    else:
        modulation = "Unknown/Complex"
        confidence = 0.3
    
    return modulation, confidence


def analyze_signal(signal_file, center_freq=None):
    """Main analysis function."""
    print(f"Analyzing signal: {signal_file}")
    
    # Load signal
    data = load_signal(signal_file)
    print(f"Loaded {len(data)} samples")
    
    # Estimate sample rate from file if not provided
    sample_rate = 2500000  # Default
    
    # Calculate spectrum
    freqs, power = calculate_spectrum(data, sample_rate)
    
    # Find peak frequency
    peak_idx = np.argmax(power)
    peak_freq = freqs[peak_idx]
    
    # Estimate bandwidth
    bandwidth = estimate_bandwidth(freqs, power)
    
    # Detect modulation
    modulation, confidence = detect_modulation(data, sample_rate)
    
    # Calculate signal statistics
    signal_power = np.mean(power)
    noise_floor = np.percentile(power, 10)
    snr = 10 * np.log10(signal_power / noise_floor) if noise_floor > 0 else 0
    
    # Compile results
    results = {
        "file": signal_file,
        "samples": len(data),
        "estimated_sample_rate": sample_rate,
        "peak_frequency_hz": float(peak_freq),
        "bandwidth_hz": float(bandwidth),
        "modulation": modulation,
        "modulation_confidence": confidence,
        "snr_db": float(snr),
        "center_frequency_hz": center_freq
    }
    
    # Print results
    print("\n=== Signal Analysis Results ===")
    print(f"Samples: {results['samples']}")
    print(f"Peak Frequency: {peak_freq/1e6:.2f} MHz")
    print(f"Estimated Bandwidth: {bandwidth/1e3:.2f} kHz")
    print(f"Modulation: {modulation} (confidence: {confidence:.1%})")
    print(f"SNR: {snr:.1f} dB")
    
    if center_freq:
        print(f"Center Frequency: {center_freq}")
    
    return results


def main():
    parser = argparse.ArgumentParser(
        description="Analyze radio signal captures"
    )
    parser.add_argument(
        "-i", "--input",
        required=True,
        help="Input signal file (binary)"
    )
    parser.add_argument(
        "-f", "--frequency",
        help="Center frequency (e.g., '433M', '2.4G')"
    )
    parser.add_argument(
        "-o", "--output",
        help="Output JSON file for results"
    )
    
    args = parser.parse_args()
    
    # Parse frequency if provided
    center_freq = None
    if args.frequency:
        if args.frequency.endswith('M'):
            center_freq = float(args.frequency[:-1]) * 1e6
        elif args.frequency.endswith('G'):
            center_freq = float(args.frequency[:-1]) * 1e9
        else:
            center_freq = float(args.frequency)
    
    # Run analysis
    results = analyze_signal(args.input, center_freq)
    
    # Save to JSON if requested
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\nResults saved to: {args.output}")


if __name__ == "__main__":
    main()
