"""
Enhanced logging and monitoring utilities
"""
import sqlite3
import json
from datetime import datetime
from typing import Dict, Any
import logging

class PredictionLogger:
    """Logger for prediction requests and responses"""
    
    def __init__(self, db_path: str = "prediction_logs.db"):
        self.db_path = db_path
        self.setup_database()
    
    def setup_database(self):
        """Create the logging database if it doesn't exist"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS prediction_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                input_data TEXT NOT NULL,
                prediction REAL NOT NULL,
                model_used TEXT NOT NULL,
                response_time_ms REAL,
                status TEXT NOT NULL
            )
        ''')
        
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS api_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                endpoint TEXT NOT NULL,
                method TEXT NOT NULL,
                status_code INTEGER NOT NULL,
                response_time_ms REAL NOT NULL,
                user_agent TEXT
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def log_prediction(self, input_data: Dict[str, Any], prediction: float, 
                      model_used: str, response_time_ms: float, status: str = "success"):
        """Log a prediction request and response"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO prediction_logs 
            (timestamp, input_data, prediction, model_used, response_time_ms, status)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (
            datetime.now().isoformat(),
            json.dumps(input_data),
            prediction,
            model_used,
            response_time_ms,
            status
        ))
        
        conn.commit()
        conn.close()
    
    def log_api_request(self, endpoint: str, method: str, status_code: int, 
                       response_time_ms: float, user_agent: str = None):
        """Log API request metrics"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO api_metrics 
            (timestamp, endpoint, method, status_code, response_time_ms, user_agent)
            VALUES (?, ?, ?, ?, ?, ?)
        ''', (
            datetime.now().isoformat(),
            endpoint,
            method,
            status_code,
            response_time_ms,
            user_agent
        ))
        
        conn.commit()
        conn.close()
    
    def get_prediction_stats(self, hours: int = 24) -> Dict[str, Any]:
        """Get prediction statistics for the last N hours"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Get stats for the last N hours
        cursor.execute('''
            SELECT 
                COUNT(*) as total_predictions,
                AVG(prediction) as avg_prediction,
                AVG(response_time_ms) as avg_response_time,
                SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) as successful_predictions,
                model_used
            FROM prediction_logs 
            WHERE datetime(timestamp) > datetime('now', '-{} hours')
            GROUP BY model_used
        '''.format(hours))
        
        results = cursor.fetchall()
        conn.close()
        
        stats = {}
        for row in results:
            total, avg_pred, avg_time, successful, model = row
            stats[model] = {
                "total_predictions": total,
                "successful_predictions": successful,
                "success_rate": successful / total if total > 0 else 0,
                "avg_prediction": avg_pred,
                "avg_response_time_ms": avg_time
            }
        
        return stats
    
    def get_api_metrics(self, hours: int = 24) -> Dict[str, Any]:
        """Get API metrics for the last N hours"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT 
                endpoint,
                COUNT(*) as request_count,
                AVG(response_time_ms) as avg_response_time,
                SUM(CASE WHEN status_code < 400 THEN 1 ELSE 0 END) as success_count
            FROM api_metrics 
            WHERE datetime(timestamp) > datetime('now', '-{} hours')
            GROUP BY endpoint
        '''.format(hours))
        
        results = cursor.fetchall()
        conn.close()
        
        metrics = {}
        total_requests = 0
        total_success = 0
        
        for row in results:
            endpoint, count, avg_time, success = row
            total_requests += count
            total_success += success
            
            metrics[endpoint] = {
                "request_count": count,
                "success_count": success,
                "success_rate": success / count if count > 0 else 0,
                "avg_response_time_ms": avg_time
            }
        
        metrics["_summary"] = {
            "total_requests": total_requests,
            "total_success": total_success,
            "overall_success_rate": total_success / total_requests if total_requests > 0 else 0
        }
        
        return metrics

class MetricsCollector:
    """Collect and expose metrics in Prometheus format"""
    
    def __init__(self, logger: PredictionLogger):
        self.logger = logger
    
    def get_prometheus_metrics(self) -> str:
        """Generate Prometheus-format metrics"""
        stats = self.logger.get_prediction_stats(24)
        api_metrics = self.logger.get_api_metrics(24)
        
        metrics = []
        
        # Prediction metrics
        for model, data in stats.items():
            metrics.append(f'# HELP predictions_total Total number of predictions made')
            metrics.append(f'# TYPE predictions_total counter')
            metrics.append(f'predictions_total{{model="{model}"}} {data["total_predictions"]}')
            
            metrics.append(f'# HELP prediction_success_rate Success rate of predictions')
            metrics.append(f'# TYPE prediction_success_rate gauge')
            metrics.append(f'prediction_success_rate{{model="{model}"}} {data["success_rate"]}')
            
            metrics.append(f'# HELP prediction_response_time_ms Average response time in milliseconds')
            metrics.append(f'# TYPE prediction_response_time_ms gauge')
            metrics.append(f'prediction_response_time_ms{{model="{model}"}} {data["avg_response_time_ms"] or 0}')
        
        # API metrics
        if "_summary" in api_metrics:
            summary = api_metrics["_summary"]
            metrics.append(f'# HELP api_requests_total Total API requests')
            metrics.append(f'# TYPE api_requests_total counter')
            metrics.append(f'api_requests_total {summary["total_requests"]}')
            
            metrics.append(f'# HELP api_success_rate Overall API success rate')
            metrics.append(f'# TYPE api_success_rate gauge')
            metrics.append(f'api_success_rate {summary["overall_success_rate"]}')
        
        return '\n'.join(metrics)
