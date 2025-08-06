"""
Flask API for California Housing Price Prediction with Swagger UI and Prometheus monitoring
"""
import os
import sys
import logging
import time
from datetime import datetime

from flask import Flask, request
from flask_restx import Api, Resource, fields, Namespace
from flask_cors import CORS
import joblib
import mlflow
import numpy as np
import pandas as pd
from pydantic import BaseModel, ValidationError
from typing import List

# Import Prometheus monitoring
from prometheus_monitoring import MLModelMetrics, Timer

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('api_logs.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Add path for imports
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Initialize Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS for all routes

# Initialize Prometheus metrics
ml_metrics = MLModelMetrics(app)

# Initialize Flask-RESTX API with Swagger documentation
api = Api(
    app,
    version='1.0.0',
    title='California Housing Price Prediction API',
    description='A machine learning API for predicting California housing prices using Random Forest model. '
                'This API accepts housing characteristics and returns price predictions in millions of USD.',
    doc='/docs/',  # Swagger UI will be available at /docs/
    prefix='/api/v1'
)

# Create namespaces
ns_prediction = Namespace('prediction', description='Housing price prediction operations')
ns_health = Namespace('health', description='Health check and monitoring')

api.add_namespace(ns_prediction)
api.add_namespace(ns_health)

# Load model and scaler at startup
MODEL_PATH = "models/"
SCALER_PATH = "models/linear_regression_scaler.joblib"

class PredictionInput(BaseModel):
    """Input validation schema using Pydantic"""
    med_inc: float
    house_age: float
    ave_rooms: float
    ave_bedrms: float
    population: float
    ave_occup: float
    latitude: float
    longitude: float

class PredictionResponse(BaseModel):
    """Response schema"""
    prediction: float  # Value in millions of dollars
    model_used: str
    timestamp: str
    input_features: dict

# Swagger API models
prediction_input_model = api.model('PredictionInput', {
    'med_inc': fields.Float(required=True, description='Median income in block group (e.g., 8.3252)', example=8.3252),
    'house_age': fields.Float(required=True, description='Median house age in block group (e.g., 41.0)', example=41.0),
    'ave_rooms': fields.Float(required=True, description='Average number of rooms per household (e.g., 6.984)', example=6.984127),
    'ave_bedrms': fields.Float(required=True, description='Average number of bedrooms per household (e.g., 1.024)', example=1.02381),
    'population': fields.Float(required=True, description='Block group population (e.g., 322.0)', example=322.0),
    'ave_occup': fields.Float(required=True, description='Average household size (e.g., 2.556)', example=2.555556),
    'latitude': fields.Float(required=True, description='Latitude coordinate (e.g., 37.88)', example=37.88),
    'longitude': fields.Float(required=True, description='Longitude coordinate (e.g., -122.23)', example=-122.23)
})

prediction_response_model = api.model('PredictionResponse', {
    'prediction': fields.Float(required=True, description='Predicted house price in millions USD', example=0.431),
    'prediction_formatted': fields.String(required=True, description='Human-readable price format', example='$0.431M'),
    'prediction_units': fields.String(required=True, description='Units of prediction', example='millions_usd'),
    'model_used': fields.String(required=True, description='ML model used for prediction', example='random_forest'),
    'timestamp': fields.String(required=True, description='Prediction timestamp', example='2025-08-04T17:28:13.232492'),
    'input_features': fields.Raw(required=True, description='Input features used for prediction')
})

health_response_model = api.model('HealthResponse', {
    'status': fields.String(required=True, description='API health status', example='healthy'),
    'timestamp': fields.String(required=True, description='Current timestamp', example='2025-08-04T17:28:13.183221')
})

api_info_model = api.model('ApiInfo', {
    'message': fields.String(required=True, description='API description', example='California Housing Price Prediction API'),
    'status': fields.String(required=True, description='API status', example='healthy'),
    'model': fields.String(required=True, description='Current ML model', example='random_forest'),
    'version': fields.String(required=True, description='API version', example='1.0.0')
})

metrics_response_model = api.model('MetricsResponse', {
    'requests_total': fields.String(required=True, description='Total requests processed', example='N/A'),
    'predictions_total': fields.String(required=True, description='Total predictions made', example='N/A'),
    'model_name': fields.String(required=True, description='Current model name', example='random_forest'),
    'uptime': fields.String(required=True, description='API uptime', example='N/A')
})

error_response_model = api.model('ErrorResponse', {
    'error': fields.String(required=True, description='Error message', example='Input validation failed'),
    'details': fields.String(description='Detailed error information', example='Field validation error details')
})

class HousingPredictor:
    """Housing price predictor class"""
    
    def __init__(self):
        self.model = None
        self.scaler = None
        self.model_name = "random_forest"  # Best performing model
        self.load_model()
    
    def load_model(self):
        """Load the trained model and scaler"""
        # Track model loading time for Prometheus
        load_start_time = time.time()
        
        try:
            # Load scaler if it exists
            if os.path.exists(SCALER_PATH):
                self.scaler = joblib.load(SCALER_PATH)
                logger.info("Scaler loaded successfully")
            
            # Load the trained model from joblib file
            model_path = f"models/{self.model_name}.joblib"
            if os.path.exists(model_path):
                self.model = joblib.load(model_path)
                load_time = time.time() - load_start_time
                logger.info(f"Model {self.model_name} loaded successfully from {model_path}")
                
                # Record successful model loading in Prometheus
                ml_metrics.record_model_status(self.model_name, True, load_time)
            else:
                # Fallback to creating a new model (for demo purposes only)
                from sklearn.ensemble import RandomForestRegressor
                self.model = RandomForestRegressor(n_estimators=100, random_state=42)
                load_time = time.time() - load_start_time
                logger.warning(f"Model file {model_path} not found, created new untrained model")
                
                # Record fallback model loading
                ml_metrics.record_model_status(f"{self.model_name}_fallback", True, load_time)
            
        except Exception as e:
            logger.error(f"Error loading model: {str(e)}")
            # Record failed model loading
            ml_metrics.record_model_status(self.model_name, False)
            raise e
    
    def preprocess_input(self, data: dict):
        """Preprocess input data similar to training"""
        try:
            # Convert to DataFrame with original column names
            df = pd.DataFrame([data])
            
            # Rename columns to match training data
            column_mapping = {
                'med_inc': 'MedInc',
                'house_age': 'HouseAge', 
                'ave_rooms': 'AveRooms',
                'ave_bedrms': 'AveBedrms',
                'population': 'Population',
                'ave_occup': 'AveOccup',
                'latitude': 'Latitude',
                'longitude': 'Longitude'
            }
            df = df.rename(columns=column_mapping)
            
            # Apply same transformations as apply_transformations() function
            df_transformed = df.copy()
            
            # Remove outliers in MedInc (same as training)
            df_transformed = df_transformed[df_transformed['MedInc'] < 15]
            
            # Create new engineered features
            df_transformed["rooms_per_person"] = df_transformed['AveRooms'] / (df_transformed['AveOccup'] + 1e-6)
            df_transformed["bedrooms_per_room"] = df_transformed['AveBedrms'] / (df_transformed['AveRooms'] + 1e-6)
            
            # Apply log transformation to highly skewed features
            df_transformed["Population_log"] = np.log1p(df_transformed['Population'])
            df_transformed["AveOccup_log"] = np.log1p(df_transformed['AveOccup'])
            
            # For Random Forest (decision tree preprocessing):
            # - Apply transformations
            # - Drop HouseAge (from apply_transformations)
            # - Keep original Population (added back in preprocess_for_decision_tree)
            if self.model_name == "random_forest":
                # Drop HouseAge but keep Population (as done in training)
                df_processed = df_transformed.drop(columns=['HouseAge'])
                
                # Final feature order should match training:
                # ['MedInc', 'AveRooms', 'AveBedrms', 'AveOccup', 'Latitude', 'Longitude',
                #  'rooms_per_person', 'bedrooms_per_room', 'Population_log', 'AveOccup_log', 'Population']
                feature_columns = ['MedInc', 'AveRooms', 'AveBedrms', 'AveOccup', 'Latitude', 'Longitude',
                                 'rooms_per_person', 'bedrooms_per_room', 'Population_log', 'AveOccup_log', 'Population']
                df_processed = df_processed[feature_columns]
                
            else:  # Linear regression
                # Drop both Population and HouseAge (as done in apply_transformations)
                df_processed = df_transformed.drop(columns=['Population', 'HouseAge'])
                
                # Scale features if scaler is available
                if self.scaler:
                    features_scaled = self.scaler.transform(df_processed.values)
                    return features_scaled
            
            return df_processed.values
            
        except Exception as e:
            logger.error(f"Error preprocessing input: {str(e)}")
            raise e
    
    def predict(self, input_data: dict):
        """Make prediction with Prometheus metrics"""
        prediction_start_time = time.time()
        
        try:
            # Track feature engineering time
            fe_start_time = time.time()
            processed_data = self.preprocess_input(input_data)
            fe_duration = time.time() - fe_start_time
            ml_metrics.record_feature_engineering(fe_duration)
            
            # Make prediction
            prediction = self.model.predict(processed_data)[0]
            
            # Convert to price (multiply by 100k as in original dataset)
            prediction_price = prediction * 100000
            
            # Convert to millions for better readability
            prediction_millions = prediction_price / 1000000
            
            # Calculate total prediction time
            prediction_duration = time.time() - prediction_start_time
            
            # Record successful prediction metrics
            ml_metrics.record_prediction(
                model_name=self.model_name,
                prediction_value=prediction_millions,
                duration=prediction_duration,
                status='success'
            )
            
            logger.info(f"Prediction made: ${prediction_price:,.2f} (${prediction_millions:.3f}M)")
            return prediction_millions
            
        except Exception as e:
            # Calculate prediction time even for failures
            prediction_duration = time.time() - prediction_start_time
            
            # Record failed prediction
            ml_metrics.record_prediction(
                model_name=self.model_name,
                prediction_value=0.0,
                duration=prediction_duration,
                status='error'
            )
            
            logger.error(f"Error making prediction: {str(e)}")
            raise e

# Initialize predictor
predictor = HousingPredictor()

# API Routes using Flask-RESTX

@ns_health.route('/')
class Health(Resource):
    """Health check endpoint"""
    
    @api.doc('health_check')
    @api.marshal_with(health_response_model)
    def get(self):
        """Check API health status"""
        return {
            "status": "healthy",
            "timestamp": datetime.now().isoformat()
        }

@ns_health.route('/info')
class ApiInfo(Resource):
    """API Information endpoint"""
    
    @api.doc('get_api_info')
    @api.marshal_with(api_info_model)
    def get(self):
        """Get API information and status"""
        return {
            "message": "California Housing Price Prediction API",
            "status": "healthy",
            "model": predictor.model_name,
            "version": "1.0.0"
        }

@ns_health.route('/metrics')
class Metrics(Resource):
    """Metrics endpoint for monitoring"""
    
    @api.doc('get_metrics')
    @api.marshal_with(metrics_response_model)
    def get(self):
        """Get API metrics and monitoring information"""
        return {
            "requests_total": "N/A",  # Would be tracked in real implementation
            "predictions_total": "N/A",
            "model_name": predictor.model_name,
            "uptime": "N/A"
        }

@ns_prediction.route('/predict')
class Prediction(Resource):
    """Housing price prediction endpoint"""
    
    @api.doc('make_prediction')
    @api.expect(prediction_input_model)
    @api.marshal_with(prediction_response_model)
    @api.response(400, 'Input validation failed', error_response_model)
    @api.response(500, 'Internal server error', error_response_model)
    def post(self):
        """
        Predict California housing price
        
        This endpoint accepts housing characteristics and returns a price prediction.
        The prediction is returned in millions of USD (e.g., 0.431 = $431,000).
        
        Example input:
        {
            "med_inc": 8.3252,
            "house_age": 41.0,
            "ave_rooms": 6.984127,
            "ave_bedrms": 1.02381,
            "population": 322.0,
            "ave_occup": 2.555556,
            "latitude": 37.88,
            "longitude": -122.23
        }
        """
        request_start_time = time.time()
        
        try:
            # Validate input
            data = request.json
            if not data:
                # Record validation error
                ml_metrics.record_validation_error('missing_data')
                api.abort(400, "No input data provided")
            
            # Validate using Pydantic
            try:
                input_model = PredictionInput(**data)
                input_dict = input_model.dict()
            except ValidationError as e:
                # Record validation error
                ml_metrics.record_validation_error('pydantic_validation')
                logger.warning(f"Input validation failed: {str(e)}")
                api.abort(400, f"Input validation failed: {str(e)}")
            
            # Make prediction
            prediction = predictor.predict(input_dict)
            
            # Create response
            response = {
                "prediction": round(prediction, 3),
                "prediction_formatted": f"${prediction:.3f}M",
                "prediction_units": "millions_usd",
                "model_used": predictor.model_name,
                "timestamp": datetime.now().isoformat(),
                "input_features": input_dict
            }
            
            # Calculate request duration and record metrics
            request_duration = time.time() - request_start_time
            ml_metrics.record_request('POST', '/api/v1/prediction/predict', 200, request_duration)
            
            # Log the request
            logger.info(f"Prediction request: {input_dict}")
            logger.info(f"Prediction response: ${prediction:.3f}M")
            
            return response
            
        except Exception as e:
            # Calculate request duration for error case
            request_duration = time.time() - request_start_time
            ml_metrics.record_request('POST', '/api/v1/prediction/predict', 500, request_duration)
            
            logger.error(f"Error in prediction endpoint: {str(e)}")
            api.abort(500, f"Internal server error: {str(e)}")

# Add a simple UI route
@app.route('/')
def index():
    """Redirect to Swagger UI"""
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>California Housing Price Prediction API</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; background-color: #f5f5f5; }
            .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            h1 { color: #333; text-align: center; }
            .feature { background: #e8f4fd; padding: 15px; margin: 10px 0; border-radius: 5px; }
            .button { display: inline-block; background: #007bff; color: white; padding: 12px 24px; text-decoration: none; border-radius: 5px; margin: 5px; }
            .button:hover { background: #0056b3; }
            ul { list-style-type: none; padding: 0; }
            li { margin: 8px 0; }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🏠 California Housing Price Prediction API</h1>
            
            <div class="feature">
                <h3>🚀 Quick Start</h3>
                <p>This API predicts California housing prices using a Random Forest machine learning model.</p>
                <p>Predictions are returned in <strong>millions of USD</strong> (e.g., 0.431 = $431,000)</p>
            </div>
            
            <div class="feature">
                <h3>📚 API Documentation</h3>
                <a href="/docs/" class="button">📖 Interactive Swagger UI</a>
                <a href="/api/v1/health/" class="button">💚 Health Check</a>
                <a href="/api/v1/health/metrics" class="button">📊 Metrics</a>
            </div>
            
            <div class="feature">
                <h3>🔧 Required Input Parameters</h3>
                <ul>
                    <li><strong>med_inc:</strong> Median income in block group</li>
                    <li><strong>house_age:</strong> Median house age in block group</li>
                    <li><strong>ave_rooms:</strong> Average number of rooms per household</li>
                    <li><strong>ave_bedrms:</strong> Average number of bedrooms per household</li>
                    <li><strong>population:</strong> Block group population</li>
                    <li><strong>ave_occup:</strong> Average household size</li>
                    <li><strong>latitude:</strong> Latitude coordinate</li>
                    <li><strong>longitude:</strong> Longitude coordinate</li>
                </ul>
            </div>
            
            <div class="feature">
                <h3>💡 Example Usage</h3>
                <p><strong>POST</strong> to <code>/api/v1/prediction/predict</code></p>
                <pre style="background: #f8f9fa; padding: 15px; border-radius: 5px; overflow-x: auto;">{
    "med_inc": 8.3252,
    "house_age": 41.0,
    "ave_rooms": 6.984127,
    "ave_bedrms": 1.02381,
    "population": 322.0,
    "ave_occup": 2.555556,
    "latitude": 37.88,
    "longitude": -122.23
}</pre>
            </div>
            
            <p style="text-align: center; color: #666; margin-top: 30px;">
                Model: Random Forest | Version: 1.0.0 | Framework: Flask-RESTX
            </p>
        </div>
    </body>
    </html>
    """

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5001))  # Default port standardized to 5001
    app.run(host='0.0.0.0', port=port, debug=False)
