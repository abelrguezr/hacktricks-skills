#!/usr/bin/env python3
"""
Modulation Identification Tool

Uses statistical analysis to identify modulation types in radio signals.
More sophisticated than basic analysis - uses multiple features.
"""

import argparse
import numpy as np
from pathlib import Path
import sys


def load_signal(signal_file):
    """Load signal data from file."""
    path = Path(signal_file)
    
    if not path.exists():
        print(f"Error: Signal file '{signal_file}' not found")
        sys.exit(1)
    
    try:
        data = np.fromfile(signal_file, dtype=np.float32)
        return data
    except Exception:
        try:
            data = np.fromfile(signal_file, dtype=np.int16).astype(np.float32) / 32768.0
            return data
        except Exception:
            print(f"Error: Could not load signal file")
            sys.exit(1)


def calculate_cyclic_features(data):
    """Calculate cyclic features for modulation classification."""
    # Normalize
    data = data / np.std(data)
    
    # Calculate higher order statistics
    kurtosis = np.mean((data - np.mean(data))**4) / (np.std(data)**4) - 3
    skewness = np.mean((data - np.mean(data))**3) / (np.std(data)**3)
    
    # Analytic signal
    analytic = np.hilbert(data)
    amplitude = np.abs(analytic)
    phase = np.angle(analytic)
    
    # Amplitude features
    amp_mean = np.mean(amplitude)
    amp_std = np.std(amplitude)
    amp_kurtosis = np.mean((amplitude - amp_mean)**4) / (amp_std**4) - 3
    
    # Phase features
    phase_diff = np.diff(phase)
    phase_std = np.std(phase_diff)
    phase_kurtosis = np.mean((phase_diff - np.mean(phase_diff))**4) / (np.std(phase_diff)**4) - 3
    
    return {
        'kurtosis': kurtosis,
        'skewness': skewness,
        'amp_mean': amp_mean,
        'amp_std': amp_std,
        'amp_kurtosis': amp_kurtosis,
        'phase_std': phase_std,
        'phase_kurtosis': phase_kurtosis
    }


def classify_modulation(features):
    """Classify modulation based on features."""
    scores = {}
    
    # AM characteristics: high amplitude variation, low phase variation
    am_score = (
        (features['amp_std'] > 0.3) * 0.3 +
        (features['phase_std'] < 0.5) * 0.3 +
        (abs(features['kurtosis']) > 1) * 0.2 +
        (features['amp_kurtosis'] > 0) * 0.2
    )
    scores['AM'] = am_score
    
    # FM characteristics: constant amplitude, varying phase
    fm_score = (
        (features['amp_std'] < 0.2) * 0.4 +
        (features['phase_std'] > 0.5) * 0.3 +
        (abs(features['amp_kurtosis']) < 1) * 0.3
    )
    scores['FM'] = fm_score
    
    # PSK characteristics: constant amplitude, discrete phase
    psk_score = (
        (features['amp_std'] < 0.15) * 0.4 +
        (features['phase_kurtosis'] > 1) * 0.3 +
        (features['phase_std'] > 1.0) * 0.3
    )
    scores['PSK'] = psk_score
    
    # QAM characteristics: varying amplitude and phase
    qam_score = (
        (features['amp_std'] > 0.2) * 0.3 +
        (features['phase_std'] > 0.5) * 0.3 +
        (abs(features['kurtosis']) > 0.5) * 0.2 +
        (features['amp_kurtosis'] > 0.5) * 0.2
    )
    scores['QAM'] = qam_score
    
    # FSK characteristics: discrete frequency changes
    fs_k_score = (
        (features['amp_std'] < 0.2) * 0.3 +
        (features['phase_std'] > 0.8) * 0.4 +
        (features['phase_kurtosis'] > 0.5) * 0.3
    )
    scores['FSK'] = fs_k_score
    
    # Find best match
    best_modulation = max(scores, key=scores.get)
    confidence = scores[best_modulation]
    
    return best_modulation, confidence, scores


def identify_modulation(signal_file):
    """Main identification function."""
    print(f"Identifying modulation in: {signal_file}")
    
    # Load signal
    data = load_signal(signal_file)
    print(f"Loaded {len(data)} samples")
    
    # Calculate features
    features = calculate_cyclic_features(data)
    
    # Classify
    modulation, confidence, all_scores = classify_modulation(features)
    
    # Print results
    print("\n=== Modulation Identification ===")
    print(f"Best Match: {modulation}")
    print(f"Confidence: {confidence:.1%}")
    print("\nAll Scores:")
    for mod, score in sorted(all_scores.items(), key=lambda x: -x[1]):
        print(f"  {mod}: {score:.1%}")
    
    print("\nFeature Values:")
    for key, value in features.items():
        print(f"  {key}: {value:.3f}")
    
    return {
        'modulation': modulation,
        'confidence': confidence,
        'scores': all_scores,
        'features': features
    }


def main():
    parser = argparse.ArgumentParser(
        description="Identify modulation type in radio signals"
    )
    parser.add_argument(
        "-i", "--input",
        required=True,
        help="Input signal file (binary)"
    )
    parser.add_argument(
        "-o", "--output",
        help="Output JSON file for results"
    )
    
    args = parser.parse_args()
    
    # Run identification
    results = identify_modulation(args.input)
    
    # Save to JSON if requested
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\nResults saved to: {args.output}")


if __name__ == "__main__":
    main()
