# MLOps Pipeline Summary - California Housing Price Prediction

## Project Overview

This project implements a complete MLOps pipeline for a California Housing price prediction model, demonstrating industry best practices for machine learning operations. The solution covers the entire ML lifecycle from data versioning to production deployment and monitoring.

## Architecture

### 1. **Data Layer**
- **Dataset**: California Housing dataset (20,640 samples, 8 features)
- **Versioning**: DVC (Data Version Control) with S3 remote storage
- **Preprocessing**: Automated data cleaning with `dataprep` library
- **Feature Engineering**: Skewness handling, log transformations, derived features

### 2. **Model Layer**
- **Algorithms**: Linear Regression, Decision Tree, Random Forest
- **Experiment Tracking**: MLflow with SQLite backend
- **Model Registry**: Best model selection based on RMSE and R²
- **Performance**: Random Forest achieved R² = 0.80, RMSE = 0.50

### 3. **API Layer**
- **Framework**: Flask REST API with Pydantic validation
- **Endpoints**: `/predict`, `/health`, `/metrics`
- **Containerization**: Docker with multi-stage builds
- **Monitoring**: SQLite-based logging with Prometheus metrics

### 4. **Infrastructure Layer**
- **CI/CD**: GitHub Actions pipeline
- **Deployment**: Automated Docker builds and deployments
- **Monitoring**: Request logging, performance metrics, health checks

## Key Features

### ✅ **Completed Components**

1. **Repository & Data Versioning (Part 1)**
   - GitHub repository with clean structure
   - DVC integration for data tracking
   - Automated data preprocessing pipeline

2. **Model Development & Tracking (Part 2)**
   - Three ML models with different preprocessing strategies
   - MLflow experiment tracking with comprehensive metrics
   - Automated model comparison and selection

3. **API & Docker Packaging (Part 3)**
   - Production-ready Flask API with input validation
   - Dockerized application with health checks
   - JSON-based prediction interface

4. **CI/CD Pipeline (Part 4)**
   - GitHub Actions workflow for automated testing
   - Docker image building and pushing to registry
   - Automated deployment with smoke tests

5. **Logging & Monitoring (Part 5)**
   - Comprehensive request/response logging
   - SQLite-based metrics storage
   - Prometheus-compatible metrics endpoint

## Technical Implementation

### **Data Pipeline**
```
Raw Data → DVC Tracking → Cleaning → Feature Engineering → Model Training
```

### **Preprocessing Strategy**
- **Linear Regression**: StandardScaler + log transformations for skewed features
- **Decision Tree/Random Forest**: Minimal preprocessing to preserve interpretability
- **Feature Engineering**: `rooms_per_person`, `bedrooms_per_room`, log-transformed populations

### **Model Performance**
| Model | RMSE | R² Score | Features |
|-------|------|----------|----------|
| Linear Regression | 0.6791 | 0.6333 | 10 |
| Decision Tree | 0.5795 | 0.7329 | 11 |
| **Random Forest** | **0.5003** | **0.8010** | 11 |

### **API Endpoints**
- `GET /` - Service information
- `GET /health` - Health check
- `POST /predict` - Price prediction (requires JSON input)
- `GET /metrics` - Prometheus-style metrics

### **Deployment Strategy**
1. **Development**: Local testing with Flask dev server
2. **Staging**: Docker container with volume mounts
3. **Production**: Containerized deployment with CI/CD automation

## Usage Instructions

### **Local Development**
```bash
# Install dependencies
pip install -r requirements.txt

# Train models
python src/model_train.py

# Start API
python api/app.py

# Test API
python test_api.py
```

### **Docker Deployment**
```bash
# Full deployment pipeline
./deploy.sh deploy

# Stop service
./deploy.sh stop

# View logs
./deploy.sh logs
```

### **Prediction Example**
```bash
curl -X POST http://localhost:5000/predict \
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
  }'
```

## Repository Structure
```
Assignment-1/
├── api/                    # Flask API implementation
├── src/                    # Data processing and model training
├── config/                 # Configuration constants
├── data/                   # Dataset (DVC tracked)
├── notebooks/              # EDA notebooks
├── reports/                # EDA reports
├── .github/workflows/      # CI/CD pipeline
├── Dockerfile             # Container configuration
├── requirements.txt       # Python dependencies
└── deploy.sh              # Deployment script
```

## Future Enhancements

### **Immediate Next Steps**
- Implement proper MLflow model registry integration
- Add comprehensive unit tests with pytest
- Set up production monitoring with Prometheus/Grafana

### **Advanced Features**
- Model retraining triggers on data drift detection
- A/B testing framework for model comparison
- Kubernetes deployment with Helm charts
- Real-time streaming prediction pipeline

## Conclusion

This MLOps pipeline demonstrates a production-ready approach to machine learning deployment, incorporating industry best practices for reproducibility, scalability, and maintainability. The solution successfully addresses all assignment requirements while providing a foundation for future enhancements and production scaling.

**Key Achievements:**
- ✅ Complete data versioning and tracking
- ✅ Comprehensive experiment management
- ✅ Production-ready API with monitoring
- ✅ Automated CI/CD pipeline
- ✅ Containerized deployment strategy

The pipeline is ready for production deployment and can serve as a template for similar ML projects requiring robust MLOps practices.
