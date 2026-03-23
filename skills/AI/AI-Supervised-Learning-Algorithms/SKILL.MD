---
name: supervised-learning-cybersecurity
description: How to implement supervised machine learning algorithms for cybersecurity tasks like intrusion detection, malware classification, phishing detection, and spam filtering. Use this skill whenever the user mentions machine learning, ML models, classification, regression, cybersecurity datasets, NSL-KDD, phishing detection, intrusion detection, malware analysis, or wants to build predictive models for security applications. This skill covers Linear Regression, Logistic Regression, Decision Trees, Random Forests, SVM, Naive Bayes, k-NN, and Gradient Boosting with ready-to-use Python code.
---

# Supervised Learning for Cybersecurity

This skill helps you implement supervised machine learning algorithms for cybersecurity applications. It provides ready-to-use Python code for common security tasks like intrusion detection, malware classification, phishing detection, and spam filtering.

## Quick Start

Choose your task and algorithm, then run the corresponding script:

```bash
# For intrusion detection with Random Forest
python scripts/train_intrusion_detection.py --algorithm random_forest

# For phishing detection with Logistic Regression
python scripts/train_phishing_detection.py --algorithm logistic_regression

# For comparing multiple algorithms
python scripts/compare_algorithms.py --dataset nsl-kdd
```

## Available Algorithms

| Algorithm | Best For | Speed | Accuracy | Interpretability |
|-----------|----------|-------|----------|------------------|
| **Logistic Regression** | Binary classification, baseline | Fast | Good | High |
| **Decision Trees** | Rule-based detection, explainability | Fast | Medium | Very High |
| **Random Forests** | General purpose, robust detection | Medium | High | Medium |
| **SVM** | High-dimensional data, complex boundaries | Slow | High | Low |
| **Naive Bayes** | Text classification, spam filtering | Very Fast | Medium | Medium |
| **k-NN** | Small datasets, anomaly detection | Slow | Medium | Low |
| **Gradient Boosting** | Best accuracy, tabular data | Medium | Very High | Low |
| **Linear Regression** | Predicting numeric values | Fast | Varies | High |

## Common Cybersecurity Tasks

### 1. Intrusion Detection (NSL-KDD Dataset)

Detect network attacks from connection features.

```bash
python scripts/train_intrusion_detection.py --algorithm random_forest
```

**What it does:**
- Loads NSL-KDD dataset (train/test)
- Encodes categorical features (protocol_type, service, flag)
- Trains model to classify normal vs attack traffic
- Outputs accuracy, precision, recall, F1, ROC AUC

**Expected results:** Random Forest typically achieves 75-80% accuracy, 95%+ precision, 60-65% recall on NSL-KDD.

### 2. Phishing Website Detection

Classify websites as phishing or legitimate.

```bash
python scripts/train_phishing_detection.py --algorithm svm
```

**What it does:**
- Loads Phishing Websites dataset from OpenML
- Trains model on URL/domain features
- Outputs probability scores for phishing likelihood
- Evaluates with classification metrics

**Expected results:** SVM and Gradient Boosting typically achieve 95%+ accuracy, 98%+ ROC AUC.

### 3. Spam/Email Classification

Use Naive Bayes for text-based classification.

```bash
python scripts/train_spam_detection.py --algorithm naive_bayes
```

**What it does:**
- Processes email text features
- Uses Gaussian or Multinomial Naive Bayes
- Fast training and prediction
- Good baseline for text classification

## Algorithm Selection Guide

**Choose Logistic Regression when:**
- You need calibrated probability outputs
- Interpretability matters (feature coefficients)
- Dataset is large (scales well)
- Decision boundary is approximately linear

**Choose Decision Trees when:**
- You need human-readable rules
- Transparency is critical for security operations
- You want to understand which features trigger alerts
- Dataset has mixed numeric/categorical features

**Choose Random Forests when:**
- You want robust, out-of-the-box performance
- You need to reduce overfitting from single trees
- You have structured/tabular data
- You want feature importance scores

**Choose SVM when:**
- You have high-dimensional features
- Decision boundary is non-linear
- Dataset size is moderate (<100k samples)
- You need maximum margin separation

**Choose Naive Bayes when:**
- You're classifying text (spam, phishing emails)
- Speed is critical (real-time filtering)
- You have many features with independence assumption
- You need a fast baseline

**Choose k-NN when:**
- Dataset is small (<50k samples)
- You want example-based explanations
- Decision boundary is irregular
- You can afford slower prediction time

**Choose Gradient Boosting when:**
- You need the highest possible accuracy
- You have structured/tabular data
- You can tune hyperparameters
- You're willing to trade interpretability for performance

**Choose Linear Regression when:**
- You're predicting continuous values (not classification)
- You need to estimate numeric outcomes (e.g., attack volume, risk scores)
- Relationship is approximately linear

## Evaluation Metrics Explained

- **Accuracy:** Overall correctness (TP+TN)/(TP+TN+FP+FN)
- **Precision:** Of predicted attacks, how many are real? TP/(TP+FP)
- **Recall:** Of real attacks, how many did we catch? TP/(TP+FN)
- **F1-Score:** Harmonic mean of precision and recall
- **ROC AUC:** Threshold-independent measure (1.0 = perfect, 0.5 = random)

**For cybersecurity:**
- High **recall** is critical for intrusion detection (catch all attacks)
- High **precision** reduces analyst fatigue (fewer false alarms)
- Balance based on your threat model and operational constraints

## Ensemble Methods

Combine multiple models for better performance:

```bash
python scripts/train_ensemble.py --method stacking
```

**Voting Ensemble:** Multiple models vote on final prediction
- Simple, robust
- Reduces individual model errors

**Stacking:** Meta-model learns to combine base model predictions
- Often achieves best performance
- More complex to implement

## Data Preprocessing Checklist

Before training any model:

1. **Handle missing values** - Fill or remove
2. **Encode categorical features** - LabelEncoder or one-hot
3. **Scale numeric features** - StandardScaler (required for SVM, k-NN, Logistic Regression)
4. **Split train/test** - Use stratify for balanced classes
5. **Check class balance** - Consider SMOTE or class weights if imbalanced

## Common Issues and Solutions

**Problem:** Model overfits (high train accuracy, low test accuracy)
- **Solution:** Reduce model complexity (max_depth, n_estimators), add regularization, use cross-validation

**Problem:** Model underfits (low accuracy on both train and test)
- **Solution:** Increase model complexity, add features, try different algorithm

**Problem:** Class imbalance (many more normal than attack samples)
- **Solution:** Use class_weight parameter, SMOTE oversampling, or focus on recall/F1 instead of accuracy

**Problem:** Slow training time
- **Solution:** Use Random Forest instead of SVM, reduce n_estimators, use subset of data, enable parallel processing (n_jobs=-1)

**Problem:** Poor recall (missing attacks)
- **Solution:** Adjust classification threshold lower, use recall-optimized metrics, try ensemble methods

## Next Steps

1. **Start with a baseline** - Logistic Regression or Random Forest
2. **Evaluate thoroughly** - Check all metrics, not just accuracy
3. **Compare algorithms** - Use compare_algorithms.py to test multiple models
4. **Tune hyperparameters** - Use GridSearchCV or RandomizedSearchCV
5. **Consider ensembles** - Combine models for best performance
6. **Monitor in production** - Track performance drift over time

## References

- NSL-KDD Dataset: https://github.com/Mamcose/NSL-KDD-Network-Intrusion-Detection
- Phishing Websites Dataset: OpenML ID 4534
- scikit-learn Documentation: https://scikit-learn.org
- XGBoost: https://xgboost.readthedocs.io
- LightGBM: https://lightgbm.readthedocs.io
