"""
Train logistic regression (binary) and decision tree (multi‑class) models
using the 16 features defined in feature_extractor.dart.
Outputs JSON files in the format expected by the Dart threat engine.
"""

import pandas as pd
import numpy as np
import json
from sklearn.linear_model import LogisticRegression
from sklearn.tree import DecisionTreeClassifier, export_text, _tree

# ============================================================================
# 1. Configuration – YOU MUST ADAPT THESE!
# ============================================================================

# Path to your dataset CSV (65 features + label)
DATASET_PATH = "dataset.csv"  # or full path

# Column indices of the 16 features (0‑based) in the order used by feature_extractor.dart:
# 0: length
# 1: domainLength
# 2: subdomainLength
# 3: numDots
# 4: numHyphens
# 5: numUnderscores
# 6: numSlashes
# 7: numQuestionMarks
# 8: numEquals
# 9: numAmpersands
# 10: numAt
# 11: numPercent
# 12: hasIp (should be 0/1)
# 13: hasPort (0/1)
# 14: hasHttps (0/1)
# 15: entropy
FEATURE_INDICES = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]

# Label column index (0‑based). Assumes labels are integers: 0=benign, 1=defacement, 2=phishing, 3=malware
LABEL_INDEX = -1  # last column, change if needed

# ============================================================================
# 2. Load dataset and select features
# ============================================================================

print("Loading dataset...")
df = pd.read_csv(DATASET_PATH)
print(f"Dataset shape: {df.shape}")

# Extract features and labels
X_all = df.iloc[:, :-1].values  # assume label is last column
y_all = df.iloc[:, -1].values

# Select only the 16 features we use in Dart
X = X_all[:, FEATURE_INDICES]
print(f"Selected feature matrix shape: {X.shape}")

# ============================================================================
# 3. Train binary logistic regression (malicious vs benign)
# ============================================================================

print("\nTraining logistic regression (binary)...")
y_binary = (y_all != 0).astype(int)  # 1 = any malicious, 0 = benign

lr = LogisticRegression(max_iter=1000, random_state=42)
lr.fit(X, y_binary)

weights = lr.coef_[0].tolist()
bias = lr.intercept_[0].item()

# Save to JSON
lr_json = {"weights": weights, "bias": bias}
with open("logistic_regression_weights.json", "w") as f:
    json.dump(lr_json, f, indent=2)
print("Saved logistic_regression_weights.json")

# ============================================================================
# 4. Train multi‑class decision tree
# ============================================================================

print("\nTraining decision tree (multi‑class)...")
dt = DecisionTreeClassifier(max_depth=10, random_state=42)  # you can adjust max_depth
dt.fit(X, y_all)

# ============================================================================
# 5. Export decision tree to JSON (recursive node structure)
# ============================================================================

def tree_to_dict(tree, feature_names=None):
    """Convert a scikit-learn decision tree to a JSON‑serializable dictionary."""
    tree_ = tree.tree_
    feature_name = [
        feature_names[i] if feature_names is not None else f"feature_{i}"
        for i in tree_.feature
    ]

    def recurse(node, depth):
        if tree_.feature[node] != _tree.TREE_UNDEFINED:
            name = feature_name[node]
            threshold = tree_.threshold[node]
            left = recurse(tree_.children_left[node], depth + 1)
            right = recurse(tree_.children_right[node], depth + 1)
            return {
                "feature": node,  # actually we need feature index, not node index
                "threshold": threshold,
                "left": left,
                "right": right
            }
        else:
            # Leaf node – output class distribution (or majority class)
            # We'll store the probability distribution from value
            # value is [n_samples, n_classes] but in leaf it's a list
            # We'll compute the class distribution as probabilities
            counts = tree_.value[node][0]  # shape (n_classes,)
            total = counts.sum()
            if total > 0:
                probs = (counts / total).tolist()
            else:
                probs = [0.0] * len(counts)
            return {
                "distribution": probs
            }

    # Build dictionary starting at root (node 0)
    tree_dict = recurse(0, 0)
    # Remove the "feature" key that contains node index – we need actual feature index.
    # In scikit-learn, tree_.feature[node] gives the feature index used for splitting.
    # Let's rewrite recurse to store that.
    # Better to use a more accurate recursion.
    # We'll define a new function that uses the tree's feature indices.
    
    def build_node(node):
        if tree_.feature[node] != _tree.TREE_UNDEFINED:
            # Internal node
            feature_idx = int(tree_.feature[node])
            threshold = float(tree_.threshold[node])
            left_node = build_node(tree_.children_left[node])
            right_node = build_node(tree_.children_right[node])
            return {
                "feature": feature_idx,
                "threshold": threshold,
                "left": left_node,
                "right": right_node
            }
        else:
            # Leaf node: store class distribution
            counts = tree_.value[node][0]
            total = counts.sum()
            probs = (counts / total).tolist() if total > 0 else [0.0] * len(counts)
            return {"distribution": probs}
    
    tree_dict = build_node(0)
    return tree_dict

print("Converting tree to JSON...")
tree_json = tree_to_dict(dt)
with open("decision_tree.json", "w") as f:
    json.dump(tree_json, f, indent=2)
print("Saved decision_tree.json")

print("\n Training complete. JSON files are ready to copy to assets/models/.")