#!/usr/bin/env python3
"""
Jamming Detection Tool

Monitors radio spectrum for signs of jamming activity.
Detects unusual signal patterns that may indicate jamming.
"""

import argparse
import numpy as np
import time
from pathlib import Path
import sys


def parse_frequency_range(freq_range):
    """Parse frequency range string like '2400M:2500M'."""
    parts = freq_range.split(':')
    if len(parts) != 2:
        raise ValueError("Frequency range should be 'start:end' (e.g., '2400M:2500M')")
    
    def parse_freq(f):
        if f.endswith('M'):
            return float(f[:-1]) * 1e6
        elif f.endswith('G'):
            return float(f[:-1]) * 1e9
        else:
            return float(f)
    
    return parse_freq(parts[0]), parse_freq(parts[1])


def simulate_spectrum_scan(start_freq, end_freq, bandwidth=1e6):
    """
    Simulate spectrum scan.
    In real implementation, this would use RTL-SDR or similar hardware.
    """
    # This is a placeholder - real implementation would use:
    # - rtl_power for RTL-SDR
    # - hackrf_transfer for HackRF
    # - gr-osmosdr for GNU Radio
    
    num_points = int((end_freq - start_freq) / bandwidth)
    freqs = np.linspace(start_freq, end_freq, num_points)
    
    # Simulate noise floor
    power = np.random.randn(num_points) * 10 - 100  # dBm
    
    # Add some simulated signals
    for _ in range(3):
        center = np.random.uniform(start_freq, end_freq)
        width = np.random.uniform(1e5, 1e6)
        mask = np.abs(freqs - center) < width / 2
        power[mask] += np.random.uniform(20, 50)
    
    return freqs, power


def detect_jamming_patterns(freqs, power, threshold_db=-60):
    """Detect potential jamming patterns in spectrum."""
    detections = []
    
    # Look for wideband signals (potential jamming)
    threshold = np.max(power) - threshold_db
    
    # Find continuous high-power regions
    above_threshold = power > threshold
    
    # Find runs of high power
    i = 0
    while i < len(above_threshold):
        if above_threshold[i]:
            start_idx = i
            while i < len(above_threshold) and above_threshold[i]:
                i += 1
            end_idx = i
            
            # Calculate width of high-power region
            width = freqs[end_idx] - freqs[start_idx]
            avg_power = np.mean(power[start_idx:end_idx])
            
            # Wideband signals (>100kHz) with high power may be jamming
            if width > 100e3 and avg_power > -50:
                detections.append({
                    'type': 'wideband_signal',
                    'start_freq': freqs[start_idx],
                    'end_freq': freqs[end_idx],
                    'width': width,
                    'avg_power': avg_power,
                    'confidence': min(0.9, 0.5 + (width / 1e6) * 0.2)
                })
        else:
            i += 1
    
    # Look for rapid power fluctuations (potential sweep jamming)
    power_diff = np.diff(power)
    high_fluctuation = np.abs(power_diff) > 20
    
    if np.sum(high_fluctuation) > len(high_fluctuation) * 0.1:
        detections.append({
            'type': 'rapid_fluctuation',
            'description': 'Rapid power changes detected - possible sweep jamming',
            'confidence': 0.6
        })
    
    return detections


def monitor_spectrum(freq_range, duration=60, interval=5):
    """Monitor spectrum for jamming over time."""
    start_freq, end_freq = parse_frequency_range(freq_range)
    
    print(f"Monitoring {freq_range} for {duration} seconds...")
    print("(This is a simulation - real implementation would use SDR hardware)")
    print()
    
    all_detections = []
    start_time = time.time()
    
    while time.time() - start_time < duration:
        # Scan spectrum
        freqs, power = simulate_spectrum_scan(start_freq, end_freq)
        
        # Detect jamming
        detections = detect_jamming_patterns(freqs, power)
        
        if detections:
            timestamp = time.strftime('%H:%M:%S')
            print(f"[{timestamp}] Detected {len(detections)} potential jamming signal(s):")
            for det in detections:
                if det['type'] == 'wideband_signal':
                    print(f"  - Wideband signal: {det['start_freq']/1e6:.1f}-{det['end_freq']/1e6:.1f} MHz "
                          f"({det['width']/1e3:.1f} kHz, {det['avg_power']:.1f} dBm)")
                else:
                    print(f"  - {det['description']}")
            
            all_detections.extend(detections)
        
        time.sleep(interval)
    
    print(f"\nMonitoring complete. Total detections: {len(all_detections)}")
    return all_detections


def main():
    parser = argparse.ArgumentParser(
        description="Detect radio jamming activity"
    )
    parser.add_argument(
        "-f", "--frequency",
        required=True,
        help="Frequency range (e.g., '2400M:2500M')"
    )
    parser.add_argument(
        "-d", "--duration",
        type=int,
        default=60,
        help="Monitoring duration in seconds (default: 60)"
    )
    parser.add_argument(
        "-i", "--interval",
        type=int,
        default=5,
        help="Scan interval in seconds (default: 5)"
    )
    
    args = parser.parse_args()
    
    # Run monitoring
    detections = monitor_spectrum(args.frequency, args.duration, args.interval)
    
    if detections:
        print("\n⚠️  Potential jamming activity detected!")
        print("Review the detections above for details.")
    else:
        print("\n✓ No obvious jamming patterns detected.")


if __name__ == "__main__":
    main()
