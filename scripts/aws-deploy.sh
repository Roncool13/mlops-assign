#!/bin/bash

# AWS Deployment Script for MLOps Pipeline
# This script handles deployment to AWS EC2 instances

set -e

# Configuration
AWS_REGION=${AWS_REGION:-us-east-2}
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
    
    if ! aws sts get-caller-identity; then
        print_error "AWS credentials not configured. Please run 'aws configure'"
        exit 1
    fi
    
    print_success "AWS CLI and credentials verified"
}

# Function to create security group
create_security_group() {
    print_status "Creating security group: $SECURITY_GROUP"
    
    if aws ec2 describe-security-groups --group-names $SECURITY_GROUP --region $AWS_REGION; then
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
    
    # Determine SSH directory and key path safely
    if [ -n "$HOME" ] && [ -d "$HOME" ]; then
        SSH_DIR="$HOME/.ssh"
        SSH_KEY_PATH="$HOME/.ssh/$KEY_NAME.pem"
    else
        # Fallback to current user's home directory
        SSH_DIR=~/.ssh
        SSH_KEY_PATH=~/.ssh/$KEY_NAME.pem
        print_warning "HOME environment variable not set or invalid, using tilde expansion"
    fi
    
    # Check if key pair exists in AWS
    if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region $AWS_REGION; then
        print_warning "Key pair $KEY_NAME already exists in AWS"
        
        # Check if we have the private key locally
        if [ -f "$SSH_KEY_PATH" ]; then
            print_status "Private key found locally at $SSH_KEY_PATH"
            return 0
        else
            print_warning "Private key not found locally at $SSH_KEY_PATH"
            print_status "Deleting existing key pair and creating new one..."
            
            # Delete existing key pair from AWS with error handling
            if aws ec2 delete-key-pair \
                --key-name "$KEY_NAME" \
                --region $AWS_REGION; then
                print_success "Existing key pair deleted from AWS"
            else
                print_error "Failed to delete existing key pair from AWS"
                print_error "You may need to delete it manually in the AWS Console"
                return 1
            fi
            
            # Verify deletion was successful using AWS waiter (inverse logic)
            print_status "Verifying key pair deletion..."
            if timeout 30 aws ec2 wait key-pair-exists --key-names "$KEY_NAME" --region $AWS_REGION; then
                # If wait succeeds, key pair still exists - deletion failed
                print_error "Key pair still exists in AWS after deletion attempt"
                print_error "Please delete $KEY_NAME manually in AWS Console and retry"
                return 1
            else
                # If wait fails/times out, key pair doesn't exist - deletion succeeded
                print_success "Key pair deletion confirmed"
            fi
        fi
    fi
    
    print_status "Creating new key pair: $KEY_NAME"
    
    # Ensure .ssh directory exists with proper permissions
    if [ ! -d "$SSH_DIR" ]; then
        mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
        print_status "Created SSH directory at $SSH_DIR"
    fi
    
    # Create new key pair with error handling
    if aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --region $AWS_REGION \
        --query 'KeyMaterial' \
        --output text > "$SSH_KEY_PATH"; then
        
        chmod 400 "$SSH_KEY_PATH"
        print_success "Key pair created and saved to $SSH_KEY_PATH"
        
        # Verify the key file was created successfully
        if [ ! -f "$SSH_KEY_PATH" ] || [ ! -s "$SSH_KEY_PATH" ]; then
            print_error "Key pair creation appeared to succeed but file is missing or empty"
            return 1
        fi
    else
        print_error "Failed to create key pair in AWS"
        return 1
    fi
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
            --instance-type $EC2_INSTANCE_TYPE \
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

# Function to deploy via user data (for CI/CD environments)
deploy_via_user_data() {
    print_status "Deploying via AWS Systems Manager or instance restart..."
    
    # Check if instance is running
    INSTANCE_STATE=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --region $AWS_REGION \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text)
    
    if [ "$INSTANCE_STATE" != "running" ]; then
        print_status "Starting instance..."
        aws ec2 start-instances --instance-ids $INSTANCE_ID --region $AWS_REGION
        aws ec2 wait instance-running --instance-ids $INSTANCE_ID --region $AWS_REGION
    fi
    
    # Try using SSM to run deployment commands
    print_status "Attempting deployment via SSM..."
    
    COMMAND_ID=$(aws ssm send-command \
        --instance-ids $INSTANCE_ID \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["cd /home/ec2-user","git clone https://github.com/Roncool13/mlops-assign.git california-housing-api || (cd california-housing-api && git pull)","cd california-housing-api","docker-compose pull || true","docker-compose down || true","docker-compose up -d","sleep 30","curl -f http://localhost:5001/api/v1/health/ && echo \"✅ Deployment successful\" || echo \"❌ Deployment failed\""]' \
        --region $AWS_REGION \
        --query 'Command.CommandId' \
        --output text 2>/dev/null || echo "FAILED")
    
    if [ "$COMMAND_ID" != "FAILED" ]; then
        print_status "SSM command sent: $COMMAND_ID"
        print_status "Waiting for command completion..."
        
        # Wait for command to complete
        sleep $SSM_COMMAND_WAIT_TIME
        
        # Check command status
        COMMAND_STATUS=$(aws ssm get-command-invocation \
            --command-id $COMMAND_ID \
            --instance-id $INSTANCE_ID \
            --region $AWS_REGION \
            --query 'Status' \
            --output text 2>/dev/null || echo "Unknown")
        
        print_status "Command status: $COMMAND_STATUS"
        
        if [ "$COMMAND_STATUS" = "Success" ]; then
            print_success "Deployment completed via SSM"
        else
            print_warning "SSM deployment may have issues, checking API directly..."
        fi
    else
        print_warning "SSM command failed, using direct health check approach..."
    fi
    
    # Direct health check approach
    print_status "Checking API health directly..."
    local max_wait=${HEALTH_CHECK_TIMEOUT:-300}  # seconds; configurable via env var
    local wait_time=0
    
    while [ $wait_time -lt $max_wait ]; do
        sleep 15
        wait_time=$((wait_time + 15))

        if curl -f "http://$PUBLIC_IP:5001/api/v1/health/"; then
            print_success "Deployment completed successfully!"
            print_status "Services available:"
            print_status "  API: http://$PUBLIC_IP:5001"
            print_status "  Grafana: http://$PUBLIC_IP:3000 (admin/grafana123)"
            print_status "  Prometheus: http://$PUBLIC_IP:9090"
            return 0
        fi
        
        echo -ne "\r${BLUE}[INFO]${NC} Waiting for services... (${wait_time}s/${max_wait}s)"
    done
    
    print_error "Deployment verification timeout after $max_wait seconds"
    print_status "The deployment may still be in progress. Check the instance manually:"
    print_status "  Instance ID: $INSTANCE_ID"
    print_status "  Public IP: $PUBLIC_IP"
    return 1
}

# Function to deploy application to EC2
deploy_to_ec2() {
    if [ ! -f "aws-deployment.env" ]; then
        print_error "aws-deployment.env not found. Please run setup first."
        exit 1
    fi
    
    source aws-deployment.env
    
    print_status "Deploying application to EC2 instance: $INSTANCE_ID"
    
    # Determine SSH key path safely
    if [ -n "$HOME" ] && [ -d "$HOME" ]; then
        SSH_KEY_PATH="$HOME/.ssh/$KEY_NAME.pem"
    else
        SSH_KEY_PATH=~/.ssh/$KEY_NAME.pem
        print_warning "HOME environment variable not set, using tilde expansion"
    fi
    
    # Debug SSH key information
    print_status "SSH Key Debug Information:"
    echo "  Key Name: $KEY_NAME"
    echo "  Key Path: $SSH_KEY_PATH"
    echo "  Key exists: $([ -f "$SSH_KEY_PATH" ] && echo "Yes" || echo "No")"
    echo "  Instance IP: $PUBLIC_IP"
    
    if [ ! -f "$SSH_KEY_PATH" ]; then
        print_warning "SSH key not found at $SSH_KEY_PATH. This is normal in CI/CD environments."
        print_status "Using alternative deployment method..."
        deploy_via_user_data
        return 0
    fi
    
    # Check and fix SSH key permissions
    current_perms=$(ls -l "$SSH_KEY_PATH" | awk '{print $1}')
    echo "  Current permissions: $current_perms"
    
    if [ "$current_perms" != "-r--------" ]; then
        print_status "Fixing SSH key permissions..."
        chmod 400 "$SSH_KEY_PATH"
        echo "  New permissions: $(ls -l "$SSH_KEY_PATH" | awk '{print $1}')"
    fi
    
    # Check key file content
    key_size=$(wc -c < "$SSH_KEY_PATH" 2>/dev/null || echo "0")
    echo "  Key file size: $key_size bytes"
    
    if [ "$key_size" -lt 100 ]; then
        print_error "SSH key file appears to be empty or corrupted"
        print_status "Falling back to user data deployment..."
        deploy_via_user_data
        return 0
    fi
    
    # Verify key format
    if ! head -1 "$SSH_KEY_PATH" | grep -q "BEGIN.*PRIVATE KEY"; then
        print_error "SSH key file doesn't appear to be in correct format"
        print_status "First line of key: $(head -1 "$SSH_KEY_PATH")"
        print_status "Falling back to user data deployment..."
        deploy_via_user_data
        return 0
    fi
    
    # Verify key pair consistency between local and AWS
    print_status "Verifying key pair consistency..."
    if command -v ssh-keygen >/dev/null 2>&1; then
        LOCAL_KEY_FINGERPRINT=$(ssh-keygen -l -f "$SSH_KEY_PATH" 2>/dev/null | awk '{print $2}' || echo "unknown")
        AWS_KEY_FINGERPRINT=$(aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" --query 'KeyPairs[0].KeyFingerprint' --output text 2>/dev/null || echo "unknown")
        
        echo "  Local key fingerprint: $LOCAL_KEY_FINGERPRINT"
        echo "  AWS key fingerprint: $AWS_KEY_FINGERPRINT"
        echo "  Note: Different fingerprint formats are normal (private vs public key)"
    fi
    
    # Comprehensive network and security troubleshooting
    print_status "Performing network and security troubleshooting..."
    
    # Check if we can reach the instance on port 22
    echo "  Testing network connectivity to $PUBLIC_IP:22..."
    if timeout 5 bash -c "</dev/tcp/$PUBLIC_IP/22" >/dev/null 2>&1; then
        echo "  ✅ Port 22 is reachable"
    else
        print_error "❌ Port 22 is NOT reachable - this is likely a security group issue"
        print_error "Please check that your security group allows SSH (port 22) from your current IP"
        
        # Get current public IP
        CURRENT_IP=$(curl -s http://checkip.amazonaws.com/ || curl -s http://ipinfo.io/ip || echo "unknown")
        echo "  Your current public IP: $CURRENT_IP"
        
        # Check security group rules
        print_status "Checking security group SSH rules..."
        aws ec2 describe-security-groups \
            --group-names "$SECURITY_GROUP" \
            --region "$AWS_REGION" \
            --query 'SecurityGroups[0].IpPermissions[?FromPort==`22`]' \
            --output table || echo "  Could not retrieve security group rules"
        
        print_error "Network connectivity failed. Please:"
        print_error "  1. Check security group allows SSH from your IP ($CURRENT_IP)"
        print_error "  2. Verify instance has a public IP: $PUBLIC_IP"
        print_error "  3. Check if AWS region firewall rules block SSH"
        
        print_status "Attempting alternative deployment via SSM..."
        deploy_via_user_data
        return 0
    fi
    
    # Verify the instance actually has our key pair assigned
    print_status "Verifying instance key pair assignment..."
    INSTANCE_KEY=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --region "$AWS_REGION" \
        --query 'Reservations[0].Instances[0].KeyName' \
        --output text 2>/dev/null || echo "unknown")
    
    echo "  Instance key pair: $INSTANCE_KEY"
    echo "  Expected key pair: $KEY_NAME"
    
    if [ "$INSTANCE_KEY" != "$KEY_NAME" ]; then
        print_error "❌ Key pair mismatch!"
        print_error "Instance was launched with key '$INSTANCE_KEY' but we have '$KEY_NAME'"
        print_error "This will definitely cause SSH authentication failures"
        
        print_status "Attempting alternative deployment via SSM..."
        deploy_via_user_data
        return 0
    else
        echo "  ✅ Key pair assignment matches"
    fi
    
    # Check if instance is in the right security group
    print_status "Verifying instance security groups..."
    INSTANCE_SG=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --region "$AWS_REGION" \
        --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupName' \
        --output text 2>/dev/null || echo "unknown")
    
    echo "  Instance security group: $INSTANCE_SG"
    echo "  Expected security group: $SECURITY_GROUP"
    
    if [ "$INSTANCE_SG" != "$SECURITY_GROUP" ]; then
        print_warning "⚠️  Security group mismatch!"
        print_warning "Instance is in '$INSTANCE_SG' but we expected '$SECURITY_GROUP'"
    else
        echo "  ✅ Security group assignment matches"
    fi
    
    # Wait for instance to be fully ready
    print_status "Ensuring instance is fully initialized..."
    
    # Wait for instance to be running first
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" 2>/dev/null || {
        print_warning "Instance-running wait timeout, but continuing..."
    }
    
    # Wait for system status checks
    print_status "Waiting for system status checks to pass..."
    timeout 300 aws ec2 wait system-status-ok --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" 2>/dev/null || {
        print_warning "System status check timeout (this is often normal), continuing with SSH attempts..."
    }
    
        # Wait for SSH service to be ready with enhanced error handling
    print_status "Testing SSH connectivity to ec2-user@$PUBLIC_IP..."
    local max_attempts=10  # Reduced attempts since we have better diagnostics now
    local attempt=1
    local ssh_success=false
    
    while [ $attempt -le $max_attempts ]; do
        print_status "SSH attempt $attempt/$max_attempts..."
        
        # Test SSH connection with detailed error output for first few attempts
        ssh_result=""
        if [ $attempt -le 3 ]; then
            print_status "Running verbose SSH attempt for detailed diagnostics..."
            ssh_result=$(ssh -i "$SSH_KEY_PATH" \
                -o ConnectTimeout=10 \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o PasswordAuthentication=no \
                -o PubkeyAuthentication=yes \
                -o LogLevel=DEBUG1 \
                ec2-user@$PUBLIC_IP "echo 'SSH_CONNECTION_SUCCESS'" 2>&1)
            
            if echo "$ssh_result" | grep -q "SSH_CONNECTION_SUCCESS"; then
                print_success "SSH connection established!"
                ssh_success=true
                break
            else
                print_warning "SSH attempt $attempt failed. Key diagnostic info:"
                
                # Extract useful debugging information
                if echo "$ssh_result" | grep -q "Connection refused"; then
                    echo "  ❌ Connection refused - SSH service may not be running"
                elif echo "$ssh_result" | grep -q "Connection timed out"; then
                    echo "  ❌ Connection timed out - network/firewall issue"
                elif echo "$ssh_result" | grep -q "Permission denied (publickey"; then
                    echo "  ❌ Public key authentication failed"
                    echo "     - Key may not be properly installed on instance"
                    echo "     - Key format may be incorrect"
                    echo "     - Instance may have been launched with different key"
                elif echo "$ssh_result" | grep -q "Host key verification failed"; then
                    echo "  ❌ Host key verification failed"
                else
                    echo "  ❌ Other SSH error occurred"
                fi
                
                # Show relevant debug lines
                echo "  Debug info:"
                echo "$ssh_result" | grep -E "(debug1|Permission denied|Connection|Offering public key)" | head -3 | sed 's/^/    /'
            fi
        else
            # Silent attempts for later tries to reduce noise
            if ssh -i "$SSH_KEY_PATH" \
                -o ConnectTimeout=10 \
                -o StrictHostKeyChecking=no \
                -o UserKnownHostsFile=/dev/null \
                -o PasswordAuthentication=no \
                -o LogLevel=ERROR \
                ec2-user@$PUBLIC_IP "echo 'SSH_CONNECTION_SUCCESS'" >/dev/null 2>&1; then
                print_success "SSH connection established!"
                ssh_success=true
                break
            fi
        fi
        
        if [ $attempt -eq 3 ]; then
            print_status "💡 Troubleshooting suggestions after 3 failed attempts:"
            echo "  1. Manual test: ssh -i $SSH_KEY_PATH -v ec2-user@$PUBLIC_IP"
            echo "  2. Check instance console logs in AWS Console for boot issues"
            echo "  3. Verify your security group allows SSH from your IP"
            echo "  4. Try connecting from AWS EC2 Instance Connect (browser-based SSH)"
            echo ""
            print_status "Continuing with remaining attempts..."
        fi
        
        echo -ne "
${BLUE}[INFO]${NC} Waiting for SSH... (${attempt}/${max_attempts}, waiting 20s)"
        sleep 20
        ((attempt++))
    done
    
    if [ "$ssh_success" = "false" ]; then
        print_error "SSH connection failed after $max_attempts attempts"
        print_error "Common troubleshooting steps:"
        print_error "  1. Check security group allows SSH (port 22) from your IP"
        print_error "  2. Verify instance is fully booted (may take 2-3 minutes)"
        print_error "  3. Confirm key pair was created properly in AWS"
        print_error "  4. Try connecting manually: ssh -i $SSH_KEY_PATH ec2-user@$PUBLIC_IP"
        
        print_status "Attempting alternative deployment via SSM/User Data..."
        deploy_via_user_data
        return 0
    fi
    
    # Test basic SSH commands before full deployment
    print_status "Testing SSH command execution..."
    if ! ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ec2-user@$PUBLIC_IP "whoami && uname -a" >/dev/null 2>&1; then
        print_error "SSH command execution test failed"
        print_status "Falling back to user data deployment..."
        deploy_via_user_data
        return 0
    fi
    
    # Deploy application via SSH
    print_status "Deploying application via SSH..."
    if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ec2-user@$PUBLIC_IP << 'EOF'
set -e  # Exit on any error

echo "🚀 Starting deployment on EC2 instance..."

# Update system packages
echo "📦 Updating system packages..."
sudo yum update -y >/dev/null 2>&1

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    sudo yum install -y docker git >/dev/null 2>&1
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    echo "✅ Docker installed and started"
else
    echo "✅ Docker already installed"
    sudo service docker start  # Ensure it's running
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo "🔧 Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose >/dev/null 2>&1
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✅ Docker Compose installed"
else
    echo "✅ Docker Compose already installed"
fi

# Clone or update repository
echo "📥 Setting up application repository..."
cd /home/ec2-user

if [ -d "california-housing-api" ]; then
    echo "🔄 Updating existing repository..."
    cd california-housing-api
    git pull origin main >/dev/null 2>&1 || git pull >/dev/null 2>&1
else
    echo "📥 Cloning repository..."
    git clone https://github.com/Roncool13/mlops-assign.git california-housing-api >/dev/null 2>&1
    cd california-housing-api
fi

echo "✅ Repository ready"

# Ensure Docker is running and user has permissions
sudo service docker start
sleep 5

# Deploy application using Docker Compose
echo "🚀 Deploying application containers..."

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose down >/dev/null 2>&1 || true

# Pull latest images
echo "📥 Pulling latest container images..."
docker-compose pull >/dev/null 2>&1 || {
    echo "⚠️  Image pull failed, using local images"
}

# Start application
echo "🚀 Starting application containers..."
docker-compose up -d

# Wait for services to initialize
echo "⏳ Waiting for services to start (30 seconds)..."
sleep 30

# Health check
echo "🏥 Performing health check..."
for i in {1..6}; do
    if curl -f -s http://localhost:5001/api/v1/health/ >/dev/null 2>&1; then
        echo "✅ Application is healthy and running!"
        echo "🌐 API accessible at: http://localhost:5001"
        echo "📊 Services deployed successfully!"
        exit 0
    fi
    echo "⏳ Health check attempt $i/6..."
    sleep 10
done

echo "⚠️  Health check timeout - application may still be starting"
echo "📋 Container status:"
docker-compose ps

exit 1
EOF
    then
        print_success "Application deployed successfully via SSH!"
        print_status "🌐 Access your services:"
        print_status "  📊 API: http://$PUBLIC_IP:5001"
        print_status "  📈 Grafana: http://$PUBLIC_IP:3000 (admin/grafana123)"
        print_status "  🔍 Prometheus: http://$PUBLIC_IP:9090"
        
        # Final health check from outside
        print_status "Performing external health check..."
        sleep 10
        if curl -f -s "http://$PUBLIC_IP:5001/api/v1/health/" >/dev/null 2>&1; then
            print_success "✅ External health check passed!"
        else
            print_warning "⚠️  External health check failed - services may still be starting"
            print_status "Please wait a few minutes and check manually"
        fi
    else
        print_error "SSH deployment failed"
        print_status "Attempting fallback deployment via SSM/User Data..."
        deploy_via_user_data
    fi
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
        if [ -n "$HOME" ] && [ -d "$HOME" ]; then
            SSH_KEY_PATH="$HOME/.ssh/$KEY_NAME.pem"
        else
            SSH_KEY_PATH=~/.ssh/$KEY_NAME.pem
        fi
        
        if [ -f "$SSH_KEY_PATH" ]; then
            echo "  ssh -i $SSH_KEY_PATH ec2-user@$PUBLIC_IP"
        else
            echo "  SSH key not available locally (use AWS Console or SSM for access)"
        fi
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
    echo "  AWS_REGION          - AWS region (default: us-east-2)"
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
