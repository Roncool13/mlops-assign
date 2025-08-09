# 🏠 California Housing Price Prediction API

A complete MLOps pipeline for predicting California housing prices using machine learning, featuring a production-ready REST API with interactive Swagger documentation, containerized deployment, and comprehensive monitoring.

[![Python](https://img.shields.io/badge/Python-3.10-blue.svg)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Flask-2.3.3-green.svg)](https://flask.palletsprojects.com/)

```bash
# Docker Compose with multiple replicas
docker-compose up --scale api=3

# Load balancer with nginx
docker-compose -f docker-compose.prod.yml up

# AWS deployment (requires AWS credentials)
./scripts/aws-deploy.sh full
```

**GitHub Secrets for CI/CD:**
- `AWS_ACCESS_KEY_ID` - Your AWS access key
- `AWS_SECRET_ACCESS_KEY` - Your AWS secret key  
- `DOCKERHUB_USERNAME` - DockerHub username
- `DOCKERHUB_TOKEN` - DockerHub access token

**Optional AWS Configuration:**
- `AWS_KEY_NAME` - EC2 key pair name (default: mlops-keypair)
- `AWS_SECURITY_GROUP` - Security group name (default: mlops-sg)  
- `INSTANCE_NAME` - EC2 instance name (default: mlops-california-housing)
1. **🚀 Quick Star## 📞 Support

For questions or issues:
- 📋 Run tests: `source ~/miniconda3/etc/profile.d/conda.sh && conda activate mlops-assign && python test_api.py`
- 🔍 Test monitoring: `source ~/miniconda3/etc/profile.d/conda.sh && conda activate mlops-assign && python test_prometheus.py`
- 📝 Check logs: `docker logs california-housing-api`
- 🔍 Health check: `curl http://localhost:5001/api/v1/health/health`
- 📊 View metrics: Visit [http://localhost:5001/metrics](http://localhost:5001/metrics)
- 🎨 Grafana dashboards: [http://localhost:3000](http://localhost:3000) (admin/grafana123)
- 📈 Prometheus queries: [http://localhost:9090](http://localhost:9090)./deploy_monitoring.sh` for complete monitoring setup
2. **🌐 Try the API**: Visit [http://localhost:5001](http://localhost:5001) for the interactive interface
3. **📖 Explore Docs**: Use [Swagger UI](http://localhost:5001/docs/) to test endpoints
4. **📊 Monitor Performance**: Check [Grafana dashboards](http://localhost:3000) and [Prometheus](http://localhost:9090)
5. **🔍 View Metrics**: Explore [metrics endpoint](http://localhost:5001/metrics)
6. **🚀 Scale Up**: Deploy to cloud platforms (AWS, GCP, Azure)
7. **🔄 Enhance**: Add model retraining, A/B testing, advanced alertingletsprojects.com/)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![MLflow](https://img.shields.io/badge/MLflow-2.8.1-orange.svg)](https://mlflow.org/)
[![API](https://img.shields.io/badge/API-Swagger_UI-brightgreen.svg)](http://localhost:5001/docs/)

## 🚀 Quick Start

### 🐳 Docker Deployment (Recommended)

```bash
# Clone the repository
git clone <repository-url>
cd Assignment-1

# Deploy with Docker
docker build -t california-housing-api .
docker run -d --name california-housing-api -p 5001:5000 california-housing-api

# Access the API
open http://localhost:5001          # Custom landing page
open http://localhost:5001/docs/    # Interactive Swagger UI
```

### 🔍 Prometheus Monitoring Deployment

```bash
# Activate conda environment first
source ~/miniconda3/etc/profile.d/conda.sh
conda activate mlops-assign

# Deploy API with complete monitoring stack
./deploy_monitoring.sh

# Or manually with Docker Compose
docker-compose -f docker-compose.monitoring.yml up -d

# Access monitoring interfaces
open http://localhost:9090    # Prometheus
open http://localhost:3000    # Grafana (admin/grafana123)
```

### 📱 API Interfaces

| Interface | URL | Description |
|-----------|-----|-------------|
| 🎨 **Landing Page** | [http://localhost:5001/](http://localhost:5001/) | User-friendly interface with documentation |
| 📖 **Swagger UI** | [http://localhost:5001/docs/](http://localhost:5001/docs/) | Interactive API documentation |
| 🔗 **Direct API** | `http://localhost:5001/api/v1/` | RESTful endpoints for integration |
| 📊 **Prometheus** | [http://localhost:9090](http://localhost:9090) | Metrics collection and monitoring |
| 🎨 **Grafana** | [http://localhost:3000](http://localhost:3000) | Visual dashboards (admin/grafana123) |
| 📈 **Metrics** | [http://localhost:5001/metrics](http://localhost:5001/metrics) | Prometheus metrics endpoint |

---

## 🎯 Features

### ✨ **Production-Ready API**
- 🌐 **Interactive Swagger UI** - Test endpoints directly in browser
- 🎨 **Custom Web Interface** - Professional landing page with documentation
- 🔧 **RESTful Architecture** - Organized namespaces and proper HTTP methods
- 📊 **Real-time Predictions** - Housing price predictions in millions USD
- 🛡️ **Input Validation** - Comprehensive request validation with helpful errors

### 🤖 **Advanced ML Pipeline**
- 🏆 **Random Forest Model** - Best performing model (R²=0.8009)
- ⚙️ **Feature Engineering** - Automated preprocessing with 11 engineered features
- 📈 **MLflow Tracking** - Experiment management and model versioning
- 🔄 **Model Artifacts** - Persistent model storage with joblib

### 🐳 **Enterprise Deployment**
- 📦 **Containerized** - Docker-ready with multi-stage builds
- 🔍 **Health Monitoring** - Comprehensive health checks and metrics
- 📝 **Structured Logging** - Detailed request/response logging
- 🌐 **CORS Support** - Cross-origin resource sharing enabled
- 📊 **Prometheus Integration** - Advanced metrics collection and monitoring
- 🎨 **Grafana Dashboards** - Beautiful visualization and alerting

---

## 📋 API Endpoints

| Method | Endpoint | Description | Response |
|--------|----------|-------------|----------|
| `GET` | `/` | Landing page with documentation | HTML interface |
| `GET` | `/docs/` | Interactive Swagger UI | API documentation |
| `GET` | `/metrics` | **Prometheus metrics** | Metrics in Prometheus format |
| `GET` | `/api/v1/health/` | API information and status | JSON status |
| `GET` | `/api/v1/health/health` | Health check | JSON health |
| `GET` | `/api/v1/health/metrics` | Monitoring metrics | JSON metrics |
| `POST` | `/api/v1/prediction/predict` | **Housing price prediction** | JSON prediction |

### 🏠 Prediction Endpoint

**Request Format:**
```json
POST /api/v1/prediction/predict
Content-Type: application/json

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
```

**Response Format:**
```json
{
    "prediction": 0.431,
    "prediction_formatted": "$0.431M",
    "prediction_units": "millions_usd",
    "model_used": "random_forest",
    "timestamp": "2025-08-04T17:35:02.315829",
    "input_features": { ... }
}
```

---

## �️ Setup & Installation

### 🐍 Local Development Setup

1. **Create and activate Conda environment:**
   ```bash
   conda create -n mlops-assign python=3.10
   conda activate mlops-assign
   ```

2. **Install dependencies:**
   ```bash
   # Make sure environment is activated
   source ~/miniconda3/etc/profile.d/conda.sh
   conda activate mlops-assign
   pip install -r requirements.txt
   ```

3. **Pull data with DVC (optional):**
   ```bash
   # Set AWS credentials
   export AWS_ACCESS_KEY_ID="your_key"
   export AWS_SECRET_ACCESS_KEY="your_secret"
   export AWS_DEFAULT_REGION="us-east-1"
   
   # Pull data
   dvc pull
   ```

### 🤖 Train Models (Optional)

```bash
# Activate environment and train models with MLflow tracking
source ~/miniconda3/etc/profile.d/conda.sh
conda activate mlops-assign
python src/model_train.py

# View MLflow UI
mlflow ui
# Open: http://localhost:5000
```

### 🚀 Run API Locally

```bash
# Activate environment and start Flask API
source ~/miniconda3/etc/profile.d/conda.sh
conda activate mlops-assign
python api/app.py

# Access at http://localhost:5000
```

---

## 🧪 Testing

### 🧪 Automated Testing

```bash
# Activate environment first
source ~/miniconda3/etc/profile.d/conda.sh
conda activate mlops-assign

# Run comprehensive API tests
python test_api.py

# Test Prometheus integration
python test_prometheus.py
```

**Expected Output:**
```
==================================================
TEST SUMMARY
==================================================
Health Check: ✅ PASS
Home Endpoint: ✅ PASS
Prediction Endpoint: ✅ PASS
Invalid Input Test: ✅ PASS
Metrics Endpoint: ✅ PASS

Total: 5/5 tests passed
```

### 🔧 Manual Testing

```bash
# Health check
curl http://localhost:5001/api/v1/health/

# Make prediction
curl -X POST http://localhost:5001/api/v1/prediction/predict \
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
  }'
```

---

## 📊 Model Performance

| Model | RMSE | R² Score | Features | Status |
|-------|------|----------|----------|---------|
| Linear Regression | 0.6791 | 0.6333 | 10 | Baseline |
| Decision Tree | 0.5795 | 0.7329 | 11 | Alternative |
| **Random Forest** | **0.5003** | **0.8009** | **11** | **🏆 Production** |

### 🔧 Feature Engineering Pipeline

The API automatically applies the following transformations:

1. **Engineered Features:**
   - `rooms_per_person` = `ave_rooms` / `ave_occup`
   - `bedrooms_per_room` = `ave_bedrms` / `ave_rooms`

2. **Log Transformations:**
   - `Population_log` = log1p(`population`)
   - `AveOccup_log` = log1p(`ave_occup`)

3. **Feature Selection:**
   - Removes `house_age` for Random Forest
   - Keeps original `population` alongside log transform
   - Results in 11 final features for optimal performance

---

## 📁 Project Structure

```
Assignment-1/
├── 🌐 api/                    # Flask API with Swagger UI & Prometheus
│   ├── app.py                 # Main API application with documentation
│   ├── monitoring.py          # Logging and metrics
│   └── prometheus_monitoring.py # Prometheus metrics integration
├── 🤖 src/                    # ML pipeline and preprocessing
│   ├── data_preprocess.py     # Feature engineering pipeline
│   ├── model_train.py         # MLflow model training
│   └── preprocessing_analysis.py
├── ⚙️ config/                 # Configuration
│   └── constants.py           # Path and parameter constants
├── 📊 data/                   # DVC-tracked datasets
│   └── california_housing_dataset/
├── 📓 notebooks/              # Jupyter notebooks for EDA
├── 📈 reports/                # Generated EDA reports
├── 🏆 models/                 # Saved model artifacts
│   ├── random_forest.joblib   # Production model (22MB)
│   ├── linear_regression.joblib
│   └── linear_regression_scaler.joblib
├── 📝 logs/                   # Application logs
├── 🐳 Dockerfile             # Container definition
├── 🚀 docker-compose.yml     # Multi-container setup
├── 📊 docker-compose.monitoring.yml # Prometheus monitoring stack
├── 🔧 deploy_monitoring.sh   # Automated monitoring deployment
├── 🧪 test_api.py            # API testing suite
├── 🔍 test_prometheus.py     # Prometheus integration tests
├── 📦 requirements.txt       # Python dependencies
├── 📊 prometheus/            # Prometheus configuration
│   └── prometheus.yml        # Metrics collection config
├── 🎨 grafana/               # Grafana dashboards
│   ├── provisioning/         # Auto-configuration
│   └── dashboards/           # Pre-built dashboards
└── 📚 README.md              # This file
```

---

## 🔍 Monitoring & Debugging

### 📊 Prometheus Metrics

The API exposes comprehensive metrics for monitoring:

```bash
# View all metrics
curl http://localhost:5001/metrics

# Key metrics available:
# - api_requests_total: Total API requests by method/endpoint/status
# - ml_predictions_total: Total ML predictions by model/status  
# - ml_prediction_duration_seconds: Prediction latency distribution
# - ml_prediction_value_millions_usd: Price prediction distribution
# - ml_model_loaded: Model loading status (1=loaded, 0=failed)
# - system_memory_usage_percent: System memory utilization
# - system_cpu_usage_percent: System CPU utilization
```

### 🎨 Grafana Dashboards

Access pre-built dashboards at [http://localhost:3000](http://localhost:3000):

- **Credentials**: admin / grafana123
- **Dashboard**: California Housing API - ML Monitoring
- **Panels**: API metrics, prediction rates, response times, system resources

### 📊 Health Monitoring

```bash
# Check API health
curl http://localhost:5001/api/v1/health/health

# View metrics
curl http://localhost:5001/api/v1/health/metrics

# Container logs
docker logs california-housing-api

# Follow logs in real-time
docker logs -f california-housing-api
```

### � Troubleshooting

**Common Issues:**

1. **Port already in use:**
   ```bash
   # Kill existing process
   lsof -ti:5001 | xargs kill -9
   
   # Or use different port
   docker run -p 5002:5000 california-housing-api
   ```

2. **Model not found:**
   ```bash
   # Check if models exist
   ls -la models/
   
   # Retrain if needed
   python src/model_train.py
   ```

3. **Docker build issues:**
   ```bash
   # Clean and rebuild
   docker system prune -a
   docker build --no-cache -t california-housing-api .
   ```

---

## 🚀 Advanced Usage

### 🔄 Model Retraining

```bash
# Activate environment and retrain with new data
source ~/miniconda3/etc/profile.d/conda.sh
conda activate mlops-assign
python src/model_train.py

# Export best model
python -c "
import mlflow
import joblib

# Load best model from MLflow
client = mlflow.tracking.MlflowClient()
experiment = client.get_experiment_by_name('california_housing')
runs = client.search_runs(experiment.experiment_id)
best_run = max(runs, key=lambda x: x.data.metrics.get('r2', 0))

# Save to production location
model_uri = f'runs:/{best_run.info.run_id}/model'
model = mlflow.sklearn.load_model(model_uri)
joblib.dump(model, 'models/random_forest.joblib')
"

# Restart API
docker restart california-housing-api
```

### 🌐 Production Deployment

```bash
# Build production image
docker build -t your-registry/california-housing-api:v1.0 .

# Push to registry
docker push your-registry/california-housing-api:v1.0

# Deploy to Kubernetes
kubectl apply -f k8s-deployment.yaml
```

### 📈 Scaling

```bash
# Docker Compose with multiple replicas
docker-compose up --scale api=3

# Load balancer with nginx
docker-compose -f docker-compose.prod.yml up
```

---

## 💡 Key Highlights

✅ **Production-Ready**: Comprehensive error handling, logging, and monitoring  
✅ **Interactive Docs**: Swagger UI with live API testing capabilities  
✅ **User-Friendly**: Custom web interface with clear documentation  
✅ **High Performance**: Random Forest model achieving R²=0.8009  
✅ **Feature Complete**: 11 engineered features for optimal predictions  
✅ **Containerized**: Docker-ready with health checks and graceful shutdown  
✅ **Well-Tested**: Comprehensive test suite with 5/5 passing tests  
✅ **Scalable**: RESTful architecture ready for production deployment  
✅ **Prometheus Integration**: Complete metrics collection and monitoring  
✅ **Grafana Dashboards**: Beautiful visualizations and alerting capabilities  

---

## � Next Steps

1. **🌐 Try the API**: Visit [http://localhost:5001](http://localhost:5001) for the interactive interface
2. **📖 Explore Docs**: Use [Swagger UI](http://localhost:5001/docs/) to test endpoints
3. **📊 Monitor Performance**: Check health endpoints and logs
4. **🚀 Scale Up**: Deploy to cloud platforms (AWS, GCP, Azure)
5. **🔄 Enhance**: Add model retraining, A/B testing, advanced monitoring

---

## 📞 Support

For questions or issues:
- 📋 Run tests: `python test_api.py`
- � Test monitoring: `python test_prometheus.py`
- �📝 Check logs: `docker logs california-housing-api`
- 🔍 Health check: `curl http://localhost:5001/api/v1/health/health`
- 📊 View metrics: Visit [http://localhost:5001/metrics](http://localhost:5001/metrics)
- 🎨 Grafana dashboards: [http://localhost:3000](http://localhost:3000) (admin/grafana123)
- 📈 Prometheus queries: [http://localhost:9090](http://localhost:9090)

**Happy Predicting! 🏠💰**
