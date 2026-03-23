#!/usr/bin/env python3
"""
Backdoor Detector for RL Policies

Detects potential backdoor patterns in trained reinforcement learning
policies by analyzing reward anomalies and trigger-dependent behavior.

Usage:
    python scripts/backdoor_detector.py --policy model.pkl --canary-episodes 50
"""

import argparse
import json
import numpy as np
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass, asdict
from pathlib import Path


@dataclass
class BackdoorDetectionResult:
    """Results from backdoor detection analysis."""
    has_anomalies: bool
    anomaly_count: int
    trigger_suspected: bool
    reward_variance: float
    behavior_divergence: float
    recommendations: List[str]


class RewardAnalyzer:
    """Analyzes reward patterns for anomalies."""
    
    def __init__(self, threshold_std: float = 3.0):
        self.threshold_std = threshold_std
    
    def analyze_reward_deltas(self, rewards: np.ndarray) -> Dict:
        """Detect abrupt reward improvements that may indicate backdoors."""
        if len(rewards) < 2:
            return {"anomalies": [], "variance": 0.0}
        
        # Calculate reward deltas
        deltas = np.diff(rewards)
        
        # Find anomalies (large positive jumps)
        mean_delta = np.mean(deltas)
        std_delta = np.std(deltas)
        
        anomalies = []
        for i, delta in enumerate(deltas):
            if delta > mean_delta + self.threshold_std * std_delta:
                anomalies.append({
                    "index": int(i),
                    "delta": float(delta),
                    "z_score": float((delta - mean_delta) / std_delta if std_delta > 0 else 0)
                })
        
        return {
            "anomalies": anomalies,
            "variance": float(np.var(rewards)),
            "mean_delta": float(mean_delta),
            "std_delta": float(std_delta)
        }


class CanaryTester:
    """Tests policy behavior on canary (trigger) episodes."""
    
    def __init__(self, n_canary_episodes: int = 50):
        self.n_canary_episodes = n_canary_episodes
    
    def generate_canary_states(self, n_states: int, 
                                rng: np.random.Generator) -> List[int]:
        """Generate rare canary states for testing."""
        # Select states that are unlikely to be visited normally
        canary_states = rng.choice(
            n_states, 
            size=min(n_canary_episodes, n_states),
            replace=False
        )
        return canary_states.tolist()
    
    def test_behavior_divergence(self, 
                                  normal_actions: np.ndarray,
                                  canary_actions: np.ndarray) -> float:
        """Measure how much behavior diverges on canary states."""
        if len(normal_actions) == 0 or len(canary_actions) == 0:
            return 0.0
        
        # Compare action distributions
        normal_dist = np.bincount(normal_actions, minlength=10) / len(normal_actions)
        canary_dist = np.bincount(canary_actions, minlength=10) / len(canary_actions)
        
        # KL divergence as measure of divergence
        # Add small epsilon to avoid log(0)
        epsilon = 1e-10
        kl_div = np.sum(canary_dist * np.log((canary_dist + epsilon) / (normal_dist + epsilon)))
        
        return float(kl_div)


class BackdoorDetector:
    """Main backdoor detection class."""
    
    def __init__(self, canary_episodes: int = 50):
        self.reward_analyzer = RewardAnalyzer()
        self.canary_tester = CanaryTester(canary_episodes)
    
    def detect(self, policy_data: Dict) -> BackdoorDetectionResult:
        """Run full backdoor detection pipeline."""
        recommendations = []
        anomaly_count = 0
        trigger_suspected = False
        
        # Analyze reward patterns
        if "rewards" in policy_data:
            reward_analysis = self.reward_analyzer.analyze_reward_deltas(
                np.array(policy_data["rewards"])
            )
            anomaly_count = len(reward_analysis["anomalies"])
            
            if anomaly_count > 5:
                trigger_suspected = True
                recommendations.append(
                    f"Found {anomaly_count} reward anomalies. "
                    "Inspect training data for poisoned trajectories."
                )
        
        # Test canary behavior
        if "canary_actions" in policy_data and "normal_actions" in policy_data:
            divergence = self.canary_tester.test_behavior_divergence(
                np.array(policy_data["normal_actions"]),
                np.array(policy_data["canary_actions"])
            )
            
            if divergence > 2.0:  # High KL divergence threshold
                trigger_suspected = True
                recommendations.append(
                    f"High behavior divergence ({divergence:.2f}) on canary states. "
                    "Policy may have trigger-dependent behavior."
                )
        
        # General recommendations
        if not recommendations:
            recommendations.append(
                "No obvious backdoor patterns detected. "
                "Continue monitoring in production."
            )
        
        recommendations.extend([
            "Maintain canary trigger set for ongoing monitoring",
            "Verify training data provenance",
            "Use ensemble methods to detect outlier policies"
        ])
        
        return BackdoorDetectionResult(
            has_anomalies=anomaly_count > 0,
            anomaly_count=anomaly_count,
            trigger_suspected=trigger_suspected,
            reward_variance=reward_analysis.get("variance", 0.0) if "rewards" in policy_data else 0.0,
            behavior_divergence=divergence if "canary_actions" in policy_data else 0.0,
            recommendations=recommendations
        )
    
    def generate_report(self, result: BackdoorDetectionResult) -> str:
        """Generate human-readable report."""
        lines = [
            "=" * 60,
            "BACKDOOR DETECTION REPORT",
            "=" * 60,
            "",
            f"Anomalies Detected: {result.has_anomalies}",
            f"Anomaly Count: {result.anomaly_count}",
            f"Trigger Suspected: {result.trigger_suspected}",
            f"Reward Variance: {result.reward_variance:.4f}",
            f"Behavior Divergence: {result.behavior_divergence:.4f}",
            "",
            "Recommendations:",
        ]
        
        for i, rec in enumerate(result.recommendations, 1):
            lines.append(f"  {i}. {rec}")
        
        lines.append("=" * 60)
        return "\n".join(lines)


def load_policy_data(path: str) -> Dict:
    """Load policy data for analysis."""
    # For demo purposes, generate synthetic data
    # In production, this would load from actual policy files
    rng = np.random.default_rng(42)
    
    return {
        "rewards": rng.normal(0, 1, 1000).tolist(),
        "normal_actions": rng.integers(0, 4, 500).tolist(),
        "canary_actions": rng.integers(0, 4, 50).tolist()
    }


def main():
    parser = argparse.ArgumentParser(
        description="Detect backdoor patterns in RL policies"
    )
    parser.add_argument("--policy", type=str, required=True,
                        help="Path to policy file")
    parser.add_argument("--canary-episodes", type=int, default=50,
                        help="Number of canary episodes to test")
    parser.add_argument("--trigger-patterns", type=str,
                        help="Path to trigger patterns JSON")
    parser.add_argument("--output", type=str, default="backdoor_report.json",
                        help="Output path for report")
    
    args = parser.parse_args()
    
    print(f"Loading policy from {args.policy}...")
    policy_data = load_policy_data(args.policy)
    
    print(f"Running backdoor detection with {args.canary_episodes} canary episodes...")
    detector = BackdoorDetector(args.canary_episodes)
    result = detector.detect(policy_data)
    
    # Print report
    print(detector.generate_report(result))
    
    # Save JSON report
    report = {
        "detection_result": asdict(result),
        "policy_path": args.policy,
        "canary_episodes": args.canary_episodes
    }
    
    with open(args.output, "w") as f:
        json.dump(report, f, indent=2)
    
    print(f"\nReport saved to {args.output}")
    
    # Exit with error code if backdoor suspected
    if result.trigger_suspected:
        print("\n⚠️  WARNING: Potential backdoor detected!")
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())
