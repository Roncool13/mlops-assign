#!/usr/bin/env python3
"""
Unit tests for the California Housing API
"""

import pytest
import requests
import time

class TestAPI:
    """Test class for California Housing API"""
    
    BASE_URL = "http://localhost:5001"
    
    @classmethod
    def setup_class(cls):
        """Setup for all tests"""
        # Wait for API to be ready
        max_attempts = 30
        for attempt in range(max_attempts):
            try:
                response = requests.get(f"{cls.BASE_URL}/api/v1/health/", timeout=5)
                if response.status_code == 200:
                    print(f"✅ API is ready after {attempt + 1} attempts")
                    break
            except requests.exceptions.RequestException:
                if attempt < max_attempts - 1:
                    print(f"⏳ Waiting for API... attempt {attempt + 1}/{max_attempts}")
                    time.sleep(2)
                else:
                    pytest.fail("API not available after maximum attempts")
    
    def test_health_endpoint(self):
        """Test the health check endpoint"""
        response = requests.get(f"{self.BASE_URL}/api/v1/health/")
        
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert "timestamp" in data
        assert "version" in data
    
    def test_home_endpoint(self):
        """Test the home endpoint"""
        response = requests.get(f"{self.BASE_URL}/")
        
        assert response.status_code == 200
        assert "California Housing Price Prediction API" in response.text
    
    def test_prediction_endpoint_valid_data(self):
        """Test prediction with valid data"""
        payload = {
            "med_inc": 8.3252,
            "house_age": 41.0,
            "ave_rooms": 6.984127,
            "ave_bedrms": 1.02381,
            "population": 322.0,
            "ave_occup": 2.555556,
            "latitude": 37.88,
            "longitude": -122.23
        }
        
        response = requests.post(
            f"{self.BASE_URL}/api/v1/prediction/predict",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        
        assert response.status_code == 200
        data = response.json()
        assert "prediction" in data
        assert "prediction_formatted" in data
        assert "model_version" in data
        assert isinstance(data["prediction"], (int, float))
    
    def test_prediction_endpoint_invalid_data(self):
        """Test prediction with invalid data"""
        payload = {
            "med_inc": "invalid",  # Should be numeric
            "house_age": 41.0,
            "ave_rooms": 6.984127,
            "ave_bedrms": 1.02381,
            "population": 322.0,
            "ave_occup": 2.555556,
            "latitude": 37.88,
            "longitude": -122.23
        }
        
        response = requests.post(
            f"{self.BASE_URL}/api/v1/prediction/predict",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        
        assert response.status_code == 422  # Validation error
    
    def test_prediction_endpoint_missing_fields(self):
        """Test prediction with missing required fields"""
        payload = {
            "med_inc": 8.3252,
            "house_age": 41.0
            # Missing other required fields
        }
        
        response = requests.post(
            f"{self.BASE_URL}/api/v1/prediction/predict",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        
        assert response.status_code == 422  # Validation error
    
    def test_metrics_endpoint(self):
        """Test the Prometheus metrics endpoint"""
        response = requests.get(f"{self.BASE_URL}/metrics")
        
        assert response.status_code == 200
        assert "api_requests_total" in response.text
        assert "api_request_duration_seconds" in response.text
    
    def test_ml_metrics_endpoint(self):
        """Test the ML-specific metrics endpoint"""
        response = requests.get(f"{self.BASE_URL}/ml-metrics")
        
        assert response.status_code == 200
        assert "ml_predictions_total" in response.text
        assert "ml_model_load_time_seconds" in response.text
    
    def test_docs_endpoint(self):
        """Test the API documentation endpoint"""
        response = requests.get(f"{self.BASE_URL}/docs/")
        
        assert response.status_code == 200
        assert "swagger" in response.text.lower() or "openapi" in response.text.lower()
    
    def test_multiple_predictions(self):
        """Test multiple predictions to ensure consistency"""
        payload = {
            "med_inc": 5.0,
            "house_age": 25.0,
            "ave_rooms": 6.0,
            "ave_bedrms": 1.2,
            "population": 3000.0,
            "ave_occup": 3.0,
            "latitude": 34.0,
            "longitude": -118.0
        }
        
        predictions = []
        for _ in range(3):
            response = requests.post(
                f"{self.BASE_URL}/api/v1/prediction/predict",
                json=payload,
                headers={"Content-Type": "application/json"}
            )
            
            assert response.status_code == 200
            data = response.json()
            predictions.append(data["prediction"])
        
        # All predictions should be identical for the same input
        assert all(p == predictions[0] for p in predictions)
    
    def test_prediction_range(self):
        """Test that predictions are within reasonable range"""
        payload = {
            "med_inc": 6.0,
            "house_age": 30.0,
            "ave_rooms": 5.5,
            "ave_bedrms": 1.1,
            "population": 2500.0,
            "ave_occup": 2.8,
            "latitude": 37.0,
            "longitude": -121.0
        }
        
        response = requests.post(
            f"{self.BASE_URL}/api/v1/prediction/predict",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        
        assert response.status_code == 200
        data = response.json()
        prediction = data["prediction"]
        
        # California housing prices should be positive and reasonable
        assert prediction > 0
        assert prediction < 10  # In hundreds of thousands of dollars


class TestIntegration:
    """Integration tests for the complete system"""
    
    BASE_URL = "http://localhost:5001"
    
    def test_end_to_end_workflow(self):
        """Test complete workflow from health check to prediction"""
        # 1. Check health
        health_response = requests.get(f"{self.BASE_URL}/api/v1/health/")
        assert health_response.status_code == 200
        
        # 2. Make prediction
        payload = {
            "med_inc": 7.5,
            "house_age": 35.0,
            "ave_rooms": 6.2,
            "ave_bedrms": 1.0,
            "population": 2800.0,
            "ave_occup": 2.9,
            "latitude": 36.5,
            "longitude": -119.5
        }
        
        pred_response = requests.post(
            f"{self.BASE_URL}/api/v1/prediction/predict",
            json=payload,
            headers={"Content-Type": "application/json"}
        )
        assert pred_response.status_code == 200
        
        # 3. Check metrics updated
        metrics_response = requests.get(f"{self.BASE_URL}/metrics")
        assert metrics_response.status_code == 200
        assert "api_requests_total" in metrics_response.text
    
    def test_concurrent_requests(self):
        """Test system under concurrent load"""
        import concurrent.futures
        
        payload = {
            "med_inc": 6.5,
            "house_age": 20.0,
            "ave_rooms": 5.8,
            "ave_bedrms": 1.15,
            "population": 3200.0,
            "ave_occup": 3.1,
            "latitude": 38.0,
            "longitude": -122.5
        }
        
        def make_request():
            response = requests.post(
                f"{self.BASE_URL}/api/v1/prediction/predict",
                json=payload,
                headers={"Content-Type": "application/json"}
            )
            return response.status_code == 200
        
        # Make 10 concurrent requests
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
            futures = [executor.submit(make_request) for _ in range(10)]
            results = [future.result() for future in concurrent.futures.as_completed(futures)]
        
        # All requests should succeed
        assert all(results)


if __name__ == "__main__":
    # Run tests
    pytest.main([__file__, "-v", "--tb=short"])
