#!/usr/bin/env python3
"""
Benchmark Script for Comparing Unsupervised Learning Algorithms

Usage:
    python benchmark_algorithms.py --input data.csv --output benchmark.json
    python benchmark_algorithms.py --input data.csv --algorithms isolation-forest,dbscan,kmeans
"""

import argparse
import json
import sys
import time
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.cluster import KMeans, DBSCAN, AgglomerativeClustering
from sklearn.mixture import GaussianMixture
from sklearn.decomposition import PCA
from sklearn.manifold import TSNE
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import silhouette_score, davies_bouldin_score

try:
    from hdbscan import HDBSCAN
    HDBSCAN_AVAILABLE = True
except ImportError:
    HDBSCAN_AVAILABLE = False

try:
    from pyod.models import ECOD
    PYOD_AVAILABLE = True
except ImportError:
    PYOD_AVAILABLE = False


def load_data(input_path: str) -> tuple[np.ndarray, pd.DataFrame]:
    """Load data from CSV file."""
    df = pd.read_csv(input_path)
    numeric_cols = df.select_dtypes(include=[np.number]).columns.tolist()
    
    if not numeric_cols:
        raise ValueError("No numeric columns found in the dataset")
    
    X = df[numeric_cols].values
    return X, df, numeric_cols


def benchmark_algorithm(name: str, func: callable, X: np.ndarray, **kwargs) -> dict:
    """Run an algorithm and measure performance."""
    start_time = time.time()
    
    try:
        result = func(X, **kwargs)
        elapsed_time = time.time() - start_time
        
        return {
            "name": name,
            "status": "success",
            "elapsed_time_seconds": round(elapsed_time, 3),
            "result": result
        }
    except Exception as e:
        elapsed_time = time.time() - start_time
        return {
            "name": name,
            "status": "error",
            "error": str(e),
            "elapsed_time_seconds": round(elapsed_time, 3)
        }


def run_isolation_forest(X: np.ndarray, contamination: float = 0.05) -> dict:
    """Run Isolation Forest."""
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    model = IsolationForest(contamination=contamination, random_state=42)
    model.fit(X_scaled)
    
    labels = model.predict(X_scaled)
    n_anomalies = sum(labels == -1)
    
    return {
        "type": "anomaly_detection",
        "n_anomalies": int(n_anomalies),
        "anomaly_rate": float(n_anomalies / len(labels))
    }


def run_kmeans(X: np.ndarray, n_clusters: int = 4) -> dict:
    """Run K-Means clustering."""
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    model = KMeans(n_clusters=n_clusters, random_state=42)
    labels = model.fit_predict(X_scaled)
    
    if len(set(labels)) > 1:
        silhouette = silhouette_score(X_scaled, labels)
        davies_bouldin = davies_bouldin_score(X_scaled, labels)
    else:
        silhouette = 0.0
        davies_bouldin = 0.0
    
    return {
        "type": "clustering",
        "n_clusters": int(n_clusters),
        "silhouette_score": float(silhouette),
        "davies_bouldin_score": float(davies_bouldin)
    }


def run_dbscan(X: np.ndarray, eps: float = 0.5, min_samples: int = 5) -> dict:
    """Run DBSCAN clustering."""
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    model = DBSCAN(eps=eps, min_samples=min_samples)
    labels = model.fit_predict(X_scaled)
    
    n_clusters = len(set(labels) - {-1})
    n_noise = sum(labels == -1)
    
    return {
        "type": "clustering",
        "n_clusters": int(n_clusters),
        "n_noise": int(n_noise),
        "noise_rate": float(n_noise / len(labels))
    }


def run_hdbscan(X: np.ndarray, min_cluster_size: int = 15) -> dict:
    """Run HDBSCAN clustering."""
    if not HDBSCAN_AVAILABLE:
        raise ImportError("HDBSCAN not available")
    
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    model = HDBSCAN(min_cluster_size=min_cluster_size)
    labels = model.fit_predict(X_scaled)
    
    n_clusters = len(set(labels) - {-1})
    n_noise = sum(labels == -1)
    
    return {
        "type": "clustering",
        "n_clusters": int(n_clusters),
        "n_noise": int(n_noise),
        "noise_rate": float(n_noise / len(labels))
    }


def run_gmm(X: np.ndarray, n_components: int = 3) -> dict:
    """Run GMM clustering."""
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    model = GaussianMixture(n_components=n_components, random_state=42)
    model.fit(X_scaled)
    
    labels = model.predict(X_scaled)
    
    if len(set(labels)) > 1:
        silhouette = silhouette_score(X_scaled, labels)
    else:
        silhouette = 0.0
    
    return {
        "type": "clustering",
        "n_components": int(n_components),
        "silhouette_score": float(silhouette)
    }


def run_pca(X: np.ndarray, n_components: int = 2) -> dict:
    """Run PCA dimensionality reduction."""
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    model = PCA(n_components=n_components)
    model.fit(X_scaled)
    
    return {
        "type": "dimensionality_reduction",
        "n_components": int(n_components),
        "explained_variance_ratio": model.explained_variance_ratio_.tolist(),
        "cumulative_variance": float(np.sum(model.explained_variance_ratio_))
    }


def run_tsne(X: np.ndarray, n_components: int = 2) -> dict:
    """Run t-SNE dimensionality reduction."""
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    model = TSNE(n_components=n_components, random_state=42, n_iter=500)
    model.fit(X_scaled)
    
    return {
        "type": "dimensionality_reduction",
        "n_components": int(n_components)
    }


def run_ecod(X: np.ndarray, contamination: float = 0.05) -> dict:
    """Run ECOD anomaly detection."""
    if not PYOD_AVAILABLE:
        raise ImportError("PyOD not available")
    
    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)
    
    model = ECOD(contamination=contamination)
    model.fit(X_scaled)
    
    labels = model.predict(X_scaled)
    n_anomalies = sum(labels == 1)
    
    return {
        "type": "anomaly_detection",
        "n_anomalies": int(n_anomalies),
        "anomaly_rate": float(n_anomalies / len(labels))
    }


def main():
    parser = argparse.ArgumentParser(description='Benchmark unsupervised learning algorithms')
    parser.add_argument('--input', '-i', required=True, help='Input CSV file')
    parser.add_argument('--output', '-o', default='benchmark_results.json', help='Output JSON file')
    parser.add_argument('--algorithms', '-a', default=None,
                        help='Comma-separated list of algorithms to run')
    parser.add_argument('--contamination', '-c', type=float, default=0.05,
                        help='Contamination rate for anomaly detectors (default: 0.05)')
    parser.add_argument('--n-clusters', '-k', type=int, default=4,
                        help='Number of clusters (default: 4)')
    parser.add_argument('--eps', type=float, default=0.5,
                        help='DBSCAN eps parameter (default: 0.5)')
    parser.add_argument('--min-samples', type=int, default=5,
                        help='DBSCAN min_samples parameter (default: 5)')
    
    args = parser.parse_args()
    
    # Define all available algorithms
    all_algorithms = {
        'isolation-forest': lambda X: run_isolation_forest(X, args.contamination),
        'kmeans': lambda X: run_kmeans(X, args.n_clusters),
        'dbscan': lambda X: run_dbscan(X, args.eps, args.min_samples),
        'hdbscan': lambda X: run_hdbscan(X, 15),
        'gmm': lambda X: run_gmm(X, args.n_clusters),
        'pca': lambda X: run_pca(X, 2),
        'tsne': lambda X: run_tsne(X, 2),
        'ecod': lambda X: run_ecod(X, args.contamination)
    }
    
    # Filter available algorithms
    available_algorithms = {
        k: v for k, v in all_algorithms.items()
        if (k != 'hdbscan' or HDBSCAN_AVAILABLE) and (k != 'ecod' or PYOD_AVAILABLE)
    }
    
    # Select algorithms to run
    if args.algorithms:
        selected = [a.strip() for a in args.algorithms.split(',')]
        algorithms_to_run = {k: available_algorithms[k] for k in selected if k in available_algorithms}
    else:
        algorithms_to_run = available_algorithms
    
    print(f"Loading data from {args.input}...")
    X, df, numeric_cols = load_data(args.input)
    print(f"Loaded {len(X)} samples with {len(numeric_cols)} features")
    print(f"Running {len(algorithms_to_run)} algorithms...")
    
    results = []
    for name, func in algorithms_to_run.items():
        print(f"  Running {name}...")
        result = benchmark_algorithm(name, func, X)
        results.append(result)
        if result['status'] == 'success':
            print(f"    Completed in {result['elapsed_time_seconds']:.3f}s")
        else:
            print(f"    Error: {result.get('error', 'Unknown error')}")
    
    # Create summary
    successful = [r for r in results if r['status'] == 'success']
    summary = {
        "n_samples": len(X),
        "n_features": len(numeric_cols),
        "algorithms_run": len(results),
        "algorithms_successful": len(successful),
        "algorithms_failed": len(results) - len(successful)
    }
    
    # Group by type
    by_type = {}
    for r in successful:
        algo_type = r['result'].get('type', 'unknown')
        if algo_type not in by_type:
            by_type[algo_type] = []
        by_type[algo_type].append(r)
    
    # Find fastest in each category
    for algo_type, algos in by_type.items():
        fastest = min(algos, key=lambda x: x['elapsed_time_seconds'])
        summary[f"fastest_{algo_type}"] = fastest['name']
        summary[f"fastest_{algo_type}_time"] = fastest['elapsed_time_seconds']
    
    output = {
        "summary": summary,
        "results": results
    }
    
    # Save results
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    
    with open(output_path, 'w') as f:
        json.dump(output, f, indent=2)
    
    print(f"\nBenchmark results saved to {args.output}")
    print(f"\nSummary:")
    print(f"  Samples: {summary['n_samples']}")
    print(f"  Features: {summary['n_features']}")
    print(f"  Successful: {summary['algorithms_successful']}/{summary['algorithms_run']}")
    
    for algo_type, fastest_name in [
        (k, v) for k, v in summary.items() 
        if k.startswith('fastest_') and k.endswith('_name')
    ]:
        algo_type = algo_type.replace('fastest_', '').replace('_name', '')
        time_key = f"fastest_{algo_type}_time"
        print(f"  Fastest {algo_type}: {fastest_name} ({summary[time_key]:.3f}s)")


if __name__ == '__main__':
    main()
