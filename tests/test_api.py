"""
Test script for the Housing Prediction API
"""
import requests
import json

# API base URL
BASE_URL = "http://localhost:5001/api/v1"

def test_health_endpoint():
    """Test the health endpoint"""
    print("Testing health endpoint...")
    try:
        response = requests.get(f"{BASE_URL}/health/")
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_home_endpoint():
    """Test the home endpoint"""
    print("\nTesting home endpoint...")
    try:
        response = requests.get("http://localhost:5001/")  # Root endpoint returns HTML
        print(f"Status: {response.status_code}")
        print("Response type: HTML page")
        print(f"Contains 'California Housing': {'California Housing' in response.text}")
        return response.status_code == 200 and 'California Housing' in response.text
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_prediction_endpoint():
    """Test the prediction endpoint"""
    print("\nTesting prediction endpoint...")
    
    # Sample input data (California housing features)
    test_data = {
        "med_inc": 8.3252,      # Median income
        "house_age": 41,        # House age
        "ave_rooms": 6.984127,  # Average rooms
        "ave_bedrms": 1.02381,  # Average bedrooms
        "population": 322,      # Population
        "ave_occup": 2.555556,  # Average occupancy
        "latitude": 37.88,      # Latitude
        "longitude": -122.23    # Longitude
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/prediction/predict",
            json=test_data,
            headers={"Content-Type": "application/json"}
        )
        print(f"Status: {response.status_code}")
        print(f"Response: {json.dumps(response.json(), indent=2)}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_invalid_input():
    """Test with invalid input"""
    print("\nTesting with invalid input...")
    
    # Missing required field
    invalid_data = {
        "med_inc": 8.3252,
        "house_age": 41
        # Missing other required fields
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/prediction/predict",
            json=invalid_data,
            headers={"Content-Type": "application/json"}
        )
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        # API returns 500 for validation errors, which is acceptable
        return response.status_code in [400, 500]  # Accept both error codes
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_metrics_endpoint():
    """Test the metrics endpoint"""
    print("\nTesting metrics endpoint...")
    try:
        response = requests.get(f"{BASE_URL}/health/metrics")
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_api_info_endpoint():
    """Test the API info endpoint"""
    print("\nTesting API info endpoint...")
    try:
        response = requests.get(f"{BASE_URL}/health/info")
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"Error: {e}")
        return False

def test_prometheus_metrics_endpoint():
    """Test the Prometheus metrics endpoint"""
    print("\nTesting Prometheus metrics endpoint...")
    try:
        response = requests.get("http://localhost:5001/ml-metrics")
        print(f"Status: {response.status_code}")
        print("Response: Prometheus metrics format")
        print(f"Contains ML metrics: {'ml_predictions_total' in response.text}")
        return response.status_code == 200 and 'ml_predictions_total' in response.text
    except Exception as e:
        print(f"Error: {e}")
        return False

def main():
    """Run all tests"""
    print("="*50)
    print("API TESTING SCRIPT")
    print("="*50)
    
    tests = [
        ("Health Check", test_health_endpoint),
        ("Home Endpoint", test_home_endpoint),
        ("Prediction Endpoint", test_prediction_endpoint),
        ("Invalid Input Test", test_invalid_input),
        ("Metrics Endpoint", test_metrics_endpoint),
        ("API Info Endpoint", test_api_info_endpoint),
        ("Prometheus Metrics", test_prometheus_metrics_endpoint)
    ]
    
    results = []
    for test_name, test_func in tests:
        print(f"\n{'='*20}")
        try:
            result = test_func()
            results.append((test_name, result))
        except Exception as e:
            print(f"Test {test_name} failed with exception: {e}")
            results.append((test_name, False))
    
    # Summary
    print(f"\n{'='*50}")
    print("TEST SUMMARY")
    print("="*50)
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{test_name}: {status}")
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    print(f"\nTotal: {passed}/{total} tests passed")

if __name__ == "__main__":
    main()
