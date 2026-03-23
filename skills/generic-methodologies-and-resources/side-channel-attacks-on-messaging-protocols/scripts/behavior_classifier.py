#!/usr/bin/env python3
"""
Behavior classifier for delivery receipt side-channel attacks.
Builds active/idle classifiers from RTT traces and detects patterns.

Usage:
    python behavior_classifier.py --input analysis.json --output behavior.json
"""

import argparse
import json
from typing import List, Dict, Tuple
from collections import defaultdict
import statistics


def load_analysis(input_file: str) -> Dict:
    """Load analysis results from JSON file."""
    with open(input_file, 'r') as f:
        return json.load(f)


def classify_device_state(rtt_ms: float, thresholds: Dict[str, float]) -> str:
    """Classify device state based on RTT."""
    if rtt_ms < thresholds["active"]:
        return "active"
    elif rtt_ms < thresholds["background"]:
        return "background"
    else:
        return "offline_or_delayed"


def detect_patterns(rtts: List[Dict], window_size: int = 10) -> List[Dict]:
    """Detect behavioral patterns in RTT traces."""
    if not rtts:
        return []
    
    # Sort by probe ID
    sorted_rtts = sorted(rtts, key=lambda x: x["probe_id"])
    
    # Default thresholds (can be tuned per platform)
    thresholds = {
        "active": 500,      # < 500ms = active/foreground
        "background": 1500  # < 1500ms = background
    }
    
    patterns = []
    current_pattern = None
    
    for i, rtt in enumerate(sorted_rtts):
        state = classify_device_state(rtt["rtt_ms"], thresholds)
        
        if current_pattern is None:
            current_pattern = {
                "start_probe": rtt["probe_id"],
                "end_probe": rtt["probe_id"],
                "state": state,
                "rtt_values": [rtt["rtt_ms"]],
                "device_id": rtt["device_id"]
            }
        elif state == current_pattern["state"] and rtt["device_id"] == current_pattern["device_id"]:
            # Continue pattern
            current_pattern["end_probe"] = rtt["probe_id"]
            current_pattern["rtt_values"].append(rtt["rtt_ms"])
        else:
            # Save current pattern and start new one
            if len(current_pattern["rtt_values"]) >= window_size:
                current_pattern["avg_rtt_ms"] = statistics.mean(current_pattern["rtt_values"])
                current_pattern["duration_probes"] = current_pattern["end_probe"] - current_pattern["start_probe"] + 1
                patterns.append(current_pattern)
            
            current_pattern = {
                "start_probe": rtt["probe_id"],
                "end_probe": rtt["probe_id"],
                "state": state,
                "rtt_values": [rtt["rtt_ms"]],
                "device_id": rtt["device_id"]
            }
    
    # Don't forget the last pattern
    if current_pattern and len(current_pattern["rtt_values"]) >= window_size:
        current_pattern["avg_rtt_ms"] = statistics.mean(current_pattern["rtt_values"])
        current_pattern["duration_probes"] = current_pattern["end_probe"] - current_pattern["start_probe"] + 1
        patterns.append(current_pattern)
    
    return patterns


def infer_daily_patterns(patterns: List[Dict]) -> Dict:
    """Infer daily behavioral patterns from state sequences."""
    if not patterns:
        return {}
    
    # Count state durations
    state_durations = defaultdict(int)
    for pattern in patterns:
        state_durations[pattern["state"]] += pattern["duration_probes"]
    
    total_probes = sum(state_durations.values())
    
    # Infer likely activities
    inferences = []
    
    if state_durations["active"] / total_probes > 0.6:
        inferences.append("User frequently active - likely during work hours or high engagement")
    
    if state_durations["background"] / total_probes > 0.3:
        inferences.append("Significant background time - phone present but not in use")
    
    if state_durations["offline_or_delayed"] / total_probes > 0.2:
        inferences.append("Frequent offline periods - possible commuting, sleep, or no-signal areas")
    
    # Detect transitions
    transitions = 0
    for i in range(1, len(patterns)):
        if patterns[i]["state"] != patterns[i-1]["state"]:
            transitions += 1
    
    if transitions > len(patterns) * 0.3:
        inferences.append("High state volatility - user frequently switching between active/background")
    
    return {
        "state_distribution": {
            state: count / total_probes * 100
            for state, count in state_durations.items()
        },
        "total_patterns": len(patterns),
        "state_transitions": transitions,
        "inferences": inferences
    }


def analyze_device_switching(rtts: List[Dict]) -> Dict:
    """Analyze device switching patterns (mobile vs desktop)."""
    device_sequences = defaultdict(list)
    
    for rtt in sorted(rtts, key=lambda x: x["probe_id"]):
        device_sequences[rtt["device_id"]].append(rtt["probe_id"])
    
    switching_analysis = {}
    for device_id, probe_ids in device_sequences.items():
        # Detect gaps (offline periods)
        gaps = []
        for i in range(1, len(probe_ids)):
            gap = probe_ids[i] - probe_ids[i-1]
            if gap > 5:  # More than 5 probes gap
                gaps.append({
                    "start": probe_ids[i-1],
                    "end": probe_ids[i],
                    "duration": gap
                })
        
        switching_analysis[device_id] = {
            "total_probes": len(probe_ids),
            "first_seen": min(probe_ids),
            "last_seen": max(probe_ids),
            "offline_gaps": gaps,
            "gap_count": len(gaps),
            "avg_gap_duration": statistics.mean([g["duration"] for g in gaps]) if gaps else 0
        }
    
    return switching_analysis


def run_classification(input_file: str, output_file: str) -> Dict:
    """Run full behavior classification."""
    print(f"Loading analysis from {input_file}...")
    analysis = load_analysis(input_file)
    
    # Get RTT data from device analysis
    rtts = []
    for device_id, device_data in analysis.get("device_analysis", {}).items():
        # Reconstruct RTT entries (simplified - in practice, load from original receipts)
        for _ in range(device_data["count"]):
            rtts.append({
                "device_id": device_id,
                "rtt_ms": device_data["avg_rtt_ms"],
                "probe_id": 0  # Placeholder
            })
    
    if not rtts:
        print("No RTT data found")
        return {}
    
    print(f"Analyzing {len(rtts)} RTT measurements...")
    
    print("Detecting patterns...")
    patterns = detect_patterns(rtts)
    
    print("Inferring daily patterns...")
    daily_patterns = infer_daily_patterns(patterns)
    
    print("Analyzing device switching...")
    switching = analyze_device_switching(rtts)
    
    # Compile results
    results = {
        "patterns": patterns,
        "daily_inference": daily_patterns,
        "device_switching": switching,
        "recommendations": generate_recommendations(daily_patterns, switching)
    }
    
    # Save results
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\nClassification saved to {output_file}")
    
    # Print summary
    print("\n=== BEHAVIOR CLASSIFICATION ===")
    print(f"Total patterns detected: {len(patterns)}")
    print(f"\nState distribution:")
    for state, percentage in daily_patterns.get("state_distribution", {}).items():
        print(f"  {state}: {percentage:.1f}%")
    
    print(f"\nInferences:")
    for inference in daily_patterns.get("inferences", []):
        print(f"  - {inference}")
    
    print(f"\nRecommendations:")
    for rec in results["recommendations"]:
        print(f"  - {rec}")
    
    return results


def generate_recommendations(daily_patterns: Dict, switching: Dict) -> List[str]:
    """Generate actionable recommendations based on analysis."""
    recommendations = []
    
    # Based on state distribution
    state_dist = daily_patterns.get("state_distribution", {})
    
    if state_dist.get("active", 0) > 70:
        recommendations.append("Target active hours for maximum engagement - user frequently foreground")
    
    if state_dist.get("offline_or_delayed", 0) > 30:
        recommendations.append("Significant offline periods detected - consider timing probes around expected online windows")
    
    # Based on device switching
    for device_id, device_data in switching.items():
        if device_data["gap_count"] > 3:
            recommendations.append(f"Device {device_id} has frequent offline gaps - may indicate commuting or device switching")
        
        if device_data["avg_gap_duration"] > 20:
            recommendations.append(f"Device {device_id} has long offline periods (avg {device_data['avg_gap_duration']} probes) - possible sleep or travel")
    
    if not recommendations:
        recommendations.append("No strong patterns detected - continue monitoring for longer duration")
    
    return recommendations


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Behavior classifier for delivery receipt side-channel attacks"
    )
    parser.add_argument("--input", required=True, help="Input analysis JSON file")
    parser.add_argument("--output", default="behavior.json", help="Output behavior JSON file")
    
    args = parser.parse_args()
    
    run_classification(args.input, args.output)
