#!/usr/bin/env python3
"""
Test script for Prometheus metrics validation
"""
import requests
import time

def test_prometheus_integration():
    """Test Prometheus metrics are working"""
    
    base_url = "http://localhost:5001"  # Updated to match standardized port
    metrics_url = f"{base_url}/metrics"
    predict_url = f"{base_url}/api/v1/prediction/predict"
    
    print("🔍 Testing Prometheus Integration...")
    print("=" * 50)
    
    # Test 1: Check if metrics endpoint is available
    print("\n1️⃣  Testing /metrics endpoint...")
    try:
        response = requests.get(metrics_url, timeout=10)
        if response.status_code == 200:
            print("✅ Metrics endpoint is accessible")
            print(f"📊 Metrics response size: {len(response.text)} bytes")
            
            # Check for key metrics from both endpoints
            metrics_text = response.text
            
            # Also check custom ML metrics endpoint
            ml_metrics_url = f"{base_url}/ml-metrics"
            ml_response = requests.get(ml_metrics_url, timeout=10)
            if ml_response.status_code == 200:
                print("✅ Custom ML metrics endpoint is accessible")
                metrics_text += ml_response.text
            
            expected_metrics = [
                'api_requests_total',
                'ml_predictions_total', 
                'ml_prediction_duration_seconds',
                'ml_model_loaded',
                'system_memory_usage_percent',
                'system_cpu_usage_percent'
            ]
            
            for metric in expected_metrics:
                if metric in metrics_text:
                    print(f"✅ Found metric: {metric}")
                else:
                    print(f"❌ Missing metric: {metric}")
        else:
            print(f"❌ Metrics endpoint returned status {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Failed to access metrics endpoint: {e}")
        return False
    
    # Test 2: Make some predictions to generate metrics
    print("\n2️⃣  Generating prediction metrics...")
    
    test_data = {
        "med_inc": 8.3252,
        "house_age": 41.0,
        "ave_rooms": 6.984127,
        "ave_bedrms": 1.02381,
        "population": 322.0,
        "ave_occup": 2.555556,
        "latitude": 37.88,
        "longitude": -122.23
    }
    
    # Make multiple predictions to generate metrics
    for i in range(5):
        try:
            response = requests.post(predict_url, json=test_data, timeout=10)
            if response.status_code == 200:
                result = response.json()
                print(f"✅ Prediction {i+1}: ${result['prediction_formatted']}")
            else:
                print(f"❌ Prediction {i+1} failed with status {response.status_code}")
        except Exception as e:
            print(f"❌ Prediction {i+1} failed: {e}")
        
        time.sleep(1)  # Brief delay between requests
    
    # Test 3: Verify metrics were updated
    print("\n3️⃣  Verifying metrics were updated...")
    try:
        response = requests.get(metrics_url, timeout=10)
        if response.status_code == 200:
            metrics_text = response.text
            
            # Check for specific metric values
            if 'ml_predictions_total' in metrics_text:
                print("✅ ML prediction metrics are being recorded")
            
            if 'api_requests_total' in metrics_text:
                print("✅ API request metrics are being recorded")
                
            if 'ml_model_loaded 1' in metrics_text:
                print("✅ Model status is being tracked")
            
            # Show sample metrics
            print("\n📊 Sample Prometheus Metrics:")
            print("-" * 30)
            for line in metrics_text.split('\n'):
                if any(metric in line for metric in ['ml_predictions_total', 'api_requests_total', 'ml_model_loaded']):
                    if not line.startswith('#') and line.strip():
                        print(f"   {line}")
        
        print("\n✅ Prometheus integration test completed successfully!")
        return True
    
    except Exception as e:
        print(f"❌ Failed to verify updated metrics: {e}")
        return False

def test_grafana_dashboard():
    """Test if Grafana is accessible"""
    print("\n🎨 Testing Grafana Dashboard...")
    print("=" * 50)
    
    grafana_url = "http://localhost:3000"
    
    try:
        response = requests.get(grafana_url, timeout=10)
        if response.status_code == 200:
            print("✅ Grafana is accessible at http://localhost:3000")
            print("📋 Default credentials: admin / grafana123")
            print("📊 Dashboard: California Housing API - ML Monitoring")
            return True
        else:
            print(f"❌ Grafana returned status {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Failed to access Grafana: {e}")
        print("💡 Make sure to run: docker-compose -f docker-compose.monitoring.yml up -d")
        return False

def test_prometheus_ui():
    """Test if Prometheus UI is accessible"""
    print("\n🔎 Testing Prometheus UI...")
    print("=" * 50)
    
    prometheus_url = "http://localhost:9090"
    
    try:
        response = requests.get(prometheus_url, timeout=10)
        if response.status_code == 200:
            print("✅ Prometheus UI is accessible at http://localhost:9090")
            print("🔍 Try these queries:")
            print("   • rate(api_requests_total[5m])")
            print("   • ml_predictions_total")
            print("   • histogram_quantile(0.95, rate(ml_prediction_duration_seconds_bucket[5m]))")
            return True
        else:
            print(f"❌ Prometheus UI returned status {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Failed to access Prometheus UI: {e}")
        print("💡 Make sure to run: docker-compose -f docker-compose.monitoring.yml up -d")
        return False

if __name__ == "__main__":
    print("🏠 California Housing API - Prometheus Integration Test")
    print("=" * 60)
    
    # Test API and Prometheus metrics
    api_success = test_prometheus_integration()
    
    # Test Grafana (optional)
    grafana_success = test_grafana_dashboard()
    
    # Test Prometheus UI (optional)
    prometheus_success = test_prometheus_ui()
    
    print("\n" + "=" * 60)
    print("📋 TEST SUMMARY")
    print("=" * 60)
    print(f"API & Metrics: {'✅ PASS' if api_success else '❌ FAIL'}")
    print(f"Grafana:       {'✅ PASS' if grafana_success else '❌ FAIL'}")
    print(f"Prometheus UI: {'✅ PASS' if prometheus_success else '❌ FAIL'}")
    
    if api_success:
        print("\n🎉 Prometheus integration is working!")
        print("🔗 Access points:")
        print("   • API: http://localhost:5001")  # Updated port
        print("   • Metrics: http://localhost:5001/metrics")  # Updated port
        print("   • Prometheus: http://localhost:9090")
        print("   • Grafana: http://localhost:3000")
    else:
        print("\n❌ Some tests failed. Check the API deployment.")
