# MLOps CI/CD Setup Guide

This guide explains how to set up and use the CI/CD pipeline for the California Housing Price Prediction API.

## 🚀 Quick Start

### Prerequisites

1. **GitHub Repository**: Fork or clone this repository
2. **Docker Hub Account**: Create account at [hub.docker.com](https://hub.docker.com)
3. **AWS Account** (optional): For cloud deployment

### Required GitHub Secrets

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

```bash
# Docker Hub
DOCKERHUB_USERNAME=your-dockerhub-username
DOCKERHUB_TOKEN=your-dockerhub-access-token

# AWS (optional)
AWS_ACCESS_KEY_ID=your-aws-access-key
AWS_SECRET_ACCESS_KEY=your-aws-secret-key
```

## 📋 Directory Structure

```
Assignment-1/
├── .github/workflows/
│   └── mlops-pipeline.yml          # Main CI/CD pipeline
├── scripts/
│   ├── deploy.sh                   # Local deployment script
│   ├── docker-hub-integration.sh   # Docker Hub integration
│   ├── aws-deploy.sh              # AWS deployment script
│   └── ec2-user-data.sh           # EC2 setup script
├── tests/
│   ├── test_api.py                # Basic API tests
│   ├── test_prometheus.py         # Prometheus tests
│   └── test_api_comprehensive.py  # Comprehensive test suite
├── api/                           # FastAPI application
├── src/                           # Source code
├── models/                        # ML models
├── docker-compose.yml             # Container orchestration
├── Dockerfile                     # Container definition
└── requirements.txt               # Python dependencies
```

## 🔄 CI/CD Pipeline Overview

### Triggers

- **Push to main/develop**: Full pipeline
- **Pull Request**: Lint and test only
- **Schedule**: Weekly model retraining (Sundays 2 AM UTC)
- **Manual**: Workflow dispatch with options

### Pipeline Jobs

1. **Lint and Test**
   - Code quality checks (flake8, black)
   - Unit tests (pytest)
   - API integration tests

2. **Model Retraining**
   - Check for new data
   - Retrain models if needed
   - Version and artifact storage

3. **Build and Push**
   - Build Docker image
   - Push to Docker Hub
   - Multi-platform support (amd64, arm64)

4. **Deploy Local**
   - Pull latest images
   - Deploy with monitoring stack
   - Run smoke tests

5. **Deploy AWS**
   - Create/update EC2 instance
   - Deploy application stack
   - Health checks

## 🛠️ Local Development

### Setup

```bash
# Clone repository
git clone https://github.com/your-username/mlops-assign.git
cd Assignment-1

# Make scripts executable
chmod +x scripts/*.sh

# Set up environment
conda create -n mlops-assign python=3.10
conda activate mlops-assign
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

### Local Deployment

```bash
# Full local deployment
./scripts/deploy.sh deploy

# Available commands
./scripts/deploy.sh help
```

### Docker Hub Integration

```bash
# Set environment variable
export DOCKER_HUB_USERNAME=your-username

# Login to Docker Hub
docker login

# Build and push
./scripts/docker-hub-integration.sh push

# Retrain model and rebuild
./scripts/docker-hub-integration.sh retrain
```

## ☁️ AWS Deployment

### Setup AWS CLI

```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure credentials
aws configure
```

### Deploy to AWS

```bash
# Full AWS deployment
./scripts/aws-deploy.sh full

# Available commands
./scripts/aws-deploy.sh help
```

## 🧪 Testing

### Run Tests Locally

```bash
# Start services
./scripts/deploy.sh deploy

# Run all tests
python -m pytest tests/ -v

# Run specific test
python tests/test_api_comprehensive.py
```

### Test Categories

- **Unit Tests**: Individual component testing
- **Integration Tests**: API endpoint testing
- **Load Tests**: Concurrent request handling
- **Health Checks**: Service availability

## 📊 Monitoring

### Local Monitoring

- **API**: http://localhost:5001
- **Grafana**: http://localhost:3000 (admin/grafana123)
- **Prometheus**: http://localhost:9090
- **Metrics**: http://localhost:5001/metrics

### AWS Monitoring

- **CloudWatch**: Automatic log collection
- **Health Checks**: Automated monitoring
- **Alerts**: System status notifications

## 🔄 Model Retraining

### Automatic Retraining

- **Schedule**: Weekly on Sundays
- **Data Changes**: When new data detected
- **Manual Trigger**: GitHub Actions workflow dispatch

### Manual Retraining

```bash
# Local retraining
./scripts/docker-hub-integration.sh retrain

# Force retraining via GitHub Actions
# Go to Actions → MLOps CI/CD Pipeline → Run workflow
# Set "Force model retraining" to true
```

## 🚨 Troubleshooting

### Common Issues

1. **Docker Hub Login Failed**
   ```bash
   docker login
   # Enter your credentials
   ```

2. **AWS Permissions**
   ```bash
   # Ensure IAM user has EC2, SSM permissions
   aws sts get-caller-identity
   ```

3. **Port Conflicts**
   ```bash
   ./scripts/deploy.sh cleanup
   ./scripts/deploy.sh deploy
   ```

4. **Model Loading Issues**
   ```bash
   # Check model files exist
   ls -la models/
   
   # Retrain if needed
   python src/model_train.py
   ```

### Logs and Debugging

```bash
# Container logs
docker compose logs -f

# Service status
./scripts/deploy.sh status

# AWS instance logs
aws logs describe-log-groups
```

## 📝 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `DOCKER_HUB_USERNAME` | Docker Hub username | Required |
| `AWS_REGION` | AWS deployment region | us-west-2 |
| `EC2_INSTANCE_TYPE` | EC2 instance type | t3.medium |

### Customization

- **Model Parameters**: Edit `src/model_train.py`
- **API Configuration**: Edit `api/app.py`
- **Monitoring**: Edit `prometheus/prometheus.yml`
- **Deployment**: Edit `docker-compose.yml`

## 🔐 Security

- Store sensitive data in GitHub Secrets
- Use IAM roles with minimal permissions
- Regular security updates via Dependabot
- Container vulnerability scanning

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Hub Documentation](https://docs.docker.com/docker-hub/)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [MLflow Documentation](https://mlflow.org/docs/latest/index.html)
