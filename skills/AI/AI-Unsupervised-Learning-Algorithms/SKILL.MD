---
name: unsupervised-learning-security
description: Apply unsupervised machine learning algorithms to security data for anomaly detection, clustering, and dimensionality reduction. Use this skill whenever the user needs to analyze unlabeled security data, detect unknown threats, cluster network events, reduce feature dimensions, or identify outliers in logs, traffic, or behavioral data. Trigger for tasks involving K-Means, DBSCAN, HDBSCAN, Isolation Forest, GMM, PCA, t-SNE, or any unsupervised pattern discovery in cybersecurity contexts.
---

# Unsupervised Learning for Security Analysis

This skill helps you apply unsupervised machine learning algorithms to security data. Unlike supervised learning, these methods work with unlabeled data to discover hidden patterns, detect anomalies, and cluster similar events.

## When to Use This Skill

Use this skill when you need to:
- Detect unknown threats or anomalies in network traffic, logs, or user behavior
- Cluster security events to find groups of similar activity
- Reduce high-dimensional security data for visualization or analysis
- Identify outliers that might indicate attacks or misconfigurations
- Explore unlabeled datasets to understand their structure
- Build threat-hunting pipelines without labeled attack data

## Algorithm Selection Guide

Choose the right algorithm based on your use case:

| Use Case | Recommended Algorithm | Why |
|----------|----------------------|-----|
| **Anomaly detection** | Isolation Forest, DBSCAN, HDBSCAN | Designed to flag outliers without labels |
| **Clustering with known K** | K-Means, GMM | Fast, works well when you know cluster count |
| **Clustering with unknown K** | DBSCAN, HDBSCAN, Hierarchical | Automatically determines cluster count |
| **Varying density clusters** | HDBSCAN, DBSCAN | Handles clusters of different densities |
| **Soft clustering** | GMM | Provides probability of cluster membership |
| **Dimensionality reduction** | PCA (linear), t-SNE (nonlinear) | Compress features for visualization |
| **Large datasets** | Isolation Forest, K-Means | Efficient O(n log n) or O(n) complexity |
| **Visual exploration** | t-SNE, PCA | Create 2D/3D plots for human analysis |

## Core Algorithms

### K-Means Clustering

**Best for:** Quick clustering when you know the number of groups, spherical clusters of similar size.

**How it works:**
1. Initialize K centroids (randomly or via k-means++)
2. Assign each point to nearest centroid
3. Recalculate centroids as mean of assigned points
4. Repeat until convergence

**Security use cases:**
- Group network traffic into normal vs. attack patterns
- Cluster log entries by similarity
- Classify malware families by behavior profiles

**Key parameters:**
- `n_clusters`: Number of clusters (use Elbow Method or Silhouette Score to determine)
- `random_state`: For reproducibility
- `n_init`: Number of initializations (higher = more stable)

**Limitations:** Assumes spherical, equally-sized clusters. Sensitive to initialization. Requires normalization.

### DBSCAN (Density-Based Clustering)

**Best for:** Finding arbitrarily shaped clusters, detecting outliers as noise, unknown cluster count.

**How it works:**
- Groups points within `eps` distance that have at least `min_samples` neighbors
- Points not in any cluster are labeled as noise (-1)
- No need to specify number of clusters

**Security use cases:**
- Detect port scans or DoS traffic as sparse regions
- Flag zero-day malware that doesn't fit known families
- Identify anomalous user behavior patterns

**Key parameters:**
- `eps`: Maximum distance between points in same cluster
- `min_samples`: Minimum points to form a dense region

**Limitations:** Struggles with varying densities. Single `eps` may not work for all clusters. Can be slow on large datasets.

### HDBSCAN (Hierarchical DBSCAN)

**Best for:** Clusters of varying density, modern threat-hunting pipelines, outlier scoring.

**How it works:**
- Builds hierarchy of density-connected components
- Condenses hierarchy to extract clusters
- Provides outlier scores for each point

**Security use cases:**
- Cluster HTTP beaconing traffic (legitimate vs. C2)
- Threat-hunting playbooks in XDR suites
- Detect low-density attack patterns hidden in noise

**Key parameters:**
- `min_cluster_size`: Minimum points per cluster (sensible defaults available)
- `prediction_data=True`: Enable outlier scoring

**Advantages over DBSCAN:** Handles varying densities, only one main hyperparameter, provides outlier probabilities.

### Isolation Forest

**Best for:** Fast anomaly detection on large, high-dimensional datasets.

**How it works:**
- Builds random binary trees that partition data
- Anomalies are isolated faster (shorter path length)
- Anomaly score based on average path length across trees

**Security use cases:**
- Intrusion detection on network traffic logs
- Fraud detection in financial transactions
- Account takeover detection from login patterns
- System metric monitoring for unusual behavior

**Key parameters:**
- `n_estimators`: Number of trees (100-200 typical)
- `contamination`: Expected fraction of anomalies (e.g., 0.05 for 5%)

**Advantages:** O(n log n) complexity, works on high-dimensional data, no distribution assumptions.

### Gaussian Mixture Models (GMM)

**Best for:** Soft clustering, probabilistic anomaly detection, ellipsoidal clusters.

**How it works:**
- Assumes data comes from mixture of K Gaussian distributions
- Uses Expectation-Maximization (EM) to fit parameters
- Each point gets probability of belonging to each cluster

**Security use cases:**
- Model normal traffic distribution, flag low-likelihood points
- Cluster user behavior with uncertainty quantification
- Phishing detection with probabilistic scoring

**Key parameters:**
- `n_components`: Number of Gaussian components
- `covariance_type`: 'full', 'tied', 'diag', 'spherical'

**Advantages:** Soft assignments, handles different cluster shapes, provides likelihood scores.

### PCA (Principal Component Analysis)

**Best for:** Linear dimensionality reduction, noise reduction, feature decorrelation.

**How it works:**
- Finds orthogonal axes of maximum variance
- Projects data onto top K principal components
- Reduces dimensions while preserving structure

**Security use cases:**
- Reduce 40+ network metrics to handful of components
- Visualize traffic in 2D/3D for pattern spotting
- Preprocess data for other algorithms
- Remove redundant correlated features

**Key parameters:**
- `n_components`: Number of components to keep
- `whiten=True`: Scale components to unit variance

**Limitations:** Linear only, components may be hard to interpret, prioritizes variance not "interestingness".

### t-SNE (t-Distributed Stochastic Neighbor Embedding)

**Best for:** Nonlinear visualization of high-dimensional data.

**How it works:**
- Converts similarities to probability distributions
- Preserves local neighborhood structure in 2D/3D
- Uses gradient descent to minimize KL divergence

**Security use cases:**
- Visualize malware family groupings
- Plot network intrusion data to spot attack clusters
- Explore complex security datasets for patterns

**Key parameters:**
- `perplexity`: Effective number of neighbors (5-50 typical)
- `learning_rate`: Step size for optimization
- `n_iter`: Number of iterations (1000+ for convergence)

**Limitations:** Computationally heavy O(n²), distances not globally meaningful, can't project new points easily.

## Security Considerations

### Adversarial Vulnerabilities

Unsupervised learners are **not immune** to active attackers:

1. **Data poisoning:** Adding ~3% crafted traffic can shift anomaly detector boundaries (Chen et al., IEEE S&P 2024)
2. **Backdooring:** Trigger patterns can force clustering into "benign" groups (BadCME, BlackHat EU 2023)
3. **Evasion:** Attackers can craft patterns that fall into density gaps, hiding as noise (KU Leuven, 2025)

### Mitigations

1. **Model sanitization (TRIM):** Discard 1-2% highest-loss points before retraining
2. **Consensus ensembling:** Combine multiple detectors (Isolation Forest + GMM + ECOD), alert if any flags
3. **Distance-based defense:** Re-cluster with different random seeds, ignore points that hop clusters

## Modern Tooling

- **PyOD 2.x:** 30+ anomaly detectors, one-line benchmarking
- **Anomalib v1.5:** Vision-focused, includes PatchCore for screenshot analysis
- **scikit-learn 1.5:** HDBSCAN wrapper with `score_samples` support

## Implementation Patterns

### Pattern 1: Anomaly Detection Pipeline

```python
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler

# 1. Prepare features
X = df[['duration', 'bytes', 'packets', 'errors']].values
X_scaled = StandardScaler().fit_transform(X)

# 2. Train detector
iso = IsolationForest(contamination=0.05, random_state=42)
iso.fit(X_scaled)

# 3. Score and flag
scores = iso.decision_function(X_scaled)
labels = iso.predict(X_scaled)  # -1 = anomaly, 1 = normal

# 4. Extract anomalies
anomalies = df[labels == -1].sort_values('score', ascending=False)
```

### Pattern 2: Clustering with Multiple Algorithms

```python
from sklearn.cluster import KMeans, DBSCAN
from hdbscan import HDBSCAN

# Try multiple algorithms
kmeans = KMeans(n_clusters=4, random_state=42).fit(X_scaled)
dbscan = DBSCAN(eps=0.5, min_samples=5).fit(X_scaled)
hdb = HDBSCAN(min_cluster_size=15, prediction_data=True).fit(X_scaled)

# Compare results
print(f"K-Means: {len(set(kmeans.labels_))} clusters")
print(f"DBSCAN: {len(set(dbscan.labels_) - {-1})} clusters, {sum(dbscan.labels_ == -1)} noise")
print(f"HDBSCAN: {len(set(hdb.labels_) - {-1})} clusters, {sum(hdb.labels_ == -1)} noise")
```

### Pattern 3: Dimensionality Reduction for Visualization

```python
from sklearn.decomposition import PCA
from sklearn.manifold import TSNE

# PCA for quick linear reduction
pca = PCA(n_components=2)
X_pca = pca.fit_transform(X_scaled)
print(f"PCA explained variance: {pca.explained_variance_ratio_}")

# t-SNE for nonlinear visualization
tsne = TSNE(n_components=2, perplexity=30, random_state=42)
X_tsne = tsne.fit_transform(X_scaled)
```

### Pattern 4: Ensemble Anomaly Detection

```python
from pyod.models import ECOD, IForest

# Train multiple detectors
models = [ECOD(), IForest(contamination=0.05)]

# Ensemble: flag if any model detects anomaly
scores = sum(m.fit(X_train).decision_function(X_test) for m in models) / len(models)
anomalies = X_test[scores < threshold]
```

## Best Practices

1. **Always normalize features** before distance-based algorithms (K-Means, DBSCAN, etc.)
2. **Start with Isolation Forest** for anomaly detection - fast, robust, few parameters
3. **Use HDBSCAN over DBSCAN** when possible - handles varying densities better
4. **Try multiple algorithms** and compare results - different algorithms find different patterns
5. **Visualize with t-SNE** to understand cluster structure before deploying
6. **Set contamination conservatively** (1-5%) and tune based on false positive rate
7. **Use ensemble methods** to reduce adversarial vulnerability
8. **Monitor for concept drift** - retrain periodically as attack patterns evolve

## Common Pitfalls

- **Not normalizing:** Distance-based algorithms fail with unscaled features
- **Wrong K for K-Means:** Use Elbow Method or Silhouette Score to determine
- **t-SNE overinterpretation:** Distances aren't globally meaningful, focus on local structure
- **PCA on nonlinear data:** Use t-SNE or autoencoders for nonlinear relationships
- **Ignoring noise:** DBSCAN/HDBSCAN noise points are often the most interesting (potential attacks)
- **Single algorithm reliance:** Always try multiple approaches and compare

## Next Steps

After running an algorithm:
1. Inspect the flagged anomalies or clusters
2. Validate against known ground truth if available
3. Tune parameters based on precision/recall tradeoff
4. Consider ensemble methods for production
5. Set up monitoring for model drift and retraining triggers
