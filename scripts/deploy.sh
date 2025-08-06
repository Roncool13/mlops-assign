#!/bin/bash

# MLOps Unified Deployment Script
# This script handles building, testing, and deploying the California Housing API with monitoring

set -e  # Exit on any error

# Configuration
IMAGE_NAME="california-housing-api"
CONTAINER_NAME="california-housing-api"
API_PORT=5001
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
NODE_EXPORTER_PORT=9100

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Helper functions
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}========================================${NC}"
}

# Function to check if port is in use
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_warning "Port $port is already in use"
        print_status "Killing processes on port $port..."
        lsof -ti:$port | xargs kill -9 2>/dev/null || true
        sleep 2
        print_success "Port $port cleared"
    fi
}

# Function to wait for service to be healthy
wait_for_service() {
    local url=$1
    local service_name=$2
    local max_attempts=30
    local attempt=1
    
    print_status "Waiting for $service_name to be healthy..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "$url" >/dev/null 2>&1; then
            print_success "$service_name is healthy!"
            return 0
        fi
        
        echo -ne "\r${BLUE}[INFO]${NC} Attempt $attempt/$max_attempts - waiting for $service_name..."
        sleep 2
        ((attempt++))
    done
    
    echo ""
    print_error "$service_name failed to become healthy after $max_attempts attempts"
    return 1
}

# Function to activate conda environment
activate_conda_env() {
    print_status "Activating conda environment 'mlops-assign'..."
    
    # Check if conda is available
    if ! command -v conda &> /dev/null; then
        print_error "Conda is not installed or not in PATH"
        exit 1
    fi
    
    # Initialize conda for bash
    eval "$(conda shell.bash hook)"
    
    # Activate environment
    if conda activate mlops-assign 2>/dev/null; then
        print_success "Conda environment 'mlops-assign' activated"
    else
        print_error "Failed to activate conda environment 'mlops-assign'"
        print_status "Available environments:"
        conda env list
        exit 1
    fi
}

# Function to run comprehensive tests
run_tests() {
    print_header "RUNNING TESTS"
    
    activate_conda_env
    
    print_status "Running API tests..."
    if python tests/test_api.py; then
        print_success "API tests passed!"
    else
        print_error "API tests failed!"
        return 1
    fi
    
    print_status "Running Prometheus tests..."
    if python tests/test_prometheus.py; then
        print_success "Prometheus tests passed!"
    else
        print_error "Prometheus tests failed!"
        return 1
    fi
}

# Function to run quick smoke tests
run_smoke_tests() {
    print_status "Running smoke tests..."
    
    # Test health endpoint
    if curl -f -s http://localhost:$API_PORT/api/v1/health/ >/dev/null 2>&1; then
        print_success "Health check passed"
    else
        print_error "Health check failed"
        return 1
    fi
    
    # Test prediction endpoint
    local test_response=$(curl -s -X POST http://localhost:$API_PORT/api/v1/prediction/predict \
        -H "Content-Type: application/json" \
        -d '{
            "med_inc": 8.3252,
            "house_age": 41,
            "ave_rooms": 6.984127,
            "ave_bedrms": 1.02381,
            "population": 322,
            "ave_occup": 2.555556,
            "latitude": 37.88,
            "longitude": -122.23
        }')
    
    if echo "$test_response" | grep -q "prediction"; then
        print_success "Prediction endpoint test passed"
    else
        print_error "Prediction endpoint test failed"
        return 1
    fi
    
    print_success "All smoke tests passed"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "CHECKING PREREQUISITES"
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    print_success "Docker is running"
    
    # Check if conda environment exists
    if conda env list | grep -q "mlops-assign"; then
        print_success "Conda environment 'mlops-assign' found"
    else
        print_error "Conda environment 'mlops-assign' not found"
        print_status "Please create the environment first: conda env create -f environment.yml"
        exit 1
    fi
    
    # Check required files
    local required_files=(
        "Dockerfile"
        "requirements.txt" 
        "api/app.py"
        "prometheus/prometheus.yml"
        "grafana/provisioning/datasources/prometheus.yml"
        "grafana/dashboards/ml-api-dashboard.json"
    )
    
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            print_success "Found: $file"
        else
            print_error "Missing required file: $file"
            exit 1
        fi
    done
}

# Function to cleanup existing containers
cleanup() {
    print_header "CLEANING UP EXISTING CONTAINERS"
    
    # Stop and remove containers if they exist
    docker compose down --remove-orphans 2>/dev/null || true
    
    # Clean up any standalone containers
    local containers=("$CONTAINER_NAME" "prometheus" "grafana" "node-exporter")
    for container in "${containers[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            print_status "Stopping and removing container: $container"
            docker stop "$container" 2>/dev/null || true
            docker rm "$container" 2>/dev/null || true
        fi
    done
    
    # Clear ports
    local ports=($API_PORT $PROMETHEUS_PORT $GRAFANA_PORT $NODE_EXPORTER_PORT)
    for port in "${ports[@]}"; do
        check_port "$port"
    done
    
    print_success "Cleanup completed"
}

# Function to build and deploy
build_and_deploy() {
    print_header "BUILDING AND DEPLOYING"
    
    # Build and start services
    print_status "Building Docker images..."
    docker compose build --no-cache
    
    print_status "Starting all services..."
    docker compose up -d
    
    print_success "All services started!"
}

# Function to verify deployment
verify_deployment() {
    print_header "VERIFYING DEPLOYMENT"
    
    # Wait for all services to be healthy
    wait_for_service "http://localhost:$API_PORT/api/v1/health/" "California Housing API"
    wait_for_service "http://localhost:$PROMETHEUS_PORT/-/healthy" "Prometheus"
    wait_for_service "http://localhost:$GRAFANA_PORT/api/health" "Grafana"
    wait_for_service "http://localhost:$NODE_EXPORTER_PORT/metrics" "Node Exporter"
    
    # Test API functionality
    print_status "Testing API prediction endpoint..."
    local test_response=$(curl -s -X POST http://localhost:$API_PORT/api/v1/prediction/predict \
        -H "Content-Type: application/json" \
        -d '{
            "med_inc": 8.3252,
            "house_age": 41.0,
            "ave_rooms": 6.984127,
            "ave_bedrms": 1.02381,
            "population": 322.0,
            "ave_occup": 2.555556,
            "latitude": 37.88,
            "longitude": -122.23
        }')
    
    if echo "$test_response" | grep -q "prediction"; then
        print_success "API prediction endpoint working!"
        echo "Test prediction: $(echo "$test_response" | jq -r '.prediction_formatted' 2>/dev/null || echo 'N/A')"
    else
        print_error "API prediction endpoint test failed"
        return 1
    fi
    
    # Test metrics endpoints
    print_status "Testing metrics endpoints..."
    if curl -s "http://localhost:$API_PORT/metrics" | grep -q "api_requests_total"; then
        print_success "Standard metrics endpoint working!"
    else
        print_warning "Standard metrics endpoint has issues"
    fi
    
    if curl -s "http://localhost:$API_PORT/ml-metrics" | grep -q "ml_predictions_total"; then
        print_success "ML metrics endpoint working!"
    else
        print_warning "ML metrics endpoint has issues"
    fi
}

# Function to display access information
display_access_info() {
    print_header "ACCESS INFORMATION"
    
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}📱 SERVICE URLS:${NC}"
    echo -e "  🏠 California Housing API:    http://localhost:$API_PORT"
    echo -e "  📊 API Documentation:         http://localhost:$API_PORT/docs/"
    echo -e "  📈 Prometheus:                http://localhost:$PROMETHEUS_PORT"
    echo -e "  📊 Grafana Dashboard:         http://localhost:$GRAFANA_PORT"
    echo -e "  🖥️  Node Exporter:             http://localhost:$NODE_EXPORTER_PORT"
    echo ""
    echo -e "${BLUE}🔐 LOGIN CREDENTIALS:${NC}"
    echo -e "  Grafana Username: admin"
    echo -e "  Grafana Password: grafana123"
    echo ""
    echo -e "${BLUE}📊 DIRECT DASHBOARD ACCESS:${NC}"
    echo -e "  ML Monitoring Dashboard: http://localhost:$GRAFANA_PORT/d/california_housing_ml/california-housing-api---ml-monitoring"
    echo ""
    echo -e "${BLUE}🔧 METRICS ENDPOINTS:${NC}"
    echo -e "  Standard Metrics: http://localhost:$API_PORT/metrics"
    echo -e "  ML Metrics:       http://localhost:$API_PORT/ml-metrics"
    echo ""
    echo -e "${YELLOW}💡 NEXT STEPS:${NC}"
    echo -e "  1. Open Grafana dashboard to view monitoring"
    echo -e "  2. Test API endpoints using the Swagger UI"
    echo -e "  3. Check Prometheus for metrics collection"
    echo -e "  4. Monitor logs: docker compose logs -f"
}

# Function to show service status
show_status() {
    print_header " SERVICE STATUS"
    docker compose ps
    echo ""
    print_status "Service Health Checks:"
    curl -s http://localhost:$API_PORT/api/v1/health/ 2>/dev/null && echo "✅ API: Healthy" || echo "❌ API: Unhealthy"
    curl -s http://localhost:$PROMETHEUS_PORT/-/healthy 2>/dev/null && echo "✅ Prometheus: Healthy" || echo "❌ Prometheus: Unhealthy"
    curl -s http://localhost:$GRAFANA_PORT/api/health 2>/dev/null && echo "✅ Grafana: Healthy" || echo "❌ Grafana: Unhealthy"
    curl -s http://localhost:$NODE_EXPORTER_PORT/metrics 2>/dev/null >/dev/null && echo "✅ Node Exporter: Healthy" || echo "❌ Node Exporter: Unhealthy"
}

# Function to restart services
restart_services() {
    print_header "🔄 RESTARTING SERVICES"
    docker compose restart
    sleep 5
    verify_deployment
    print_success "Services restarted successfully"
}

# Function to show logs
show_logs() {
    print_header "📋 SERVICE LOGS"
    docker compose logs -f
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy     - Full deployment (cleanup, build, deploy, verify)"
    echo "  test       - Run comprehensive tests only"
    echo "  smoke      - Run quick smoke tests only"
    echo "  cleanup    - Stop and remove all containers"
    echo "  restart    - Restart all services"
    echo "  logs       - Show logs from all services"
    echo "  status     - Show status of all services"
    echo "  help       - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 deploy     # Full deployment with verification"
    echo "  $0 test       # Run comprehensive tests"
    echo "  $0 smoke      # Run quick smoke tests"
    echo "  $0 cleanup    # Clean up containers"
    echo "  $0 status     # Check service status"
}

# Main execution logic
main() {
    local command=${1:-deploy}
    
    case $command in
        "deploy")
            print_header "🚀 CALIFORNIA HOUSING API - FULL DEPLOYMENT"
            check_prerequisites
            cleanup
            build_and_deploy
            sleep 10  # Give services time to fully start
            verify_deployment
            display_access_info
            ;;
        "test")
            print_header "🧪 RUNNING COMPREHENSIVE TESTS"
            run_tests
            ;;
        "smoke")
            print_header "💨 RUNNING SMOKE TESTS"
            run_smoke_tests
            ;;
        "cleanup")
            cleanup
            print_success "Cleanup completed"
            ;;
        "restart")
            restart_services
            ;;
        "logs")
            show_logs
            ;;
        "status")
            show_status
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            print_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
