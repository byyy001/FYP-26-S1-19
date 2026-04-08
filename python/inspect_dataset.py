import pandas as pd
import os

script_dir = os.path.dirname(os.path.abspath(__file__))
dataset_path = os.path.join(script_dir, "..", "data", "dataset.csv")

print(f"Looking for dataset at: {dataset_path}")

if not os.path.exists(dataset_path):
    print("ERROR: File not found.")
    exit(1)

df = pd.read_csv(dataset_path)

print("\n=== Dataset Info ===")
print(f"Shape: {df.shape}")
print("\nAll column names:")
for i, col in enumerate(df.columns):
    print(f"{i}: {col}")

print("\n=== First 5 rows (all columns) ===")
# Show all columns (may be wide, but we'll see)
print(df.head(5).to_string())

print("\n=== Unique values in 'type' column ===")
print(df['type'].value_counts())

print("\n=== Unique values in 'label' column (if exists) ===")
if 'label' in df.columns:
    print(df['label'].value_counts())
else:
    print("No 'label' column found.")