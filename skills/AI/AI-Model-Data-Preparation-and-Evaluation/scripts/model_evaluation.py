#!/usr/bin/env python3
"""Model evaluation script for ML performance metrics.

Calculates accuracy, precision, recall, F1, ROC-AUC, MCC, MAE, and more.
"""

import argparse
import pandas as pd
import numpy as np
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    roc_auc_score, matthews_corrcoef, confusion_matrix,
    mean_absolute_error, mean_squared_error, r2_score,
    classification_report, roc_curve, precision_recall_curve
)
import json
import warnings
warnings.filterwarnings('ignore')


def load_labels(filepath):
    """Load labels from CSV file."""
    df = pd.read_csv(filepath)
    # Handle various column name formats
    if 'label' in df.columns:
        return df['label'].values
    elif 'actual' in df.columns:
        return df['actual'].values
    elif 'y_true' in df.columns:
        return df['y_true'].values
    elif 'target' in df.columns:
        return df['target'].values
    else:
        return df.iloc[:, 0].values


def load_predictions(filepath):
    """Load predictions from CSV file."""
    df = pd.read_csv(filepath)
    # Handle various column name formats
    if 'prediction' in df.columns:
        return df['prediction'].values
    elif 'predicted' in df.columns:
        return df['predicted'].values
    elif 'y_pred' in df.columns:
        return df['y_pred'].values
    elif 'output' in df.columns:
        return df['output'].values
    else:
        return df.iloc[:, 0].values


def calculate_classification_metrics(y_true, y_pred, y_prob=None, verbose=True):
    """Calculate classification metrics.
    
    Args:
        y_true: True labels
        y_pred: Predicted labels
        y_prob: Predicted probabilities (for ROC-AUC)
        verbose: Print metrics
    
    Returns:
        Dictionary of metrics
    """
    metrics = {}
    
    # Basic metrics
    metrics['accuracy'] = accuracy_score(y_true, y_pred)
    
    # Binary classification metrics
    try:
        metrics['precision'] = precision_score(y_true, y_pred, average='binary', zero_division=0)
        metrics['recall'] = recall_score(y_true, y_pred, average='binary', zero_division=0)
        metrics['f1'] = f1_score(y_true, y_pred, average='binary', zero_division=0)
    except:
        # Multi-class
        metrics['precision'] = precision_score(y_true, y_pred, average='weighted', zero_division=0)
        metrics['recall'] = recall_score(y_true, y_pred, average='weighted', zero_division=0)
        metrics['f1'] = f1_score(y_true, y_pred, average='weighted', zero_division=0)
    
    # ROC-AUC (requires probabilities)
    if y_prob is not None:
        try:
            metrics['roc_auc'] = roc_auc_score(y_true, y_prob)
        except:
            metrics['roc_auc'] = None
    else:
        metrics['roc_auc'] = None
    
    # Matthews Correlation Coefficient
    try:
        metrics['mcc'] = matthews_corrcoef(y_true, y_pred)
    except:
        metrics['mcc'] = None
    
    # Confusion matrix
    metrics['confusion_matrix'] = confusion_matrix(y_true, y_pred).tolist()
    
    if verbose:
        print("\n=== Classification Metrics ===")
        print(f"Accuracy:  {metrics['accuracy']:.4f}")
        print(f"Precision: {metrics['precision']:.4f}")
        print(f"Recall:    {metrics['recall']:.4f}")
        print(f"F1 Score:  {metrics['f1']:.4f}")
        if metrics['roc_auc'] is not None:
            print(f"ROC-AUC:   {metrics['roc_auc']:.4f}")
        if metrics['mcc'] is not None:
            print(f"MCC:       {metrics['mcc']:.4f}")
        print(f"\nConfusion Matrix:")
        print(f"  TP={metrics['confusion_matrix'][1][1]}, FN={metrics['confusion_matrix'][1][0]}")
        print(f"  FP={metrics['confusion_matrix'][0][1]}, TN={metrics['confusion_matrix'][0][0]}")
    
    return metrics


def calculate_regression_metrics(y_true, y_pred, verbose=True):
    """Calculate regression metrics.
    
    Args:
        y_true: True values
        y_pred: Predicted values
        verbose: Print metrics
    
    Returns:
        Dictionary of metrics
    """
    metrics = {}
    
    metrics['mae'] = mean_absolute_error(y_true, y_pred)
    metrics['mse'] = mean_squared_error(y_true, y_pred)
    metrics['rmse'] = np.sqrt(metrics['mse'])
    metrics['r2'] = r2_score(y_true, y_pred)
    
    if verbose:
        print("\n=== Regression Metrics ===")
        print(f"MAE:  {metrics['mae']:.4f}")
        print(f"MSE:  {metrics['mse']:.4f}")
        print(f"RMSE: {metrics['rmse']:.4f}")
        print(f"R²:   {metrics['r2']:.4f}")
    
    return metrics


def calculate_specificity(y_true, y_pred):
    """Calculate specificity (true negative rate).
    
    Args:
        y_true: True labels
        y_pred: Predicted labels
    
    Returns:
        Specificity value
    """
    tn, fp, fn, tp = confusion_matrix(y_true, y_pred).ravel()
    return tn / (tn + fp) if (tn + fp) > 0 else 0


def evaluate_model(actual_path, predicted_path, metric_type='classification',
                   probability_path=None, metrics='all', verbose=True):
    """Main evaluation pipeline.
    
    Args:
        actual_path: Path to actual labels
        predicted_path: Path to predictions
        metric_type: 'classification' or 'regression'
        probability_path: Path to probabilities (for ROC-AUC)
        metrics: Comma-separated list of metrics or 'all'
        verbose: Print metrics
    
    Returns:
        Dictionary of metrics
    """
    print(f"Loading actual labels from {actual_path}")
    y_true = load_labels(actual_path)
    
    print(f"Loading predictions from {predicted_path}")
    y_pred = load_predictions(predicted_path)
    
    # Load probabilities if provided
    y_prob = None
    if probability_path:
        print(f"Loading probabilities from {probability_path}")
        y_prob = load_predictions(probability_path)
    
    # Calculate metrics
    if metric_type == 'classification':
        metrics = calculate_classification_metrics(y_true, y_pred, y_prob, verbose)
    else:
        metrics = calculate_regression_metrics(y_true, y_pred, verbose)
    
    # Add specificity for classification
    if metric_type == 'classification':
        metrics['specificity'] = calculate_specificity(y_true, y_pred)
        if verbose:
            print(f"Specificity: {metrics['specificity']:.4f}")
    
    return metrics


def save_metrics(metrics, output_path):
    """Save metrics to JSON file."""
    with open(output_path, 'w') as f:
        json.dump(metrics, f, indent=2)
    print(f"\nMetrics saved to {output_path}")


def main():
    parser = argparse.ArgumentParser(description='Evaluate ML model')
    parser.add_argument('--actual', '-a', required=True, help='Path to actual labels')
    parser.add_argument('--predicted', '-p', required=True, help='Path to predictions')
    parser.add_argument('--probabilities', type=str, default=None,
                       help='Path to predicted probabilities (for ROC-AUC)')
    parser.add_argument('--type', type=str, default='classification',
                       choices=['classification', 'regression'],
                       help='Evaluation type')
    parser.add_argument('--metrics', type=str, default='all',
                       help='Metrics to calculate (comma-separated or "all")')
    parser.add_argument('--output', '-o', type=str, default=None,
                       help='Output JSON file path')
    parser.add_argument('--verbose', action='store_true', default=True,
                       help='Print metrics')
    
    args = parser.parse_args()
    
    metrics = evaluate_model(
        args.actual, args.predicted,
        metric_type=args.type,
        probability_path=args.probabilities,
        metrics=args.metrics,
        verbose=args.verbose
    )
    
    if args.output:
        save_metrics(metrics, args.output)


if __name__ == '__main__':
    main()
