#!/bin/bash

# Docker Hub Integration Script for MLOps Pipeline
# This script handles Docker image building, tagging, and pushing to Docker Hub

set -e

# Configuration
DOCKER_HUB_USERNAME=${DOCKER_HUB_USERNAME:-""}
DOCKER_HUB_REPO=${DOCKER_HUB_REPO:-"california-housing-api"}
IMAGE_TAG=${1:-$(date +%Y%m%d-%H%M%S)}
LOCAL_IMAGE_NAME="california-housing-api"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Function to check Docker Hub credentials
check_credentials() {
    if [ -z "$DOCKER_HUB_USERNAME" ]; then
        print_error "DOCKER_HUB_USERNAME environment variable not set"
        print_status "Please set it with: export DOCKER_HUB_USERNAME=your-username"
        exit 1
    fi
    
    # Check if logged in
    if ! docker info | grep -q "Username: $DOCKER_HUB_USERNAME" 2>/dev/null; then
        print_warning "Not logged in to Docker Hub"
        print_status "Please login with: docker login"
        exit 1
    fi
    
    print_success "Docker Hub credentials verified"
}

# Function to build and tag image
build_and_tag() {
    print_status "Building Docker image..."
    
    # Build image locally first
    docker build -t $LOCAL_IMAGE_NAME:$IMAGE_TAG .
    docker build -t $LOCAL_IMAGE_NAME:latest .
    
    # Tag for Docker Hub
    docker tag $LOCAL_IMAGE_NAME:$IMAGE_TAG $DOCKER_HUB_USERNAME/$DOCKER_HUB_REPO:$IMAGE_TAG
    docker tag $LOCAL_IMAGE_NAME:latest $DOCKER_HUB_USERNAME/$DOCKER_HUB_REPO:latest
    
    print_success "Image built and tagged: $DOCKER_HUB_USERNAME/$DOCKER_HUB_REPO:$IMAGE_TAG"
}

# Function to push to Docker Hub
push_to_hub() {
    print_status "Pushing images to Docker Hub..."
    
    # Push tagged version
    docker push $DOCKER_HUB_USERNAME/$DOCKER_HUB_REPO:$IMAGE_TAG
    
    # Push latest
    docker push $DOCKER_HUB_USERNAME/$DOCKER_HUB_REPO:latest
    
    print_success "Images pushed to Docker Hub"
    print_status "Tagged version: $DOCKER_HUB_USERNAME/$DOCKER_HUB_REPO:$IMAGE_TAG"
    print_status "Latest version: $DOCKER_HUB_USERNAME/$DOCKER_HUB_REPO:latest"
}

# Function to update local deployment with Docker Hub image
update_local_deployment() {
    print_status "Updating local deployment to use Docker Hub image..."
    
    # Create backup of docker-compose.yml
    cp docker-compose.yml docker-compose.yml.bak
    
    # Update docker-compose.yml to use Docker Hub image
    sed -i.tmp "s|build: \.|image: $DOCKER_HUB_USERNAME/$DOCKER_HUB_REPO:$IMAGE_TAG|g" docker-compose.yml
    rm docker-compose.yml.tmp
    
    # Pull and restart the API service
    docker compose pull california-housing-api
    docker compose up -d california-housing-api
    
    print_success "Local deployment updated with Docker Hub image"
}

# Function to revert to local build
revert_to_local() {
    print_status "Reverting to local Docker build..."
    
    if [ -f "docker-compose.yml.bak" ]; then
        mv docker-compose.yml.bak docker-compose.yml
        print_success "Reverted to local build configuration"
    else
        print_warning "No backup found, manually update docker-compose.yml"
    fi
}

# Function to trigger model retraining and rebuild
retrain_and_rebuild() {
    print_status "Starting model retraining and rebuild process..."
    
    # Activate conda environment if available
    if command -v conda &> /dev/null; then
        eval "$(conda shell.bash hook)"
        if conda env list | grep -q "mlops-assign"; then
            conda activate mlops-assign
            print_success "Activated conda environment: mlops-assign"
        fi
    fi
    
    # Run model training
    print_status "Training models..."
    python src/model_train.py
    
    # Generate new timestamp tag
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    NEW_TAG="model-$TIMESTAMP"
    
    print_success "Model training completed, building new image: $NEW_TAG"
    
    # Build and push new image
    IMAGE_TAG=$NEW_TAG
    build_and_tag
    push_to_hub
    
    # Update local deployment
    update_local_deployment
    
    print_success "Model retraining, rebuild, and deployment completed!"
    print_status "New image version: $DOCKER_HUB_USERNAME/$DOCKER_HUB_REPO:$NEW_TAG"
}

# Function to show current status
show_status() {
    print_status "Docker Hub Integration Status"
    echo ""
    echo "🐳 Local Images:"
    docker images | grep -E "(california-housing-api|$DOCKER_HUB_USERNAME/$DOCKER_HUB_REPO)" || echo "  No local images found"
    echo ""
    echo "🌐 Docker Hub Repository: https://hub.docker.com/r/$DOCKER_HUB_USERNAME/$DOCKER_HUB_REPO"
    echo ""
    echo "📝 Current docker-compose.yml configuration:"
    grep -A 3 -B 1 "california-housing-api:" docker-compose.yml || echo "  Configuration not found"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND] [TAG]"
    echo ""
    echo "Commands:"
    echo "  build [tag]     - Build and tag image (default: timestamp)"
    echo "  push [tag]      - Build, tag, and push to Docker Hub"
    echo "  deploy [tag]    - Build, push, and update local deployment"
    echo "  retrain         - Retrain model and rebuild/redeploy"
    echo "  revert          - Revert to local build configuration"
    echo "  status          - Show current status"
    echo "  help            - Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  DOCKER_HUB_USERNAME - Your Docker Hub username (required)"
    echo "  DOCKER_HUB_REPO     - Repository name (default: california-housing-api)"
    echo ""
    echo "Examples:"
    echo "  $0 build                    # Build with timestamp tag"
    echo "  $0 push v1.0.0              # Build and push with custom tag"
    echo "  $0 deploy                   # Full deployment with Docker Hub"
    echo "  $0 retrain                  # Retrain model and redeploy"
    echo "  $0 status                   # Show current status"
}

# Main execution logic
main() {
    local command=${1:-help}
    
    case $command in
        "build")
            check_credentials
            build_and_tag
            ;;
        "push")
            check_credentials
            build_and_tag
            push_to_hub
            ;;
        "deploy")
            check_credentials
            build_and_tag
            push_to_hub
            update_local_deployment
            ;;
        "retrain")
            check_credentials
            retrain_and_rebuild
            ;;
        "revert")
            revert_to_local
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

# Check if we're in the right directory
if [ ! -f "docker-compose.yml" ] || [ ! -f "Dockerfile" ]; then
    print_error "This script must be run from the project root directory"
    print_status "Please cd to the directory containing docker-compose.yml and Dockerfile"
    exit 1
fi

# Run main function with all arguments
main "$@"
