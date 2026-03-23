#!/usr/bin/env python3
"""
Train a pre-trained LLM for text classification.

This script:
1. Loads a pre-trained model (e.g., GPT2)
2. Replaces the output head with a classification layer
3. Freezes most parameters
4. Trains on your prepared dataset
5. Evaluates on validation and test sets

Usage:
    python train_classifier.py --data-dir prepared_data/ --model-path gpt2.pth --output trained_model/
"""

import argparse
import json
import os
from pathlib import Path
from typing import Optional
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset


# Simple GPT-like model structure (replace with your actual model)
class GPTModel(nn.Module):
    def __init__(self, config):
        super().__init__()
        self.emb_dim = config["emb_dim"]
        self.trf_blocks = nn.ModuleList([
            nn.TransformerEncoderLayer(d_model=config["emb_dim"], nhead=config["n_heads"])
            for _ in range(config["n_layers"])
        ])
        self.final_norm = nn.LayerNorm(config["emb_dim"])
        self.out_head = nn.Linear(config["emb_dim"], config["vocab_size"])
    
    def forward(self, x):
        # x: (batch, seq_len)
        # Simplified forward pass
        batch_size, seq_len = x.shape
        # Embedding (simplified)
        embedded = torch.randn(batch_size, seq_len, self.emb_dim, device=x.device)
        # Transformer blocks
        for block in self.trf_blocks:
            embedded = block(embedded)
        # Final norm
        embedded = self.final_norm(embedded)
        # Output head
        logits = self.out_head(embedded)
        return logits  # (batch, seq_len, vocab_size)


def load_prepared_data(data_dir: str, split: str, device: str) -> DataLoader:
    """Load prepared data from JSON files."""
    filepath = Path(data_dir) / f"{split}.json"
    with open(filepath, "r") as f:
        data = json.load(f)
    
    inputs = torch.tensor(data["inputs"], dtype=torch.long)
    labels = torch.tensor(data["labels"], dtype=torch.long)
    
    dataset = TensorDataset(inputs, labels)
    dataloader = DataLoader(dataset, batch_size=32, shuffle=(split == "train"))
    
    return dataloader


def load_model(config_path: str, weights_path: str) -> GPTModel:
    """Load pre-trained model."""
    with open(config_path, "r") as f:
        config = json.load(f)
    
    model = GPTModel(config)
    model.load_state_dict(torch.load(weights_path, map_location="cpu"))
    return model


def replace_output_head(model: GPTModel, num_classes: int) -> None:
    """Replace the vocabulary output with classification head."""
    model.out_head = nn.Linear(
        in_features=model.emb_dim,
        out_features=num_classes
    )
    print(f"Replaced output head: {num_classes} classes")


def freeze_parameters(model: GPTModel) -> None:
    """Freeze all parameters except final layers."""
    # Freeze all parameters
    for param in model.parameters():
        param.requires_grad = False
    
    # Unfreeze last transformer block
    for param in model.trf_blocks[-1].parameters():
        param.requires_grad = True
    
    # Unfreeze final norm
    for param in model.final_norm.parameters():
        param.requires_grad = True
    
    # Unfreeze output head
    for param in model.out_head.parameters():
        param.requires_grad = True
    
    # Count trainable parameters
    trainable = sum(p.numel() for p in model.parameters() if p.requires_grad)
    total = sum(p.numel() for p in model.parameters())
    print(f"Trainable parameters: {trainable:,} / {total:,} ({100*trainable/total:.1f}%)")


def calc_loss_batch(input_batch, target_batch, model, device):
    """Calculate loss for classification (only last token)."""
    input_batch, target_batch = input_batch.to(device), target_batch.to(device)
    logits = model(input_batch)[:, -1, :]  # Last token only
    loss = nn.functional.cross_entropy(logits, target_batch)
    return loss


def calc_accuracy_loader(data_loader, model, device, num_batches=None):
    """Calculate accuracy on a data loader."""
    model.eval()
    correct_predictions, num_examples = 0, 0
    
    if num_batches is None:
        num_batches = len(data_loader)
    else:
        num_batches = min(num_batches, len(data_loader))
    
    for i, (input_batch, target_batch) in enumerate(data_loader):
        if i < num_batches:
            input_batch, target_batch = input_batch.to(device), target_batch.to(device)
            
            with torch.no_grad():
                logits = model(input_batch)[:, -1, :]
                predicted_labels = torch.argmax(logits, dim=-1)
            
            num_examples += predicted_labels.shape[0]
            correct_predictions += (predicted_labels == target_batch).sum().item()
        else:
            break
    
    return correct_predictions / num_examples


def train_model(
    model: GPTModel,
    train_loader: DataLoader,
    val_loader: DataLoader,
    device: str,
    epochs: int = 10,
    learning_rate: float = 1e-5,
    save_dir: Optional[str] = None
) -> None:
    """Train the classification model."""
    model = model.to(device)
    optimizer = optim.Adam(
        filter(lambda p: p.requires_grad, model.parameters()),
        lr=learning_rate
    )
    
    best_val_accuracy = 0.0
    
    for epoch in range(epochs):
        model.train()
        total_loss = 0
        num_batches = 0
        
        for input_batch, target_batch in train_loader:
            optimizer.zero_grad()
            loss = calc_loss_batch(input_batch, target_batch, model, device)
            loss.backward()
            optimizer.step()
            
            total_loss += loss.item()
            num_batches += 1
        
        avg_loss = total_loss / num_batches
        
        # Evaluate on validation set
        val_accuracy = calc_accuracy_loader(val_loader, model, device)
        
        print(f"Epoch {epoch+1}/{epochs}: Loss={avg_loss:.4f}, Val Accuracy={val_accuracy:.4f}")
        
        # Save best model
        if val_accuracy > best_val_accuracy:
            best_val_accuracy = val_accuracy
            if save_dir:
                save_path = Path(save_dir) / "best_model.pth"
                torch.save(model.state_dict(), save_path)
                print(f"  Saved best model to {save_path}")


def evaluate_model(
    model: GPTModel,
    test_loader: DataLoader,
    device: str
) -> float:
    """Evaluate model on test set."""
    accuracy = calc_accuracy_loader(test_loader, model, device)
    print(f"\nTest Accuracy: {accuracy:.4f}")
    return accuracy


def main():
    parser = argparse.ArgumentParser(description="Train LLM for text classification")
    parser.add_argument("--data-dir", required=True, help="Directory with prepared data")
    parser.add_argument("--model-path", required=True, help="Path to pre-trained model weights")
    parser.add_argument("--config-path", required=True, help="Path to model config JSON")
    parser.add_argument("--output", required=True, help="Output directory for trained model")
    parser.add_argument("--epochs", type=int, default=10, help="Number of training epochs")
    parser.add_argument("--learning-rate", type=float, default=1e-5, help="Learning rate")
    parser.add_argument("--device", default="cuda" if torch.cuda.is_available() else "cpu", help="Device to use")
    
    args = parser.parse_args()
    
    # Load metadata
    metadata_path = Path(args.data_dir) / "metadata.json"
    with open(metadata_path, "r") as f:
        metadata = json.load(f)
    
    num_classes = metadata["num_classes"]
    print(f"Number of classes: {num_classes}")
    
    # Load model
    print("Loading pre-trained model...")
    model = load_model(args.config_path, args.model_path)
    
    # Replace output head
    replace_output_head(model, num_classes)
    
    # Freeze parameters
    freeze_parameters(model)
    
    # Load data
    print("Loading data...")
    train_loader = load_prepared_data(args.data_dir, "train", args.device)
    val_loader = load_prepared_data(args.data_dir, "val", args.device)
    test_loader = load_prepared_data(args.data_dir, "test", args.device)
    
    # Create output directory
    output_path = Path(args.output)
    output_path.mkdir(parents=True, exist_ok=True)
    
    # Train
    print("\nTraining...")
    train_model(
        model, train_loader, val_loader, args.device,
        epochs=args.epochs,
        learning_rate=args.learning_rate,
        save_dir=args.output
    )
    
    # Evaluate on test set
    print("\nEvaluating on test set...")
    model.load_state_dict(torch.load(output_path / "best_model.pth", map_location=args.device))
    test_accuracy = evaluate_model(model, test_loader, args.device)
    
    # Save final results
    results = {
        "test_accuracy": test_accuracy,
        "num_classes": num_classes,
        "epochs": args.epochs,
        "learning_rate": args.learning_rate
    }
    results_path = output_path / "results.json"
    with open(results_path, "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nResults saved to {results_path}")
    print("Training complete!")


if __name__ == "__main__":
    main()
