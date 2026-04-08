# train_full_features.py
# ===============================
# Enhanced training using class_weight (no oversampling), stratified subset tuning,
# and threshold tuning for XGBoost. Saves model files for Dart inference and generates performance plots.
# Now includes LightGBM training and export.
# All files are saved to the project root's assets/ directory.
# ===============================

import pandas as pd
import numpy as np
import json
import os
from sklearn.model_selection import train_test_split, StratifiedShuffleSplit, RandomizedSearchCV
from sklearn.preprocessing import StandardScaler
from sklearn.linear_model import LogisticRegression as SklearnLR
from sklearn.tree import DecisionTreeClassifier
from sklearn.ensemble import RandomForestClassifier, VotingClassifier
from sklearn.metrics import classification_report, confusion_matrix
import xgboost as xgb
import lightgbm as lgb
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
warnings.filterwarnings('ignore')

# ----------------------------------------------------------------------
# Determine project root (two levels up from this script's location)
# Assumes script is in python/ subfolder of project root
# ----------------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)  # goes up one level from python/ to project root
ASSETS_DIR = os.path.join(PROJECT_ROOT, 'assets', 'models')
PLOTS_DIR = os.path.join(PROJECT_ROOT, 'assets', 'plots')
os.makedirs(ASSETS_DIR, exist_ok=True)
os.makedirs(PLOTS_DIR, exist_ok=True)

print(f"Project root: {PROJECT_ROOT}")
print(f"Models will be saved to: {ASSETS_DIR}")
print(f"Plots will be saved to: {PLOTS_DIR}")

# -------------------------------
# Load dataset
# -------------------------------
dataset_path = os.path.join(PROJECT_ROOT, 'data', 'dataset.csv')
print(f"Looking for dataset at: {dataset_path}")

df = pd.read_csv(dataset_path)

print("\n=== Dataset Info ===")
print(f"Shape: {df.shape}")
print("Unique labels:\n", df['label'].value_counts())

# -------------------------------
# Select features & target
# -------------------------------
features = [
    'url_len', '@', '?', '-', '=', '.', '#', '%', '+', '$', '!', '*', ',', '//', 'digits', 'letters',
    'abnormal_url', 'https', 'Shortining_Service', 'having_ip_address', 'web_http_status', 'web_is_live',
    'web_ext_ratio', 'web_unique_domains', 'web_favicon', 'web_csp', 'web_xframe', 'web_hsts', 'web_xcontent',
    'web_security_score', 'web_forms_count', 'web_password_fields', 'web_hidden_inputs', 'web_has_login',
    'web_ssl_valid', 'phish_urgency_words', 'phish_security_words', 'phish_brand_mentions', 'phish_brand_hijack',
    'phish_multiple_subdomains', 'phish_long_path', 'phish_many_params', 'phish_suspicious_tld',
    'phish_adv_exact_brand_match', 'phish_adv_brand_in_subdomain', 'phish_adv_brand_in_path',
    'phish_adv_hyphen_count', 'phish_adv_number_count', 'phish_adv_suspicious_tld', 'phish_adv_long_domain',
    'phish_adv_many_subdomains', 'phish_adv_encoded_chars', 'phish_adv_path_keywords', 'phish_adv_has_redirect',
    'phish_adv_many_params', 'path_has_hacked_terms', 'suspicious_extension', 'path_underscore_count', 'is_gov_edu'
]

target = 'label'

X = df[features]
y = df[target]

# Convert to numeric, fill NaNs
X = X.apply(pd.to_numeric, errors='coerce').fillna(0)

# -------------------------------
# Split train/test (stratified)
# -------------------------------
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

# -------------------------------
# Create a stratified subset for hyperparameter tuning (e.g., 20% of training)
# -------------------------------
print("\n=== Creating stratified tuning subset ===")
sss = StratifiedShuffleSplit(n_splits=1, test_size=0.2, random_state=42)
for _, idx in sss.split(X_train, y_train):
    X_tune, y_tune = X_train.iloc[idx], y_train.iloc[idx]

print(f"Tuning set size: {X_tune.shape[0]} (≈{len(X_tune)/len(X_train)*100:.1f}% of training)")

# -------------------------------
# Feature scaling (fit on full training)
# -------------------------------
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)
X_tune_scaled = scaler.transform(X_tune)

# -------------------------------
# 1. Logistic Regression (tuned on subset, then retrained on full)
# -------------------------------
print("\n=== Tuning Logistic Regression on subset ===")
lr = SklearnLR(random_state=42, class_weight='balanced', max_iter=1000, solver='lbfgs')
param_grid_lr = {
    'C': [0.1, 1, 10],
    'solver': ['lbfgs', 'saga']
}
random_lr = RandomizedSearchCV(
    lr, param_grid_lr, n_iter=5, cv=3, scoring='f1_macro', n_jobs=-1, random_state=42
)
random_lr.fit(X_tune_scaled, y_tune)
best_lr = random_lr.best_estimator_
print(f"Best LR params: {random_lr.best_params_}")
print(f"Best CV macro F1: {random_lr.best_score_:.4f}")

# Retrain on full training set
print("Retraining LR on full training set...")
best_lr.fit(X_train_scaled, y_train)
y_pred_lr = best_lr.predict(X_test_scaled)
print("\n=== Logistic Regression Evaluation (final) ===")
print(classification_report(y_test, y_pred_lr, digits=2))

# -------------------------------
# 2. Decision Tree (tuned on subset, then retrained on full)
# -------------------------------
print("\n=== Tuning Decision Tree on subset ===")
dt = DecisionTreeClassifier(random_state=42, class_weight='balanced')
param_dist_dt = {
    'max_depth': [10, 15, 20, 25],
    'min_samples_split': [2, 5, 10],
    'min_samples_leaf': [1, 2, 4],
    'criterion': ['gini', 'entropy']
}
random_dt = RandomizedSearchCV(
    dt, param_dist_dt, n_iter=10, cv=3, scoring='f1_macro', n_jobs=-1, random_state=42
)
random_dt.fit(X_tune, y_tune)          # Decision Tree does not need scaling
best_dt = random_dt.best_estimator_
print(f"Best DT params: {random_dt.best_params_}")
print(f"Best CV macro F1: {random_dt.best_score_:.4f}")

# Retrain on full training set
print("Retraining DT on full training set...")
best_dt.fit(X_train, y_train)
y_pred_dt = best_dt.predict(X_test)
print("\n=== Decision Tree Evaluation (final) ===")
print(classification_report(y_test, y_pred_dt, digits=2))

# -------------------------------
# 3. XGBoost (tuned on subset, then retrained on full, with threshold tuning)
# -------------------------------
print("\n=== Tuning XGBoost on subset ===")
xgb_model = xgb.XGBClassifier(
    objective='multi:softprob', num_class=4, eval_metric='mlogloss', random_state=42
)
param_dist_xgb = {
    'n_estimators': [100, 200, 300],
    'max_depth': [4, 6, 8],
    'learning_rate': [0.05, 0.1, 0.2],
    'subsample': [0.7, 0.8, 1.0],
    'colsample_bytree': [0.7, 0.8, 1.0],
    'min_child_weight': [1, 3, 5]
}
random_xgb = RandomizedSearchCV(
    xgb_model, param_dist_xgb, n_iter=10, cv=3, scoring='f1_macro', n_jobs=-1, random_state=42
)
random_xgb.fit(X_tune_scaled, y_tune)
best_xgb = random_xgb.best_estimator_
print(f"Best XGBoost params: {random_xgb.best_params_}")
print(f"Best CV macro F1: {random_xgb.best_score_:.4f}")

# Retrain on full training set
print("Retraining XGBoost on full training set...")
best_xgb.fit(X_train_scaled, y_train)

# Threshold tuning
print("Applying threshold tuning for XGBoost...")
probs = best_xgb.predict_proba(X_test_scaled)
y_pred_xgb = []
for p in probs:
    if p[2] > 0.3:       # phishing threshold
        y_pred_xgb.append(2)
    elif p[3] > 0.5:     # malware threshold
        y_pred_xgb.append(3)
    else:
        y_pred_xgb.append(np.argmax(p))
y_pred_xgb = np.array(y_pred_xgb)

print("\n=== XGBoost Evaluation (final with thresholds) ===")
print(classification_report(y_test, y_pred_xgb, digits=2))

# -------------------------------
# 4. LightGBM – train and export to JSON
# -------------------------------
print("\n=== Training LightGBM ===")
lgb_model = lgb.LGBMClassifier(
    objective='multiclass',
    num_class=4,
    random_state=42,
    n_estimators=200,
    max_depth=6,
    learning_rate=0.1,
    subsample=0.8,
    colsample_bytree=0.8,
    reg_alpha=0.1,
    reg_lambda=0.1,
    class_weight='balanced'
)
lgb_model.fit(X_train_scaled, y_train)
y_pred_lgb = lgb_model.predict(X_test_scaled)
print("\n=== LightGBM Evaluation ===")
print(classification_report(y_test, y_pred_lgb, digits=2))

# Helper to recursively parse LightGBM tree into a serializable dict
def parse_lgb_tree(node):
    if 'leaf_value' in node:
        return {'leaf': True, 'value': node['leaf_value']}
    else:
        return {
            'leaf': False,
            'feature': node['split_feature'],
            'threshold': node['threshold'],
            'left': parse_lgb_tree(node['left_child']),
            'right': parse_lgb_tree(node['right_child'])
        }

# Export LightGBM model to JSON for Dart (saves to ASSETS_DIR)
def export_lgb_to_json(model, output_path):
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    booster = model.booster_
    num_class = model.n_classes_
    tree_infos = booster.dump_model()['tree_info']
    all_trees = []
    for info in tree_infos:
        all_trees.append(parse_lgb_tree(info['tree_structure']))
    class_trees = []
    for c in range(num_class):
        class_trees.append(all_trees[c::num_class])
    model_dict = {
        'num_class': num_class,
        'class_trees': class_trees
    }
    with open(output_path, 'w') as f:
        json.dump(model_dict, f, indent=2)
    print(f"Exported LightGBM model to {output_path}")

lgb_output = os.path.join(ASSETS_DIR, 'lightgbm_model.json')
export_lgb_to_json(lgb_model, lgb_output)

# -------------------------------
# 5. Voting Ensemble (LR + DT + XGB) – for comparison
# -------------------------------
print("\n=== Training Voting Classifier (LR + DT + XGB) ===")
voting_clf = VotingClassifier(
    estimators=[('lr', best_lr), ('dt', best_dt), ('xgb', best_xgb)],
    voting='soft'
)
voting_clf.fit(X_train_scaled, y_train)
y_pred_ens = voting_clf.predict(X_test_scaled)
print("\n=== Voting Ensemble Evaluation ===")
print(classification_report(y_test, y_pred_ens, digits=2))

# -------------------------------
# Generate performance plots (for XGBoost as example)
# -------------------------------
print("\n=== Generating performance plots ===")
y_pred_for_plots = y_pred_xgb
model_name = "XGBoost_with_thresholds"

# Bar chart
report_dict = classification_report(y_test, y_pred_for_plots, output_dict=True)
classes = [str(c) for c in sorted(report_dict.keys()) if c.isdigit()]
precision = [report_dict[c]['precision'] for c in classes]
recall = [report_dict[c]['recall'] for c in classes]
f1 = [report_dict[c]['f1-score'] for c in classes]

x = np.arange(len(classes))
width = 0.25

fig, ax = plt.subplots(figsize=(10, 6))
bars1 = ax.bar(x - width, precision, width, label='Precision')
bars2 = ax.bar(x, recall, width, label='Recall')
bars3 = ax.bar(x + width, f1, width, label='F1-score')

ax.set_xlabel('Class')
ax.set_ylabel('Score')
ax.set_title(f'{model_name} Performance per Class')
ax.set_xticks(x)
ax.set_xticklabels(['Safe (0)', 'Suspicious (1)', 'Phishing (2)', 'Malware (3)'])
ax.legend()
ax.set_ylim(0, 1)

for bars in [bars1, bars2, bars3]:
    for bar in bars:
        height = bar.get_height()
        ax.annotate(f'{height:.2f}',
                    xy=(bar.get_x() + bar.get_width() / 2, height),
                    xytext=(0, 3),
                    textcoords="offset points",
                    ha='center', va='bottom')

plt.tight_layout()
plt.savefig(os.path.join(PLOTS_DIR, f"{model_name.lower()}_performance.png"), dpi=150)
plt.close()
print(f"Saved performance bar chart to {PLOTS_DIR}/{model_name.lower()}_performance.png")

# Confusion matrix heatmap
cm = confusion_matrix(y_test, y_pred_for_plots)
cm_percent = cm.astype('float') / cm.sum(axis=1)[:, np.newaxis] * 100

plt.figure(figsize=(8, 6))
sns.heatmap(cm_percent, annot=True, fmt='.1f', cmap='Blues',
            xticklabels=['Safe', 'Suspicious', 'Phishing', 'Malware'],
            yticklabels=['Safe', 'Suspicious', 'Phishing', 'Malware'])
plt.title(f'{model_name} Confusion Matrix (Row Percentages)')
plt.ylabel('Actual Label')
plt.xlabel('Predicted Label')
plt.tight_layout()
plt.savefig(os.path.join(PLOTS_DIR, f"{model_name.lower()}_confusion_matrix.png"), dpi=150)
plt.close()
print(f"Saved confusion matrix heatmap to {PLOTS_DIR}/{model_name.lower()}_confusion_matrix.png")

# -------------------------------
# Save all model files for Dart engine (to ASSETS_DIR)
# -------------------------------
print("\n=== Saving model files ===")

# Scaler
scaler_params = {
    "mean": scaler.mean_.tolist(),
    "scale": scaler.scale_.tolist()
}
with open(os.path.join(ASSETS_DIR, "scaler_params.json"), "w") as f:
    json.dump(scaler_params, f)
print("Saved scaler_params.json")

# Logistic Regression
lr_weights = {
    "weights": best_lr.coef_.tolist(),
    "bias": best_lr.intercept_.tolist(),
    "classes": best_lr.classes_.tolist()
}
with open(os.path.join(ASSETS_DIR, "logistic_regression_weights.json"), "w") as f:
    json.dump(lr_weights, f)
print("Saved logistic_regression_weights.json")

# Decision Tree
def export_tree(tree, classes):
    return {
        "feature": tree.feature.tolist(),
        "threshold": tree.threshold.tolist(),
        "children_left": tree.children_left.tolist(),
        "children_right": tree.children_right.tolist(),
        "value": tree.value.tolist(),
        "n_node_samples": tree.n_node_samples.tolist(),
        "classes": classes.tolist()
    }

tree_dict = {
    "tree": export_tree(best_dt.tree_, best_dt.classes_),
    "n_features": best_dt.n_features_in_,
    "n_classes": len(best_dt.classes_)
}
with open(os.path.join(ASSETS_DIR, "decision_tree.json"), "w") as f:
    json.dump(tree_dict, f)
print("Saved decision_tree.json")

# XGBoost
best_xgb.save_model(os.path.join(ASSETS_DIR, "xgboost_model.json"))
print("Saved xgboost_model.json")

print(f"\nAll model files saved to {ASSETS_DIR}")