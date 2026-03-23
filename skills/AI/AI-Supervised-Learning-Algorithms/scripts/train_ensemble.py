#!/usr/bin/env python3
"""
Train ensemble models (voting or stacking) for cybersecurity tasks.

Usage:
    python train_ensemble.py --method voting --dataset phishing
    python train_ensemble.py --method stacking --dataset phishing
"""

import argparse
import pandas as pd
from sklearn.datasets import fetch_openml
from sklearn.model_selection import train_test_split
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeClassifier
from sklearn.neighbors import KNeighborsClassifier
from sklearn.ensemble import VotingClassifier, StackingClassifier, RandomForestClassifier
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score
import warnings
warnings.filterwarnings('ignore')

def load_phishing_dataset():
    """Load Phishing Websites dataset."""
    print("Loading Phishing Websites dataset...")
    data = fetch_openml(data_id=4534, as_frame=True)
    df = data.frame
    
    y = (df['Result'].astype(int) != 1).astype(int)
    X = df.drop(columns=['Result'])
    
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.20, random_state=42, stratify=y
    )
    
    print(f"Train: {len(X_train)}, Test: {len(X_test)}")
    return X_train, y_train, X_test, y_test

def get_base_learners():
    """Define base learners for ensemble."""
    return [
        ('lr', make_pipeline(
            StandardScaler(),
            LogisticRegression(max_iter=1000, solver='lbfgs', random_state=42)
        )),
        ('dt', DecisionTreeClassifier(max_depth=5, random_state=42)),
        ('knn', make_pipeline(
            StandardScaler(),
            KNeighborsClassifier(n_neighbors=5)
        ))
    ]

def train_voting_ensemble(X_train, y_train, X_test, y_test):
    """Train voting ensemble."""
    print("\nTraining Voting Ensemble...")
    
    base_learners = get_base_learners()
    
    # Hard voting (majority vote)
    voting_hard = VotingClassifier(estimators=base_learners, voting='hard')
    voting_hard.fit(X_train, y_train)
    
    # Soft voting (probability-based)
    voting_soft = VotingClassifier(estimators=base_learners, voting='soft')
    voting_soft.fit(X_train, y_train)
    
    # Evaluate hard voting
    y_pred_hard = voting_hard.predict(X_test)
    y_prob_hard = voting_hard.predict_proba(X_test)[:, 1]
    
    # Evaluate soft voting
    y_pred_soft = voting_soft.predict(X_test)
    y_prob_soft = voting_soft.predict_proba(X_test)[:, 1]
    
    print("\nHard Voting Results:")
    print(f"  Accuracy : {accuracy_score(y_test, y_pred_hard):.3f}")
    print(f"  Precision: {precision_score(y_test, y_pred_hard):.3f}")
    print(f"  Recall   : {recall_score(y_test, y_pred_hard):.3f}")
    print(f"  F1-score : {f1_score(y_test, y_pred_hard):.3f}")
    print(f"  ROC AUC  : {roc_auc_score(y_test, y_prob_hard):.3f}")
    
    print("\nSoft Voting Results:")
    print(f"  Accuracy : {accuracy_score(y_test, y_pred_soft):.3f}")
    print(f"  Precision: {precision_score(y_test, y_pred_soft):.3f}")
    print(f"  Recall   : {recall_score(y_test, y_pred_soft):.3f}")
    print(f"  F1-score : {f1_score(y_test, y_pred_soft):.3f}")
    print(f"  ROC AUC  : {roc_auc_score(y_test, y_prob_soft):.3f}")
    
    return {
        'hard_voting': {
            'accuracy': accuracy_score(y_test, y_pred_hard),
            'f1': f1_score(y_test, y_pred_hard),
            'roc_auc': roc_auc_score(y_test, y_prob_hard)
        },
        'soft_voting': {
            'accuracy': accuracy_score(y_test, y_pred_soft),
            'f1': f1_score(y_test, y_pred_soft),
            'roc_auc': roc_auc_score(y_test, y_prob_soft)
        }
    }

def train_stacking_ensemble(X_train, y_train, X_test, y_test):
    """Train stacking ensemble."""
    print("\nTraining Stacking Ensemble...")
    
    base_learners = get_base_learners()
    meta_learner = RandomForestClassifier(n_estimators=50, random_state=42)
    
    stack_model = StackingClassifier(
        estimators=base_learners,
        final_estimator=meta_learner,
        cv=5,
        passthrough=False
    )
    
    stack_model.fit(X_train, y_train)
    
    y_pred = stack_model.predict(X_test)
    y_prob = stack_model.predict_proba(X_test)[:, 1]
    
    print("\nStacking Results:")
    print(f"  Accuracy : {accuracy_score(y_test, y_pred):.3f}")
    print(f"  Precision: {precision_score(y_test, y_pred):.3f}")
    print(f"  Recall   : {recall_score(y_test, y_pred):.3f}")
    print(f"  F1-score : {f1_score(y_test, y_pred):.3f}")
    print(f"  ROC AUC  : {roc_auc_score(y_test, y_prob):.3f}")
    
    return {
        'stacking': {
            'accuracy': accuracy_score(y_test, y_pred),
            'f1': f1_score(y_test, y_pred),
            'roc_auc': roc_auc_score(y_test, y_prob)
        }
    }

def main():
    parser = argparse.ArgumentParser(description='Train ensemble models')
    parser.add_argument('--method', type=str, required=True,
                       choices=['voting', 'stacking'],
                       help='Ensemble method')
    parser.add_argument('--dataset', type=str, default='phishing',
                       choices=['phishing'],
                       help='Dataset to use')
    args = parser.parse_args()
    
    # Load data
    X_train, y_train, X_test, y_test = load_phishing_dataset()
    
    # Train ensemble
    if args.method == 'voting':
        results = train_voting_ensemble(X_train, y_train, X_test, y_test)
    else:
        results = train_stacking_ensemble(X_train, y_train, X_test, y_test)
    
    print(f"\n{'='*60}")
    print(f"Ensemble training complete!")
    print(f"{'='*60}")

if __name__ == '__main__':
    main()
