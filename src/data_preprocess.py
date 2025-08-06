# Third-party imports
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler


def load_and_clean_data(file_path):
    """
    Load and clean the dataset from the specified file path.
    
    Parameters:
    - file_path (str): Path to the CSV file containing the dataset.
    
    Returns:
    - pd.DataFrame: Cleaned DataFrame.
    """
    df = pd.read_csv(file_path)
    # Basic cleaning - remove rows with missing values and duplicates
    cleaned_df = df.dropna().drop_duplicates().reset_index(drop=True)
    return cleaned_df


def detect_skewness(df, threshold=1.0):
    """
    Detect skewed features in the dataset.
    
    Parameters:
    - df (pd.DataFrame): Input DataFrame
    - threshold (float): Absolute skewness threshold (default: 1.0)
    
    Returns:
    - dict: Dictionary with feature names and their skewness values
    """
    numeric_features = df.select_dtypes(include=[np.number]).columns
    skewness = df[numeric_features].skew().abs()
    skewed_features = skewness[skewness > threshold].to_dict()
    
    print(f"Features with |skewness| > {threshold}:")
    for feature, skew_val in skewed_features.items():
        print(f"  {feature}: {skew_val:.3f}")
    
    return skewed_features


def apply_transformations(df, target_column='med_house_val'):
    """
    Apply transformations to handle skewed data and create new features.
    
    Parameters:
    - df (pd.DataFrame): Input DataFrame
    - target_column (str): Name of the target column
    
    Returns:
    - pd.DataFrame: Transformed DataFrame
    """
    df_transformed = df.copy()
    
    # Handle both original and cleaned column names
    med_inc_col = 'med_inc' if 'med_inc' in df.columns else 'MedInc'
    ave_rooms_col = 'ave_rooms' if 'ave_rooms' in df.columns else 'AveRooms'
    ave_bedrms_col = 'ave_bedrms' if 'ave_bedrms' in df.columns else 'AveBedrms'
    ave_occup_col = 'ave_occup' if 'ave_occup' in df.columns else 'AveOccup'
    population_col = 'population' if 'population' in df.columns else 'Population'
    house_age_col = 'house_age' if 'house_age' in df.columns else 'HouseAge'
    
    # Remove outliers in MedInc/med_inc
    df_transformed = df_transformed[df_transformed[med_inc_col] < 15]
    
    # Create new features
    df_transformed["rooms_per_person"] = df_transformed[ave_rooms_col] / (df_transformed[ave_occup_col] + 1e-6)
    df_transformed["bedrooms_per_room"] = df_transformed[ave_bedrms_col] / (df_transformed[ave_rooms_col] + 1e-6)
    
    # Apply log transformation to highly skewed features
    skewed_features = [population_col, ave_occup_col]
    for feature in skewed_features:
        if feature in df_transformed.columns:
            df_transformed[f"{feature}_log"] = np.log1p(df_transformed[feature])
    
    # Drop original skewed features and less important features
    features_to_drop = [population_col, house_age_col]
    df_transformed = df_transformed.drop(columns=[col for col in features_to_drop if col in df_transformed.columns])
    
    return df_transformed


def preprocess_for_linear_regression(df, target_column='med_house_val', test_size=0.2, random_state=42):
    """
    Preprocess data specifically for Linear Regression model.
    Includes scaling and handling of skewed features.
    
    Parameters:
    - df (pd.DataFrame): Input DataFrame
    - target_column (str): Name of the target column
    - test_size (float): Test set size
    - random_state (int): Random state for reproducibility
    
    Returns:
    - tuple: (X_train, X_test, y_train, y_test, scaler)
    """
    # Handle both original and cleaned column names
    if 'MedHouseVal' in df.columns:
        target_column = 'MedHouseVal'
    elif 'med_house_val' in df.columns:
        target_column = 'med_house_val'
    
    # Apply transformations
    df_processed = apply_transformations(df, target_column)
    
    # Separate features and target
    X = df_processed.drop(target_column, axis=1)
    y = df_processed[target_column]
    
    # Split the data
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=test_size, random_state=random_state)
    
    # Scale features (important for Linear Regression)
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    return X_train_scaled, X_test_scaled, y_train, y_test, scaler


def preprocess_for_decision_tree(df, target_column='med_house_val', test_size=0.2, random_state=42):
    """
    Preprocess data specifically for Decision Tree model.
    Minimal preprocessing as trees handle skewness well.
    
    Parameters:
    - df (pd.DataFrame): Input DataFrame
    - target_column (str): Name of the target column
    - test_size (float): Test set size
    - random_state (int): Random state for reproducibility
    
    Returns:
    - tuple: (X_train, X_test, y_train, y_test)
    """
    # Handle both original and cleaned column names
    if 'MedHouseVal' in df.columns:
        target_column = 'MedHouseVal'
    elif 'med_house_val' in df.columns:
        target_column = 'med_house_val'
    
    population_col = 'population' if 'population' in df.columns else 'Population'
    
    # Apply basic transformations (feature engineering is still beneficial)
    df_processed = apply_transformations(df, target_column)
    
    # For decision trees, we can also keep the original skewed features
    # as they might provide additional information
    if population_col in df.columns:
        df_processed[population_col] = df[population_col]
    
    # Separate features and target
    X = df_processed.drop(target_column, axis=1)
    y = df_processed[target_column]
    
    # Split the data (no scaling needed for decision trees)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=test_size, random_state=random_state)
    
    return X_train, X_test, y_train, y_test


def get_preprocessing_summary(df):
    """
    Generate a summary of preprocessing recommendations based on data analysis.
    
    Parameters:
    - df (pd.DataFrame): Input DataFrame
    
    Returns:
    - dict: Summary of recommendations
    """
    summary = {
        'total_features': len(df.columns),
        'numeric_features': len(df.select_dtypes(include=[np.number]).columns),
        'missing_values': df.isnull().sum().sum(),
        'skewed_features': detect_skewness(df, threshold=1.0),
        'recommendations': {
            'linear_regression': [
                'Apply log transformation to highly skewed features',
                'Use StandardScaler for feature scaling',
                'Consider removing outliers'
            ],
            'decision_tree': [
                'Feature engineering beneficial but not mandatory',
                'No scaling required',
                'Can handle skewed data and outliers naturally'
            ]
        }
    }
    
    return summary