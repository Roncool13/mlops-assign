#!/bin/bash

# AWS Deployment Script for MLOps Pipeline
# This script handles deployment to AWS EC2 instances

set -e

# Configuration
AWS_REGION=${AWS_REGION:-us-west-2}
EC2_INSTANCE_TYPE=${EC2_INSTANCE_TYPE:-t3.medium}
KEY_NAME=${AWS_KEY_NAME:-mlops-keypair}
SECURITY_GROUP=${AWS_SECURITY_GROUP:-mlops-sg}
INSTANCE_NAME=${INSTANCE_NAME:-mlops-california-housing}

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

# Function to check AWS CLI and credentials
check_aws_setup() {
    print_status "Checking AWS setup..."
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install AWS CLI first."
        exit 1
    fi
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured. Please run 'aws configure'"
        exit 1
    fi
    
    print_success "AWS CLI and credentials verified"
}

# Function to create security group
create_security_group() {
    print_status "Creating security group: $SECURITY_GROUP"
    
    if aws ec2 describe-security-groups --group-names $SECURITY_GROUP --region $AWS_REGION >/dev/null 2>&1; then
        print_warning "Security group $SECURITY_GROUP already exists"
        return 0
    fi
    
    # Create security group
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --group-name $SECURITY_GROUP \
        --description "MLOps California Housing API Security Group" \
        --region $AWS_REGION \
        --query 'GroupId' \
        --output text)
    
    # Add inbound rules
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION
        
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port 5001 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION
        
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port 3000 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION
        
    aws ec2 authorize-security-group-ingress \
        --group-id $SECURITY_GROUP_ID \
        --protocol tcp \
        --port 9090 \
        --cidr 0.0.0.0/0 \
        --region $AWS_REGION
        
    print_success "Security group created: $SECURITY_GROUP_ID"
}

# Function to create key pair if it doesn't exist
create_key_pair() {
    print_status "Checking key pair: $KEY_NAME"
    
    if aws ec2 describe-key-pairs --key-names $KEY_NAME --region $AWS_REGION >/dev/null 2>&1; then
        print_warning "Key pair $KEY_NAME already exists"
        return 0
    fi
    
    print_status "Creating key pair: $KEY_NAME"
    aws ec2 create-key-pair \
        --key-name $KEY_NAME \
        --region $AWS_REGION \
        --query 'KeyMaterial' \
        --output text > ~/.ssh/$KEY_NAME.pem
    
    chmod 400 ~/.ssh/$KEY_NAME.pem
    print_success "Key pair created and saved to ~/.ssh/$KEY_NAME.pem"
}

# Function to get or create EC2 instance
setup_ec2_instance() {
    print_status "Setting up EC2 instance..."
    
    # Check if instance already exists
    EXISTING_INSTANCE=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" \
                  "Name=instance-state-name,Values=running,stopped" \
        --region $AWS_REGION \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text 2>/dev/null || echo "None")
    
    if [ "$EXISTING_INSTANCE" != "None" ] && [ "$EXISTING_INSTANCE" != "null" ]; then
        print_warning "Instance $INSTANCE_NAME already exists: $EXISTING_INSTANCE"
        INSTANCE_ID=$EXISTING_INSTANCE
        
        # Start instance if stopped
        INSTANCE_STATE=$(aws ec2 describe-instances \
            --instance-ids $INSTANCE_ID \
            --region $AWS_REGION \
            --query 'Reservations[0].Instances[0].State.Name' \
            --output text)
        
        if [ "$INSTANCE_STATE" = "stopped" ]; then
            print_status "Starting stopped instance..."
            aws ec2 start-instances --instance-ids $INSTANCE_ID --region $AWS_REGION
            aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION
        fi
    else
        # Create new instance
        print_status "Creating new EC2 instance..."
        
        # Get latest Amazon Linux 2 AMI
        AMI_ID=$(aws ec2 describe-images \
            --owners amazon \
            --filters "Name=name,Values=amzn2-ami-hvm-*" \
                      "Name=architecture,Values=x86_64" \
                      "Name=state,Values=available" \
            --region $AWS_REGION \
            --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
            --output text)
        
        print_status "Using AMI: $AMI_ID"
        
        # Create instance
        INSTANCE_ID=$(aws ec2 run-instances \
            --image-id $AMI_ID \
            --count 1 \
            --instance-type $INSTANCE_TYPE \
            --key-name $KEY_NAME \
            --security-groups $SECURITY_GROUP \
            --user-data file://scripts/ec2-user-data.sh \
            --region $AWS_REGION \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
            --query 'Instances[0].InstanceId' \
            --output text)
        
        print_success "Instance created: $INSTANCE_ID"
        
        # Wait for instance to be running
        print_status "Waiting for instance to be running..."
        aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION
    fi
    
    # Get public IP
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --region $AWS_REGION \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
    
    print_success "Instance is running at: $PUBLIC_IP"
    
    # Save deployment info
    cat > aws-deployment.env << EOF
INSTANCE_ID=$INSTANCE_ID
PUBLIC_IP=$PUBLIC_IP
AWS_REGION=$AWS_REGION
KEY_NAME=$KEY_NAME
SECURITY_GROUP=$SECURITY_GROUP
EOF
    
    print_success "Deployment info saved to aws-deployment.env"
}

# Function to deploy application to EC2
deploy_to_ec2() {
    if [ ! -f "aws-deployment.env" ]; then
        print_error "aws-deployment.env not found. Please run setup first."
        exit 1
    fi
    
    source aws-deployment.env
    
    print_status "Deploying application to EC2 instance: $INSTANCE_ID"
    
    # Wait for SSH to be available
    print_status "Waiting for SSH to be available..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if ssh -i ~/.ssh/$KEY_NAME.pem -o ConnectTimeout=5 -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP "echo 'SSH Connected'" >/dev/null 2>&1; then
            print_success "SSH connection established"
            break
        fi
        echo -ne "\r${BLUE}[INFO]${NC} Attempt $attempt/$max_attempts - waiting for SSH..."
        sleep 10
        ((attempt++))
    done
    
    if [ $attempt -gt $max_attempts ]; then
        print_error "SSH connection failed after $max_attempts attempts"
        exit 1
    fi
    
    # Deploy application
    print_status "Deploying application..."
    ssh -i ~/.ssh/$KEY_NAME.pem -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP << 'EOF'
        # Update system and install dependencies
        sudo yum update -y
        
        # Install Docker if not present
        if ! command -v docker &> /dev/null; then
            sudo yum install -y docker git
            sudo service docker start
            sudo usermod -a -G docker ec2-user
            # Re-login to apply group changes
            sudo su - ec2-user -c "echo 'Docker installed and user added to docker group'"
        fi
        
        # Install Docker Compose if not present
        if ! command -v docker-compose &> /dev/null; then
            sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
        fi
        
        # Clone or update repository
        cd /home/ec2-user
        if [ -d "california-housing-api" ]; then
            cd california-housing-api
            git pull
        else
            git clone https://github.com/Roncool13/mlops-assign.git california-housing-api
            cd california-housing-api
        fi
        
        # Start Docker service (in case it's not running)
        sudo service docker start
        
        # Deploy application
        docker-compose pull || true
        docker-compose down || true
        docker-compose up -d
        
        # Wait for services to start
        sleep 30
        
        # Test deployment
        if curl -f http://localhost:5001/api/v1/health/ >/dev/null 2>&1; then
            echo "✅ Deployment successful - API is healthy"
        else
            echo "❌ Deployment may have issues - API health check failed"
            exit 1
        fi
EOF
    
    print_success "Application deployed successfully!"
    print_status "Access your application at: http://$PUBLIC_IP:5001"
    print_status "Grafana dashboard: http://$PUBLIC_IP:3000"
    print_status "Prometheus: http://$PUBLIC_IP:9090"
}

# Function to show deployment status
show_status() {
    if [ ! -f "aws-deployment.env" ]; then
        print_warning "No deployment found. Run setup first."
        return 1
    fi
    
    source aws-deployment.env
    
    print_status "AWS Deployment Status"
    echo ""
    echo "🌍 Region: $AWS_REGION"
    echo "🖥️  Instance ID: $INSTANCE_ID"
    echo "🌐 Public IP: $PUBLIC_IP"
    echo "🔑 Key Name: $KEY_NAME"
    echo "🛡️  Security Group: $SECURITY_GROUP"
    echo ""
    
    # Check instance status
    INSTANCE_STATE=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --region $AWS_REGION \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text 2>/dev/null || echo "unknown")
    
    echo "📊 Instance State: $INSTANCE_STATE"
    
    if [ "$INSTANCE_STATE" = "running" ]; then
        echo ""
        echo "🌐 Service URLs:"
        echo "  API: http://$PUBLIC_IP:5001"
        echo "  Grafana: http://$PUBLIC_IP:3000"
        echo "  Prometheus: http://$PUBLIC_IP:9090"
        echo ""
        echo "🔗 SSH Access:"
        echo "  ssh -i ~/.ssh/$KEY_NAME.pem ec2-user@$PUBLIC_IP"
    fi
}

# Function to stop EC2 instance
stop_instance() {
    if [ ! -f "aws-deployment.env" ]; then
        print_error "aws-deployment.env not found. No instance to stop."
        exit 1
    fi
    
    source aws-deployment.env
    
    print_status "Stopping EC2 instance: $INSTANCE_ID"
    aws ec2 stop-instances --instance-ids $INSTANCE_ID --region $AWS_REGION
    print_success "Instance stop initiated"
}

# Function to terminate EC2 instance
terminate_instance() {
    if [ ! -f "aws-deployment.env" ]; then
        print_error "aws-deployment.env not found. No instance to terminate."
        exit 1
    fi
    
    source aws-deployment.env
    
    print_warning "This will permanently delete the EC2 instance!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Terminating EC2 instance: $INSTANCE_ID"
        aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $AWS_REGION
        rm -f aws-deployment.env
        print_success "Instance termination initiated and deployment info cleaned up"
    else
        print_status "Termination cancelled"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup       - Create security group, key pair, and EC2 instance"
    echo "  deploy      - Deploy application to existing EC2 instance"
    echo "  full        - Complete setup and deployment"
    echo "  status      - Show current deployment status"
    echo "  stop        - Stop the EC2 instance"
    echo "  terminate   - Terminate the EC2 instance (permanent)"
    echo "  help        - Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION          - AWS region (default: us-west-2)"
    echo "  EC2_INSTANCE_TYPE   - Instance type (default: t3.medium)"
    echo "  AWS_KEY_NAME        - Key pair name (default: mlops-keypair)"
    echo "  AWS_SECURITY_GROUP  - Security group name (default: mlops-sg)"
    echo "  INSTANCE_NAME       - Instance name tag (default: mlops-california-housing)"
    echo ""
    echo "Examples:"
    echo "  $0 setup     # Create AWS resources and EC2 instance"
    echo "  $0 deploy    # Deploy application to existing instance"
    echo "  $0 full      # Complete setup and deployment"
    echo "  $0 status    # Check deployment status"
}

# Main execution logic
main() {
    local command=${1:-help}
    
    case $command in
        "setup")
            check_aws_setup
            create_security_group
            create_key_pair
            setup_ec2_instance
            ;;
        "deploy")
            check_aws_setup
            deploy_to_ec2
            ;;
        "full")
            check_aws_setup
            create_security_group
            create_key_pair
            setup_ec2_instance
            sleep 60  # Give instance time to fully initialize
            deploy_to_ec2
            ;;
        "status")
            show_status
            ;;
        "stop")
            check_aws_setup
            stop_instance
            ;;
        "terminate")
            check_aws_setup
            terminate_instance
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
