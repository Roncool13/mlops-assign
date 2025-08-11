import os
import sys
import joblib
import mlflow
import mlflow.sklearn
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.tree import DecisionTreeRegressor
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error

# Local imports
from config.constants import DATA_PATH
from src.data_preprocess import (
    load_and_clean_data, 
    preprocess_for_linear_regression, 
    preprocess_for_decision_tree
)

def setup_mlflow_clean():
    """Clean MLflow setup"""
    # Ensure clean start
    tracking_dir = "./mlruns"
    if os.path.exists(tracking_dir):
        import shutil
        shutil.rmtree(tracking_dir)
    
    # Set tracking URI
    mlflow.set_tracking_uri(f"file:{os.path.abspath(tracking_dir)}")
    
    # Create new experiment
    experiment_name = "california_housing"
    experiment_id = mlflow.create_experiment(experiment_name)
    mlflow.set_experiment(experiment_name)
    
    print(f"✅ Created clean MLflow experiment: {experiment_name}")
    print(f"📁 Tracking directory: {os.path.abspath(tracking_dir)}")
    return experiment_id

def train_model_with_mlflow(model, model_name, X_train, X_test, y_train, y_test, params=None, scaler=None):
    """Train and log model with MLflow"""
    with mlflow.start_run(run_name=model_name):
        # Train model
        model.fit(X_train, y_train)
        y_pred = model.predict(X_test)
        
        # Calculate metrics
        metrics = {
            'rmse': np.sqrt(mean_squared_error(y_test, y_pred)),
            'mae': mean_absolute_error(y_test, y_pred),
            'r2': r2_score(y_test, y_pred)
        }
        
        # Log parameters
        mlflow.log_param("model_type", type(model).__name__)
        mlflow.log_param("features_count", X_train.shape[1])
        mlflow.log_param("training_samples", X_train.shape[0])
        
        if params:
            for key, value in params.items():
                mlflow.log_param(key, value)
        
        # Log metrics
        for metric_name, metric_value in metrics.items():
            mlflow.log_metric(metric_name, metric_value)
        
        # Log model
        mlflow.sklearn.log_model(
            sk_model=model,
            artifact_path="model",
            serialization_format=mlflow.sklearn.SERIALIZATION_FORMAT_PICKLE
        )
        
        # Log scaler if provided
        if scaler is not None:
            os.makedirs("artifacts", exist_ok=True)
            scaler_path = f"artifacts/{model_name}_scaler.joblib"
            joblib.dump(scaler, scaler_path)
            mlflow.log_artifact(scaler_path, "scaler")
        
        # Save model as joblib file for API usage
        os.makedirs("models", exist_ok=True)
        model_path = f"models/{model_name}.joblib"
        joblib.dump(model, model_path)
        print(f"💾 Model saved to {model_path}")
        
        run_id = mlflow.active_run().info.run_id
        print(f"✅ {model_name} - RMSE: {metrics['rmse']:.4f}, R²: {metrics['r2']:.4f} (Run: {run_id[:8]})")
        
        return model, metrics, run_id

def main():
    """Main training pipeline with clean MLflow setup"""
    print("🚀 Starting clean MLflow training pipeline...")
    
    # Setup clean MLflow
    experiment_id = setup_mlflow_clean()
    
    # Load data
    print("📊 Loading and preprocessing data...")
    df_result = load_and_clean_data(DATA_PATH)
    df = df_result[1] if isinstance(df_result, tuple) else df_result
    
    # Prepare data for different models
    X_train_lr, X_test_lr, y_train_lr, y_test_lr, scaler = preprocess_for_linear_regression(df)
    X_train_dt, X_test_dt, y_train_dt, y_test_dt = preprocess_for_decision_tree(df)
    
    print(f"   Linear Regression data: {X_train_lr.shape}")
    print(f"   Decision Tree data: {X_train_dt.shape}")
    
    models_results = {}
    
    # Train Linear Regression
    print("\n🔵 Training Linear Regression...")
    lr_model = LinearRegression()
    lr_params = {"scaling_method": "StandardScaler", "preprocessing": "full"}
    lr_model, lr_metrics, lr_run_id = train_model_with_mlflow(
        lr_model, "linear_regression",
        X_train_lr, X_test_lr, y_train_lr, y_test_lr,
        lr_params, scaler
    )
    models_results['linear_regression'] = lr_metrics
    
    # Train Decision Tree
    print("\n🌳 Training Decision Tree...")
    dt_model = DecisionTreeRegressor(max_depth=10, min_samples_split=20, min_samples_leaf=10, random_state=42)
    dt_params = {"max_depth": 10, "min_samples_split": 20, "min_samples_leaf": 10, "preprocessing": "minimal"}
    dt_model, dt_metrics, dt_run_id = train_model_with_mlflow(
        dt_model, "decision_tree",
        X_train_dt, X_test_dt, y_train_dt, y_test_dt,
        dt_params
    )
    models_results['decision_tree'] = dt_metrics
    
    # Train Random Forest
    print("\n🌲 Training Random Forest...")
    rf_model = RandomForestRegressor(n_estimators=100, max_depth=15, min_samples_split=10, random_state=42)
    rf_params = {"n_estimators": 100, "max_depth": 15, "min_samples_split": 10, "preprocessing": "minimal"}
    rf_model, rf_metrics, rf_run_id = train_model_with_mlflow(
        rf_model, "random_forest",
        X_train_dt, X_test_dt, y_train_dt, y_test_dt,
        rf_params
    )
    models_results['random_forest'] = rf_metrics
    
    # Find best model
    best_model_name = min(models_results.keys(), key=lambda k: models_results[k]['rmse'])
    best_metrics = models_results[best_model_name]
    
    print(f"\n🏆 Best model: {best_model_name}")
    print(f"   RMSE: {best_metrics['rmse']:.4f}")
    print(f"   R²: {best_metrics['r2']:.4f}")
    print("\n✅ Training completed!")
    print("🌐 Start MLflow UI: mlflow ui")
    print("📂 MLflow files location: ./mlruns")

if __name__ == "__main__":
    main()