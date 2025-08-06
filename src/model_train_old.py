# Standard library imports
import os
import sys
import joblib

# Third-party imports
import mlflow
import mlflow.sklearn
import numpy as np
from sklearn.linear_model import LinearRegression
from sklearn.tree import DecisionTreeRegressor
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import mean_squared_error, r2_score, mean_absolute_error

# Add the parent directory to Python path to enable imports from config folder
# parent_dir = os.path.dirname(os.getcwd())
# if parent_dir not in sys.path:
#     sys.path.append(parent_dir)

# Local imports
# from ..config.constants import DATA_PATH
from config.constants import DATA_PATH
from src.data_preprocess import (
    load_and_clean_data, 
    preprocess_for_linear_regression, 
    preprocess_for_decision_tree, 
    get_preprocessing_summary,
    detect_skewness
)

def setup_mlflow():
    """
    Set up MLflow tracking.
    """
    # Set MLflow tracking URI (local for development)
    mlflow.set_tracking_uri("sqlite:///mlflow.db")
    
    # Create or set experiment
    experiment_name = "california_housing_regression"
    try:
        experiment_id = mlflow.create_experiment(experiment_name)
    except mlflow.exceptions.MlflowException:
        experiment_id = mlflow.get_experiment_by_name(experiment_name).experiment_id
    
    mlflow.set_experiment(experiment_name)
    print(f"MLflow experiment: {experiment_name} (ID: {experiment_id})")
    return experiment_id

def evaluate_model(model, X_test, y_test):
    """
    Evaluate model and return metrics.
    """
    y_pred = model.predict(X_test)
    
    metrics = {
        'rmse': np.sqrt(mean_squared_error(y_test, y_pred)),
        'mae': mean_absolute_error(y_test, y_pred),
        'r2': r2_score(y_test, y_pred)
    }
    return metrics, y_pred

def train_linear_regression(X_train, X_test, y_train, y_test, scaler):
    """
    Train and track Linear Regression model with MLflow.
    """
    with mlflow.start_run(run_name="linear_regression"):
        # Train model
        model = LinearRegression()
        model.fit(X_train, y_train)
        
        # Evaluate model
        metrics, y_pred = evaluate_model(model, X_test, y_test)
        
        # Log parameters
        mlflow.log_param("model_type", "LinearRegression")
        mlflow.log_param("features_count", X_train.shape[1])
        mlflow.log_param("training_samples", X_train.shape[0])
        mlflow.log_param("scaling_method", "StandardScaler")
        
        # Log metrics
        mlflow.log_metrics(metrics)
        
        # Log model
        mlflow.sklearn.log_model(
            model, 
            "model",
            serialization_format=mlflow.sklearn.SERIALIZATION_FORMAT_PICKLE
        )
        
        # Save scaler alongside model
        scaler_path = "models/linear_regression_scaler.joblib"
        os.makedirs("models", exist_ok=True)
        joblib.dump(scaler, scaler_path)
        mlflow.log_artifact(scaler_path)
        
        print(f"Linear Regression - RMSE: {metrics['rmse']:.4f}, R²: {metrics['r2']:.4f}")
        return model, metrics

def train_decision_tree(X_train, X_test, y_train, y_test):
    """
    Train and track Decision Tree model with MLflow.
    """
    with mlflow.start_run(run_name="decision_tree"):
        # Train model with optimal parameters
        model = DecisionTreeRegressor(
            max_depth=10,
            min_samples_split=20,
            min_samples_leaf=10,
            random_state=42
        )
        model.fit(X_train, y_train)
        
        # Evaluate model
        metrics, y_pred = evaluate_model(model, X_test, y_test)
        
        # Log parameters
        mlflow.log_param("model_type", "DecisionTreeRegressor")
        mlflow.log_param("max_depth", 10)
        mlflow.log_param("min_samples_split", 20)
        mlflow.log_param("min_samples_leaf", 10)
        mlflow.log_param("features_count", X_train.shape[1])
        mlflow.log_param("training_samples", X_train.shape[0])
        
        # Log metrics
        mlflow.log_metrics(metrics)
        
        # Log model
        mlflow.sklearn.log_model(
            model, 
            "model",
            serialization_format=mlflow.sklearn.SERIALIZATION_FORMAT_PICKLE
        )
        
        print(f"Decision Tree - RMSE: {metrics['rmse']:.4f}, R²: {metrics['r2']:.4f}")
        return model, metrics

def train_random_forest(X_train, X_test, y_train, y_test):
    """
    Train and track Random Forest model with MLflow.
    """
    with mlflow.start_run(run_name="random_forest"):
        # Train model
        model = RandomForestRegressor(
            n_estimators=100,
            max_depth=15,
            min_samples_split=10,
            random_state=42
        )
        model.fit(X_train, y_train)
        
        # Evaluate model
        metrics, y_pred = evaluate_model(model, X_test, y_test)
        
        # Log parameters
        mlflow.log_param("model_type", "RandomForestRegressor")
        mlflow.log_param("n_estimators", 100)
        mlflow.log_param("max_depth", 15)
        mlflow.log_param("min_samples_split", 10)
        mlflow.log_param("features_count", X_train.shape[1])
        mlflow.log_param("training_samples", X_train.shape[0])
        
        # Log metrics
        mlflow.log_metrics(metrics)
        
        # Log model
        mlflow.sklearn.log_model(
            model, 
            "model",
            serialization_format=mlflow.sklearn.SERIALIZATION_FORMAT_PICKLE
        )
        
        print(f"Random Forest - RMSE: {metrics['rmse']:.4f}, R²: {metrics['r2']:.4f}")
        return model, metrics

def register_best_model(models_results):
    """
    Register the best performing model in MLflow Model Registry.
    """
    best_model_name = min(models_results.keys(), key=lambda k: models_results[k]['rmse'])
    best_metrics = models_results[best_model_name]
    
    print(f"\nBest model: {best_model_name}")
    print(f"Best RMSE: {best_metrics['rmse']:.4f}")
    print(f"Best R²: {best_metrics['r2']:.4f}")
    
    # Register the best model
    model_name = "california_housing_best_model"
    
    # Note: In a real scenario, you'd get the run_id from the best run
    # For now, we'll just print the information
    print(f"Best model would be registered as: {model_name}")
    
    return best_model_name, best_metrics

def main():
    """
    Main training pipeline.
    """
    print("="*60)
    print("CALIFORNIA HOUSING REGRESSION - MODEL TRAINING")
    print("="*60)
    
    # Setup MLflow
    setup_mlflow()
    
    # Load and preprocess data
    print("\n1. Loading and preprocessing data...")
    df_result = load_and_clean_data(DATA_PATH)
    df = df_result[1] if isinstance(df_result, tuple) else df_result
    
    # Prepare data for different models
    print("2. Preparing data for different models...")
    X_train_lr, X_test_lr, y_train_lr, y_test_lr, scaler = preprocess_for_linear_regression(df)
    X_train_dt, X_test_dt, y_train_dt, y_test_dt = preprocess_for_decision_tree(df)
    
    print(f"   Linear Regression data: {X_train_lr.shape}")
    print(f"   Decision Tree data: {X_train_dt.shape}")
    
    # Train models
    print("\n3. Training models with MLflow tracking...")
    models_results = {}
    
    # Train Linear Regression
    print("\n   Training Linear Regression...")
    lr_model, lr_metrics = train_linear_regression(X_train_lr, X_test_lr, y_train_lr, y_test_lr, scaler)
    models_results['linear_regression'] = lr_metrics
    
    # Train Decision Tree
    print("\n   Training Decision Tree...")
    dt_model, dt_metrics = train_decision_tree(X_train_dt, X_test_dt, y_train_dt, y_test_dt)
    models_results['decision_tree'] = dt_metrics
    
    # Train Random Forest (bonus model)
    print("\n   Training Random Forest...")
    rf_model, rf_metrics = train_random_forest(X_train_dt, X_test_dt, y_train_dt, y_test_dt)
    models_results['random_forest'] = rf_metrics
    
    # Compare models and register best
    print("\n4. Model comparison and registration...")
    best_model_name, best_metrics = register_best_model(models_results)
    
    print("\n" + "="*60)
    print("TRAINING COMPLETED")
    print(f"Run 'mlflow ui' to view experiments in browser")
    print("="*60)

if __name__ == "__main__":
    main()

