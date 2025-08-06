#!/bin/bash

# California Housing API - Prometheus Monitoring Setup
echo "🏠 California Housing API - Prometheus Monitoring Setup"
echo "=================================================="

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker first."
    exit 1
fi

echo "✅ Docker is running"

# Function to check if port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo "⚠️  Port $port is already in use"
        echo "🔧 Killing processes on port $port..."
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
}

# Check and free required ports
echo "🔍 Checking required ports..."
check_port 5001  # API
check_port 3000  # Grafana
check_port 9090  # Prometheus
check_port 9100  # Node Exporter

# Install Python dependencies
echo "📦 Installing Python dependencies..."
source ./activate_env.sh
activate_conda_env
pip install -r requirements.txt

# Build and deploy with monitoring
echo "🚀 Building and deploying with Prometheus monitoring..."

# Stop any existing containers
echo "🛑 Stopping existing containers..."
docker compose -f docker-compose.monitoring.yml down 2>/dev/null || true

# Build the API image
echo "🔨 Building API image..."
docker build -t california-housing-api .

# Start the monitoring stack
echo "🎯 Starting monitoring stack..."
docker compose -f docker-compose.monitoring.yml up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 15

# Check service health
echo "🔍 Checking service health..."

# Check API
if curl -s http://localhost:5001/api/v1/health/ >/dev/null; then
    echo "✅ API is healthy at http://localhost:5001"
else
    echo "❌ API health check failed"
fi

# Check Prometheus
if curl -s http://localhost:9090/-/healthy >/dev/null; then
    echo "✅ Prometheus is healthy at http://localhost:9090"
else
    echo "❌ Prometheus health check failed"
fi

# Check Grafana
if curl -s http://localhost:3000/api/health >/dev/null; then
    echo "✅ Grafana is healthy at http://localhost:3000"
else
    echo "❌ Grafana health check failed"
fi

# Check Node Exporter
if curl -s http://localhost:9100/metrics >/dev/null; then
    echo "✅ Node Exporter is healthy at http://localhost:9100"
else
    echo "❌ Node Exporter health check failed"
fi

echo ""
echo "🎉 Prometheus monitoring setup complete!"
echo "=================================================="
echo "🔗 Access Points:"
echo "   • 🏠 API Dashboard:     http://localhost:5001"
echo "   • 📊 Swagger API Docs:  http://localhost:5001/docs/"
echo "   • 📈 Prometheus:        http://localhost:9090"
echo "   • 🎨 Grafana:           http://localhost:3000"
echo "   • 📊 Metrics Endpoint:  http://localhost:5001/metrics"
echo ""
echo "🔐 Grafana Credentials:"
echo "   • Username: admin"
echo "   • Password: grafana123"
echo ""
echo "📊 Pre-configured Dashboard:"
echo "   • California Housing API - ML Monitoring"
echo ""
echo "🧪 Test the integration:"
echo "   source ./activate_env.sh && python test_prometheus.py"
echo ""
echo "🛑 To stop all services:"
echo "   docker compose -f docker-compose.monitoring.yml down"
