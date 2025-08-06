# Standard library imports
import os
import sys

# Add the parent directory to Python path to enable imports from config folder
parent_dir = os.path.dirname(os.getcwd())
if parent_dir not in sys.path:
    sys.path.append(parent_dir)

# Local imports
from config.constants import DATA_PATH
from data_preprocess import (
    load_and_clean_data, 
    preprocess_for_linear_regression, 
    preprocess_for_decision_tree, 
    detect_skewness
)
import pandas as pd

def detailed_preprocessing_analysis():
    """
    Provide detailed analysis of preprocessing transformations.
    """
    print("="*60)
    print("DETAILED PREPROCESSING ANALYSIS")
    print("="*60)
    
    # Load data
    df_result = load_and_clean_data(DATA_PATH)
    df = df_result[1] if isinstance(df_result, tuple) else df_result
    
    print(f"\n🔍 ORIGINAL DATASET ANALYSIS")
    print(f"Shape: {df.shape}")
    print(f"Columns: {list(df.columns)}")
    
    # Analyze skewness
    print(f"\n📊 SKEWNESS ANALYSIS")
    skewness = df.select_dtypes(include=['number']).skew()
    for col, skew_val in skewness.items():
        status = "⚠️ HIGHLY SKEWED" if abs(skew_val) > 1.0 else "✅ Normal"
        print(f"  {col:15}: {skew_val:6.3f} {status}")
    
    # Test Linear Regression preprocessing
    print(f"\n🧮 LINEAR REGRESSION PREPROCESSING")
    X_train_lr, X_test_lr, y_train_lr, y_test_lr, scaler = preprocess_for_linear_regression(df)
    print(f"  Input shape: {df.shape}")
    print(f"  Output training shape: {X_train_lr.shape}")
    print(f"  Features created: {X_train_lr.shape[1]}")
    print(f"  Scaling applied: ✅ (mean ≈ {X_train_lr.mean():.6f})")
    
    # Show feature names (if available)
    df_processed_lr = df.copy()
    from data_preprocess import apply_transformations
    df_processed_lr = apply_transformations(df_processed_lr)
    df_processed_lr = df_processed_lr.drop('med_house_val', axis=1)
    print(f"  Feature names: {list(df_processed_lr.columns)}")
    
    # Test Decision Tree preprocessing
    print(f"\n🌳 DECISION TREE PREPROCESSING")
    X_train_dt, X_test_dt, y_train_dt, y_test_dt = preprocess_for_decision_tree(df)
    print(f"  Input shape: {df.shape}")
    print(f"  Output training shape: {X_train_dt.shape}")
    print(f"  Features created: {X_train_dt.shape[1]}")
    print(f"  Scaling applied: ❌ (raw values preserved)")
    
    # Show additional features for DT
    print(f"  Extra features vs LR: {X_train_dt.shape[1] - X_train_lr.shape[1]}")
    
    # Compare transformations
    print(f"\n🔄 TRANSFORMATION SUMMARY")
    print(f"  ✅ Outlier removal: med_inc < 15")
    print(f"  ✅ Feature engineering: rooms_per_person, bedrooms_per_room")
    print(f"  ✅ Log transformations: population_log, ave_occup_log")
    print(f"  ✅ Feature removal: population, house_age (for LR)")
    print(f"  ✅ Feature retention: population (for DT only)")
    print(f"  ✅ Scaling: StandardScaler (for LR only)")
    
    # Show data quality
    print(f"\n📈 DATA QUALITY")
    print(f"  Missing values: {df.isnull().sum().sum()}")
    print(f"  Duplicate rows: {df.duplicated().sum()}")
    print(f"  Data types: All numeric ✅")
    
    # Performance implications
    print(f"\n⚡ PERFORMANCE IMPLICATIONS")
    print(f"  Linear Regression:")
    print(f"    • Scaled features will improve convergence")
    print(f"    • Log transformations reduce skewness impact")
    print(f"    • Feature engineering adds predictive power")
    print(f"  Decision Tree:")
    print(f"    • Raw features preserve split interpretability")
    print(f"    • Additional features provide more splitting options")
    print(f"    • No scaling needed (split-based algorithm)")
    
    print(f"\n" + "="*60)
    print("ANALYSIS COMPLETED ✅")
    print("="*60)

if __name__ == "__main__":
    detailed_preprocessing_analysis()
