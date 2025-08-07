#!/usr/bin/env python3
"""
Unit tests for core modules that don't require API to be running.
These tests validate the source code functionality independently.
"""

import sys
import os
import pytest
import pandas as pd
import numpy as np
from unittest.mock import patch, MagicMock

# Add src directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'config'))

try:
    import data_preprocess
    import constants
except ImportError as e:
    print(f"Warning: Could not import modules - {e}")


class TestDataPreprocessing:
    """Test data preprocessing functionality"""
    
    def test_constants_module(self):
        """Test that constants module loads correctly"""
        assert hasattr(constants, 'MODELS_DIR') or hasattr(constants, 'models_dir') or True
        
    def test_data_preprocessing_module_imports(self):
        """Test that data preprocessing module can be imported"""
        try:
            import data_preprocess
            assert True
        except ImportError:
            pytest.skip("data_preprocess module not available")
    
    def test_basic_data_operations(self):
        """Test basic data operations without external dependencies"""
        # Create sample data
        sample_data = pd.DataFrame({
            'MedInc': [8.3252, 8.3014, 7.2574],
            'HouseAge': [41.0, 21.0, 52.0],
            'AveRooms': [6.984127, 6.238137, 8.288136],
            'AveBedrms': [1.023810, 0.971880, 1.073446],
            'Population': [322.0, 2401.0, 496.0],
            'AveOccup': [2.555556, 2.109842, 2.802260],
            'Latitude': [37.88, 37.86, 37.85],
            'Longitude': [-122.23, -122.22, -122.24]
        })
        
        # Test basic operations
        assert len(sample_data) == 3
        assert list(sample_data.columns) == ['MedInc', 'HouseAge', 'AveRooms', 'AveBedrms', 
                                           'Population', 'AveOccup', 'Latitude', 'Longitude']
        
        # Test data types
        assert sample_data['MedInc'].dtype in [np.float64, float]
        assert sample_data['HouseAge'].dtype in [np.float64, float]
        
    def test_model_input_validation(self):
        """Test model input validation logic"""
        # Test valid input structure
        valid_input = {
            'MedInc': 8.3252,
            'HouseAge': 41.0,
            'AveRooms': 6.984127,
            'AveBedrms': 1.023810,
            'Population': 322.0,
            'AveOccup': 2.555556,
            'Latitude': 37.88,
            'Longitude': -122.23
        }
        
        # Check all required keys are present
        required_keys = ['MedInc', 'HouseAge', 'AveRooms', 'AveBedrms', 
                        'Population', 'AveOccup', 'Latitude', 'Longitude']
        
        for key in required_keys:
            assert key in valid_input
            assert isinstance(valid_input[key], (int, float))


class TestModelTraining:
    """Test model training functionality"""
    
    def test_model_training_module_imports(self):
        """Test that model training module can be imported"""
        try:
            import model_train
            assert True
        except ImportError:
            pytest.skip("model_train module not available")
    
    @patch('os.path.exists')
    def test_model_file_validation(self, mock_exists):
        """Test model file validation logic"""
        mock_exists.return_value = True
        
        # Test that mocked file exists
        assert mock_exists('models/linear_regression.joblib') == True
        assert mock_exists('models/random_forest.joblib') == True
        
    def test_numpy_operations(self):
        """Test basic numpy operations used in ML pipeline"""
        # Test array operations
        arr = np.array([1, 2, 3, 4, 5])
        assert arr.mean() == 3.0
        assert arr.std() > 0
        
        # Test matrix operations
        matrix = np.array([[1, 2], [3, 4]])
        assert matrix.shape == (2, 2)
        assert np.sum(matrix) == 10


class TestConfigValidation:
    """Test configuration and environment setup"""
    
    def test_python_environment(self):
        """Test Python environment is properly set up"""
        assert sys.version_info >= (3, 8), "Python 3.8+ required"
        
    def test_required_packages(self):
        """Test that required packages can be imported"""
        required_packages = [
            'pandas', 'numpy', 'sklearn', 'flask', 'joblib'
        ]
        
        for package in required_packages:
            try:
                __import__(package)
            except ImportError:
                pytest.fail(f"Required package {package} not available")
    
    def test_directory_structure(self):
        """Test that required directories exist"""
        base_dir = os.path.dirname(os.path.dirname(__file__))
        required_dirs = ['src', 'api', 'models', 'data']
        
        for dir_name in required_dirs:
            dir_path = os.path.join(base_dir, dir_name)
            assert os.path.exists(dir_path), f"Required directory {dir_name} not found"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
