---
name: ml-data-prep-eval
description: Prepare and evaluate machine learning data. Use this skill whenever the user needs to clean, transform, or split datasets for ML training, or evaluate model performance with metrics like accuracy, precision, recall, F1, ROC-AUC, MAE, or confusion matrices. Trigger for any data preprocessing task, feature engineering, handling missing values, encoding categorical variables, normalization, or model evaluation requests.
---

# ML Data Preparation & Evaluation

This skill helps you prepare raw data for machine learning and evaluate model performance. Follow the workflow below for systematic data preparation.

## Quick Start

```bash
# Clean and prepare your data
python scripts/data_cleaning.py --input data.csv --output cleaned_data.csv

# Transform features
python scripts/data_transformation.py --input cleaned_data.csv --output transformed_data.csv

# Split for training
python scripts/data_splitting.py --input transformed_data.csv --train-ratio 0.7 --val-ratio 0.15

# Evaluate model predictions
python scripts/model_evaluation.py --actual actual.csv --predicted predictions.csv
```

## Workflow Overview

1. **Data Collection** → Gather from databases, APIs, files, or web scraping
2. **Data Cleaning** → Handle missing values, remove duplicates, filter outliers
3. **Data Transformation** → Normalize, encode, engineer features
4. **Data Splitting** → Create train/validation/test sets
5. **Model Evaluation** → Calculate performance metrics

---

## 1. Data Collection

### Supported Sources

| Source | Method | Example |
|--------|--------|---------|
| CSV/JSON files | `pandas.read_csv()` | `pd.read_csv('data.csv')` |
| SQL databases | `sqlalchemy` | `pd.read_sql(query, connection)` |
| APIs | `requests` | `requests.get(url).json()` |
| Web scraping | `beautifulsoup4` | `BeautifulSoup(html, 'html.parser')` |

### Best Practices

- Validate data types immediately after loading
- Check for encoding issues (UTF-8 is standard)
- Log the number of records collected
- Store metadata about collection time and source

---

## 2. Data Cleaning

### Missing Values

**Strategies by data type:**

| Type | Strategy | When to use |
|------|----------|-------------|
| Numeric | Mean/Median imputation | Small gaps, normal distribution |
| Numeric | KNN imputation | Complex relationships between features |
| Categorical | Mode (most frequent) | When category matters |
| Categorical | New category "Unknown" | When missingness is meaningful |
| Any | Drop rows/columns | When >50% missing or not critical |

**Use the cleaning script:**
```bash
python scripts/data_cleaning.py \
  --input data.csv \
  --numeric-strategy median \
  --categorical-strategy most_frequent \
  --remove-duplicates \
  --filter-outliers zscore:3
```

### Duplicates

- Always check for exact duplicates: `df.drop_duplicates()`
- Check for near-duplicates on key columns
- Decide whether to keep first, last, or aggregate

### Outliers

**Detection methods:**

| Method | Use case | Threshold |
|--------|----------|----------|
| Z-score | Normal distribution | |z| > 3 |
| IQR | Skewed distribution | Q1 - 1.5×IQR, Q3 + 1.5×IQR |
| Box plot | Visual inspection | Whisker bounds |

**Decision framework:**
- **Remove** if clearly erroneous (e.g., age = 200)
- **Transform** if valid but extreme (log transform)
- **Keep** if legitimate edge cases (fraud detection)

---

## 3. Data Transformation

### Normalization & Standardization

| Method | Formula | Range | Use when |
|--------|---------|-------|----------|
| Min-Max | `(X - min) / (max - min)` | [0, 1] | Neural networks, distance-based algorithms |
| Z-Score | `(X - μ) / σ` | Mean=0, Std=1 | Linear models, when outliers exist |
| Robust | `(X - median) / IQR` | - | Heavy outliers |

**Script usage:**
```bash
python scripts/data_transformation.py \
  --input cleaned_data.csv \
  --normalize zscore \
  --columns "feature1,feature2,feature3"
```

### Encoding Categorical Variables

| Method | Output | Use when |
|--------|--------|----------|
| One-Hot | Binary columns | Low cardinality (<10 categories) |
| Label | Integer 0,1,2... | Ordinal data or tree models |
| Ordinal | Ordered integers | Natural ordering exists |
| Target | Mean of target | High cardinality, supervised learning |
| Hashing | Fixed-size vector | Very high cardinality |

**Text encoding:**
- **Bag of Words**: Simple word counts
- **TF-IDF**: Weighted by document frequency
- **Bigrams/Trigrams**: Capture word sequences

### Feature Engineering

**Common patterns:**

```python
# Date/time features
df['hour'] = df['timestamp'].dt.hour
df['day_of_week'] = df['timestamp'].dt.dayofweek
df['is_weekend'] = df['day_of_week'].isin([5, 6])

# Ratios and combinations
df['price_per_sqft'] = df['price'] / df['sqft']
df['total_value'] = df['quantity'] * df['unit_price']

# Binning
df['age_group'] = pd.cut(df['age'], bins=[0, 18, 35, 50, 100], 
                         labels=['child', 'young', 'middle', 'senior'])
```

---

## 4. Data Splitting

### Standard Split Ratios

| Dataset Size | Train | Validation | Test |
|--------------|-------|------------|------|
| Small (<10K) | 70% | 15% | 15% |
| Medium (10K-100K) | 80% | 10% | 10% |
| Large (>100K) | 90% | 5% | 5% |

### Splitting Strategies

**Stratified Split** (classification with imbalanced classes):
```bash
python scripts/data_splitting.py \
  --input data.csv \
  --stratify target_column \
  --train-ratio 0.7 \
  --val-ratio 0.15
```

**Time Series Split** (temporal data):
- Train on earlier periods
- Test on later periods
- Never shuffle time series data

**K-Fold Cross-Validation** (small datasets):
- K=5 or K=10 typical
- Each fold used once as validation
- Average metrics across folds

---

## 5. Model Evaluation

### Classification Metrics

| Metric | Formula | Best for |
|--------|---------|----------|
| Accuracy | `(TP+TN) / Total` | Balanced classes |
| Precision | `TP / (TP+FP)` | Costly false positives |
| Recall | `TP / (TP+FN)` | Costly false negatives |
| F1 Score | `2×(P×R)/(P+R)` | Imbalanced classes |
| ROC-AUC | Area under ROC curve | Threshold-independent comparison |
| MCC | Correlation coefficient | Imbalanced, all confusion matrix cells |
| Specificity | `TN / (TN+FP)` | Costly false positives |

**Script usage:**
```bash
python scripts/model_evaluation.py \
  --actual actual_labels.csv \
  --predicted predictions.csv \
  --metrics "accuracy,precision,recall,f1,roc_auc,mcc"
```

### Regression Metrics

| Metric | Formula | Interpretation |
|--------|---------|----------------|
| MAE | `mean(|y - ŷ|)` | Average error in original units |
| MSE | `mean((y - ŷ)²)` | Penalizes large errors |
| RMSE | `sqrt(MSE)` | Error in original units |
| R² | `1 - SS_res/SS_tot` | Proportion of variance explained |

### Confusion Matrix

```
                Predicted
              Positive  Negative
Actual Positive    TP        FN
Actual Negative    FP        TN
```

**Key insights:**
- **High FP**: Model is too aggressive (lower threshold)
- **High FN**: Model is too conservative (raise threshold)
- **Diagonal dominance**: Good performance
- **Off-diagonal patterns**: Systematic errors to investigate

---

## Common Patterns & Pitfalls

### ✅ Do

- Always split data BEFORE any feature engineering
- Use stratified splits for imbalanced classification
- Keep test set completely untouched until final evaluation
- Document all transformations for reproducibility
- Check for data leakage (future info in training)

### ❌ Don't

- Don't normalize using test set statistics
- Don't impute missing values after splitting (fit on train only)
- Don't use accuracy for imbalanced datasets
- Don't evaluate on training data only
- Don't shuffle time series data

### ⚠️ Watch Out For

- **Data leakage**: Target information in features
- **Target imbalance**: Use appropriate metrics (F1, MCC, ROC-AUC)
- **Overfitting**: Large gap between train and test performance
- **Underfitting**: Poor performance on both train and test
- **Feature scaling**: Always scale before distance-based algorithms

---

## Quick Reference

### When to use which metric

| Scenario | Primary Metric | Secondary Metric |
|----------|---------------|------------------|
| Balanced classification | Accuracy | F1 Score |
| Imbalanced classification | F1 Score | ROC-AUC |
| Medical diagnosis | Recall | Precision |
| Fraud detection | Precision | Recall |
| Spam filtering | Recall | Specificity |
| Regression | MAE or RMSE | R² |
| Small dataset | MCC | F1 Score |

### Script Quick Commands

```bash
# Full pipeline
python scripts/data_cleaning.py -i raw.csv -o clean.csv --remove-duplicates --filter-outliers zscore:3
python scripts/data_transformation.py -i clean.csv -o prep.csv --normalize zscore --encode onehot
python scripts/data_splitting.py -i prep.csv --stratify target --train-ratio 0.8
python scripts/model_evaluation.py -a actual.csv -p pred.csv --metrics all
```

---

## Next Steps

After data preparation:
1. Train your model on the training set
2. Tune hyperparameters using validation set
3. Final evaluation on test set
4. Generate confusion matrix and detailed metrics
5. Analyze errors and iterate on features

For model training and deployment, consider using specialized ML frameworks (scikit-learn, TensorFlow, PyTorch).
