"""
Prometheus monitoring integration for ML API
"""
from prometheus_client import Counter, Histogram, Gauge, Info, generate_latest, CollectorRegistry, CONTENT_TYPE_LATEST
from prometheus_flask_exporter import PrometheusMetrics
import time
import psutil
import logging
from typing import Optional

logger = logging.getLogger(__name__)

class MLModelMetrics:
    """Custom Prometheus metrics for ML model monitoring"""
    
    def __init__(self, app=None):
        # Create custom registry for better organization
        self.registry = CollectorRegistry()
        
        # API Request Metrics
        self.api_requests_total = Counter(
            'api_requests_total',
            'Total number of API requests',
            ['method', 'endpoint', 'status_code'],
            registry=self.registry
        )
        
        self.api_request_duration = Histogram(
            'api_request_duration_seconds',
            'API request duration in seconds',
            ['method', 'endpoint'],
            registry=self.registry
        )
        
        # ML Model Metrics
        self.predictions_total = Counter(
            'ml_predictions_total',
            'Total number of ML predictions made',
            ['model_name', 'status'],
            registry=self.registry
        )
        
        self.prediction_duration = Histogram(
            'ml_prediction_duration_seconds',
            'Time taken for ML prediction in seconds',
            ['model_name'],
            registry=self.registry
        )
        
        self.prediction_value = Histogram(
            'ml_prediction_value_millions_usd',
            'Distribution of predicted house prices in millions USD',
            ['model_name'],
            buckets=[0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 1.5, 2.0, 3.0, 5.0, float('inf')],
            registry=self.registry
        )
        
        # Model Health Metrics
        self.model_loaded = Gauge(
            'ml_model_loaded',
            'Whether the ML model is successfully loaded (1=loaded, 0=not loaded)',
            ['model_name'],
            registry=self.registry
        )
        
        self.model_load_time = Gauge(
            'ml_model_load_time_seconds',
            'Time taken to load the ML model',
            ['model_name'],
            registry=self.registry
        )
        
        # Feature Engineering Metrics
        self.feature_engineering_duration = Histogram(
            'ml_feature_engineering_duration_seconds',
            'Time taken for feature engineering',
            registry=self.registry
        )
        
        # Input Validation Metrics
        self.input_validation_errors = Counter(
            'ml_input_validation_errors_total',
            'Total number of input validation errors',
            ['error_type'],
            registry=self.registry
        )
        
        # System Resource Metrics
        self.system_memory_usage = Gauge(
            'system_memory_usage_percent',
            'System memory usage percentage',
            registry=self.registry
        )
        
        self.system_cpu_usage = Gauge(
            'system_cpu_usage_percent',
            'System CPU usage percentage',
            registry=self.registry
        )
        
        # Application Info
        self.app_info = Info(
            'ml_api_info',
            'Information about the ML API application',
            registry=self.registry
        )
        
        # Initialize app info
        self.app_info.info({
            'version': '1.0.0',
            'model_type': 'random_forest',
            'framework': 'flask',
            'python_version': '3.10'
        })
        
        if app:
            self.init_app(app)
    
    def init_app(self, app):
        """Initialize with Flask app"""
        # Setup automatic Flask metrics
        self.flask_metrics = PrometheusMetrics(app)
        
        # Add custom endpoint for our ML metrics (use different path to avoid conflict)
        @app.route('/ml-metrics')
        def ml_metrics():
            """Custom ML metrics endpoint"""
            self.update_system_metrics()
            return generate_latest(self.registry), 200, {'Content-Type': CONTENT_TYPE_LATEST}
        
        # Override the default /metrics endpoint to include both Flask and ML metrics
        @app.route('/metrics')  
        def combined_metrics():
            """Combined Prometheus metrics endpoint with both Flask and ML metrics"""
            self.update_system_metrics()
            
            # Get Flask metrics
            flask_metrics_data = generate_latest()
            
            # Get our custom ML metrics  
            ml_metrics_data = generate_latest(self.registry)
            
            # Combine them
            combined = flask_metrics_data.decode('utf-8') + '\n' + ml_metrics_data.decode('utf-8')
            return combined, 200, {'Content-Type': CONTENT_TYPE_LATEST}
    
    def update_system_metrics(self):
        """Update system resource metrics"""
        try:
            # Update memory usage
            memory = psutil.virtual_memory()
            self.system_memory_usage.set(memory.percent)
            
            # Update CPU usage
            cpu_percent = psutil.cpu_percent(interval=0.1)
            self.system_cpu_usage.set(cpu_percent)
            
        except Exception as e:
            logger.warning(f"Failed to update system metrics: {e}")
    
    def record_request(self, method: str, endpoint: str, status_code: int, duration: float):
        """Record API request metrics"""
        self.api_requests_total.labels(
            method=method,
            endpoint=endpoint,
            status_code=str(status_code)
        ).inc()
        
        self.api_request_duration.labels(
            method=method,
            endpoint=endpoint
        ).observe(duration)
    
    def record_prediction(self, model_name: str, prediction_value: float, 
                         duration: float, status: str = 'success'):
        """Record ML prediction metrics"""
        self.predictions_total.labels(
            model_name=model_name,
            status=status
        ).inc()
        
        self.prediction_duration.labels(
            model_name=model_name
        ).observe(duration)
        
        if status == 'success':
            self.prediction_value.labels(
                model_name=model_name
            ).observe(prediction_value)
    
    def record_model_status(self, model_name: str, is_loaded: bool, load_time: float = 0.0):
        """Record model loading status"""
        self.model_loaded.labels(model_name=model_name).set(1 if is_loaded else 0)
        
        if load_time > 0:
            self.model_load_time.labels(model_name=model_name).set(load_time)
    
    def record_feature_engineering(self, duration: float):
        """Record feature engineering time"""
        self.feature_engineering_duration.observe(duration)
    
    def record_validation_error(self, error_type: str):
        """Record input validation error"""
        self.input_validation_errors.labels(error_type=error_type).inc()

# Context manager for timing operations
class Timer:
    """Context manager for timing operations"""
    
    def __init__(self):
        self.start_time: float = 0.0
        self.end_time: float = 0.0
        self.duration: float = 0.0
    
    def __enter__(self):
        self.start_time = time.time()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        self.end_time = time.time()
        self.duration = self.end_time - self.start_time
