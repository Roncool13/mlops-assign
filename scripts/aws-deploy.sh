#!/bin/bash

# AWS Deployment Script for MLOps Pipeline (EIC-first)
# This version uses EC2 Instance Connect with an ephemeral SSH key per run.
# Fallback to SSM/user-data remains available.

set -euo pipefail

# -----------------------------
# Configuration
# -----------------------------
AWS_REGION=${AWS_REGION:-us-east-2}
EC2_INSTANCE_TYPE=${EC2_INSTANCE_TYPE:-t3.medium}
# When using EIC, a KeyPair is not required. Keep a name if you still want classic keys sometimes.
KEY_NAME=${AWS_KEY_NAME:-mlops-keypair}
SECURITY_GROUP=${AWS_SECURITY_GROUP:-mlops-sg}
INSTANCE_NAME=${INSTANCE_NAME:-mlops-california-housing}
USE_EIC=${USE_EIC:-true}                 # << EIC enabled by default
EIC_OS_USER=${EIC_OS_USER:-ec2-user}     # Amazon Linux 2: ec2-user; Ubuntu: ubuntu
EIC_KEY_TTL_SECONDS=${EIC_KEY_TTL_SECONDS:-60} # EIC window to connect; connect immediately.
SSM_COMMAND_WAIT_TIME=${SSM_COMMAND_WAIT_TIME:-30}

# -----------------------------
# Colors & helpers
# -----------------------------
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
print_status()  { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# -----------------------------
# AWS setup check
# -----------------------------
check_aws_setup() {
  print_status "Checking AWS setup..."
  if ! command -v aws &>/dev/null; then
    print_error "AWS CLI not found. Please install AWS CLI first."
    exit 1
  fi
  if ! aws sts get-caller-identity --region "$AWS_REGION" >/dev/null; then
    print_error "AWS credentials not configured. Please run 'aws configure'"
    exit 1
  fi
  print_success "AWS CLI and credentials verified"
}

# -----------------------------
# Security group
# -----------------------------
create_security_group() {
  print_status "Creating security group: $SECURITY_GROUP"
  if aws ec2 describe-security-groups --group-names "$SECURITY_GROUP" --region "$AWS_REGION" >/dev/null 2>&1; then
    print_warning "Security group $SECURITY_GROUP already exists"
    return 0
  fi
  SECURITY_GROUP_ID=$(aws ec2 create-security-group \
      --group-name "$SECURITY_GROUP" \
      --description "MLOps California Housing API Security Group" \
      --region "$AWS_REGION" \
      --query 'GroupId' \
      --output text)
  # SSH
  aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 22   --cidr 0.0.0.0/0 --region "$AWS_REGION"
  # API
  aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 5001 --cidr 0.0.0.0/0 --region "$AWS_REGION"
  # Grafana
  aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 3000 --cidr 0.0.0.0/0 --region "$AWS_REGION"
  # Prometheus
  aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 9090 --cidr 0.0.0.0/0 --region "$AWS_REGION"
  print_success "Security group created: $SECURITY_GROUP_ID"
}

# -----------------------------
# Key pair (NO-OP when USE_EIC=true)
# -----------------------------
create_key_pair() {
  if [[ "$USE_EIC" == "true" ]]; then
    print_status "USE_EIC=true → Skipping AWS key pair creation (not required)."
    return 0
  fi

  print_status "Ensuring key pair exists for classic SSH: $KEY_NAME"
  SSH_DIR="${HOME:-~}/.ssh"
  SSH_KEY_PATH="$SSH_DIR/$KEY_NAME.pem"
  mkdir -p "$SSH_DIR"; chmod 700 "$SSH_DIR"

  if aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
    print_warning "Key pair $KEY_NAME exists in AWS."
    if [[ -f "$SSH_KEY_PATH" ]]; then
      print_status "Private key already exists locally at $SSH_KEY_PATH"
      chmod 400 "$SSH_KEY_PATH" || true
      return 0
    fi
    print_error "Local private key missing, but key exists in AWS. Cannot recover private material."
    print_error "Either switch to USE_EIC=true or rotate key and install pubkey via SSM."
    exit 1
  else
    print_status "Creating new AWS key pair: $KEY_NAME"
    aws ec2 create-key-pair \
      --key-name "$KEY_NAME" \
      --region "$AWS_REGION" \
      --query 'KeyMaterial' --output text > "$SSH_KEY_PATH"
    chmod 400 "$SSH_KEY_PATH"
    print_success "Key material saved to $SSH_KEY_PATH"
  fi
}

# -----------------------------
# Instance create / get
# -----------------------------
setup_ec2_instance() {
  print_status "Setting up EC2 instance..."

  EXISTING_INSTANCE=$(aws ec2 describe-instances \
      --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running,stopped" \
      --region "$AWS_REGION" \
      --query 'Reservations[0].Instances[0].InstanceId' \
      --output text 2>/dev/null || echo "None")

  if [[ "$EXISTING_INSTANCE" != "None" && "$EXISTING_INSTANCE" != "null" ]]; then
    print_warning "Instance $INSTANCE_NAME already exists: $EXISTING_INSTANCE"
    INSTANCE_ID="$EXISTING_INSTANCE"
    INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" \
                      --query 'Reservations[0].Instances[0].State.Name' --output text)
    if [[ "$INSTANCE_STATE" == "stopped" ]]; then
      print_status "Starting stopped instance..."
      aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" >/dev/null
      aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
    fi
  else
    print_status "Creating new EC2 instance..."
    AMI_ID=$(aws ec2 describe-images \
      --owners amazon \
      --filters "Name=name,Values=amzn2-ami-hvm-*" "Name=architecture,Values=x86_64" "Name=state,Values=available" \
      --region "$AWS_REGION" \
      --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
      --output text)
    print_status "Using AMI: $AMI_ID"

    RUN_ARGS=(
      --image-id "$AMI_ID"
      --count 1
      --instance-type "$EC2_INSTANCE_TYPE"
      --security-groups "$SECURITY_GROUP"
      --user-data file://scripts/ec2-user-data.sh
      --region "$AWS_REGION"
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]"
      --query 'Instances[0].InstanceId'
      --output text
    )

    # Only include --key-name if not using EIC-only
    if [[ "$USE_EIC" != "true" ]]; then
      RUN_ARGS+=( --key-name "$KEY_NAME" )
    fi

    INSTANCE_ID=$(aws ec2 run-instances "${RUN_ARGS[@]}")
    print_success "Instance created: $INSTANCE_ID"
    print_status "Waiting for instance to be running..."
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
  fi

  PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" \
              --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
  print_success "Instance is running at: $PUBLIC_IP"

  cat > aws-deployment.env << EOF
INSTANCE_ID=$INSTANCE_ID
PUBLIC_IP=$PUBLIC_IP
AWS_REGION=$AWS_REGION
KEY_NAME=$KEY_NAME
SECURITY_GROUP=$SECURITY_GROUP
USE_EIC=$USE_EIC
EIC_OS_USER=$EIC_OS_USER
EOF
  print_success "Deployment info saved to aws-deployment.env"
}

# -----------------------------
# EIC helpers
# -----------------------------
eic_generate_ephemeral_key() {
  EIC_KEY_DIR="${RUNNER_TEMP:-/tmp}/eic-ssh"
  mkdir -p "$EIC_KEY_DIR"
  EIC_PRIV="$EIC_KEY_DIR/id_ed25519"
  EIC_PUB="$EIC_KEY_DIR/id_ed25519.pub"

  if [[ ! -f "$EIC_PRIV" ]]; then
    print_status "Generating ephemeral SSH key (ed25519)..."
    ssh-keygen -t ed25519 -N "" -f "$EIC_PRIV" >/dev/null
  fi
  export EIC_PRIV EIC_PUB EIC_KEY_DIR
}

eic_send_pubkey() {
  # Requires INSTANCE_ID, AWS_REGION, EIC_OS_USER, EIC_PUB
  AZ=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" \
        --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' --output text)
  print_status "Pushing EIC public key for user '$EIC_OS_USER' in AZ '$AZ'..."
  aws ec2-instance-connect send-ssh-public-key \
    --instance-id "$INSTANCE_ID" \
    --availability-zone "$AZ" \
    --instance-os-user "$EIC_OS_USER" \
    --ssh-public-key "file://$EIC_PUB" \
    --region "$AWS_REGION" >/dev/null
  print_success "EIC public key injected (connect promptly; TTL is short)"
}

eic_ssh_opts() {
  export SSH_OPTS="-i $EIC_PRIV -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
}

# -----------------------------
# SSM fallback (kept as-is)
# -----------------------------
deploy_via_user_data() {
  print_status "Deploying via AWS Systems Manager or instance restart..."
  INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" \
                    --query 'Reservations[0].Instances[0].State.Name' --output text)
  if [[ "$INSTANCE_STATE" != "running" ]]; then
    print_status "Starting instance..."
    aws ec2 start-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" >/dev/null
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"
  fi

  print_status "Attempting deployment via SSM..."
  COMMAND_ID=$(aws ssm send-command \
      --instance-ids "$INSTANCE_ID" \
      --document-name "AWS-RunShellScript" \
      --parameters 'commands=["cd /home/ec2-user","git clone https://github.com/Roncool13/mlops-assign.git california-housing-api || (cd california-housing-api && git pull)","cd california-housing-api","docker-compose pull || true","docker-compose down || true","docker-compose up -d","sleep 30","curl -f http://localhost:5001/api/v1/health/ && echo \"✅ Deployment successful\" || echo \"❌ Deployment failed\""]' \
      --region "$AWS_REGION" \
      --query 'Command.CommandId' \
      --output text 2>/dev/null || echo "FAILED")

  if [[ "$COMMAND_ID" != "FAILED" ]]; then
    print_status "SSM command sent: $COMMAND_ID"
    print_status "Waiting for command completion..."
    sleep "$SSM_COMMAND_WAIT_TIME"
    COMMAND_STATUS=$(aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$INSTANCE_ID" \
        --region "$AWS_REGION" \
        --query 'Status' --output text 2>/dev/null || echo "Unknown")
    print_status "Command status: $COMMAND_STATUS"
    if [[ "$COMMAND_STATUS" == "Success" ]]; then
      print_success "Deployment completed via SSM"
    else
      print_warning "SSM deployment may have issues, checking API directly..."
    fi
  else
    print_warning "SSM command failed, using direct health check..."
  fi

  print_status "Checking API health directly..."
  local max_wait=${HEALTH_CHECK_TIMEOUT:-300}
  local wait_time=0
  while [[ $wait_time -lt $max_wait ]]; do
    sleep 15; wait_time=$((wait_time + 15))
    if curl -f "http://$PUBLIC_IP:5001/api/v1/health/" >/dev/null 2>&1; then
      print_success "Deployment completed successfully!"
      print_status "  API:       http://$PUBLIC_IP:5001"
      print_status "  Grafana:   http://$PUBLIC_IP:3000 (admin/grafana123)"
      print_status "  Prometheus:http://$PUBLIC_IP:9090"
      return 0
    fi
    echo -ne "\r${BLUE}[INFO]${NC} Waiting for services... (${wait_time}s/${max_wait}s)"
  done
  print_error "Deployment verification timeout after $max_wait seconds"
  return 1
}

# -----------------------------
# Deploy via EIC (SSH)
# -----------------------------
deploy_to_ec2() {
  if [[ ! -f "aws-deployment.env" ]]; then
    print_error "aws-deployment.env not found. Please run setup first."
    exit 1
  fi
  # shellcheck disable=SC1091
  source aws-deployment.env

  print_status "Deploying application to EC2 instance: $INSTANCE_ID"
  print_status "Connection method: $([[ "$USE_EIC" == "true" ]] && echo 'EIC (ephemeral key)' || echo 'Classic SSH key'))"

  # Ensure instance is up and has IP
  aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" 2>/dev/null || true
  PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" \
              --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
  print_status "Instance public IP: $PUBLIC_IP"

  # If not using EIC, fall back to legacy key behavior (kept for completeness)
  if [[ "$USE_EIC" != "true" ]]; then
    SSH_KEY_PATH="${HOME:-~}/.ssh/$KEY_NAME.pem"
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
      print_warning "Legacy SSH key not found at $SSH_KEY_PATH; falling back to SSM."
      deploy_via_user_data
      return 0
    fi
    chmod 400 "$SSH_KEY_PATH" || true
    SSH_OPTS="-i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
  else
    # EIC path
    eic_generate_ephemeral_key
    eic_send_pubkey
    eic_ssh_opts
    # Quick reachability test on 22
    print_status "Testing TCP reachability to $PUBLIC_IP:22..."
    if ! timeout 5 bash -c "</dev/tcp/$PUBLIC_IP/22" >/dev/null 2>&1; then
      print_error "Port 22 is not reachable. Check security group/NACL."
      print_status "Falling back to SSM..."
      deploy_via_user_data
      return 0
    fi
    # Quick SSH probe
    print_status "Probing SSH via EIC..."
    if ! ssh $SSH_OPTS "$EIC_OS_USER@$PUBLIC_IP" "echo EIC_OK"; then
      print_warning "EIC SSH probe failed. Retrying once after re-injecting key..."
      eic_send_pubkey
      if ! ssh $SSH_OPTS "$EIC_OS_USER@$PUBLIC_IP" "echo EIC_OK"; then
        print_error "EIC SSH still failing. Falling back to SSM..."
        deploy_via_user_data
        return 0
      fi
    fi
    print_success "EIC SSH connection established."
  fi

  # Basic sanity commands
  print_status "Testing SSH command execution..."
  if ! ssh $SSH_OPTS "$EIC_OS_USER@$PUBLIC_IP" "whoami && uname -a" >/dev/null 2>&1; then
    print_error "SSH command execution test failed; falling back to SSM..."
    deploy_via_user_data
    return 0
  fi

  # Deploy (same as your original SSH block)
  print_status "Deploying application via SSH..."
  if ssh $SSH_OPTS "$EIC_OS_USER@$PUBLIC_IP" << 'EOF'
set -e

echo "🚀 Starting deployment on EC2 instance..."

# Update system packages
echo "📦 Updating system packages..."
sudo yum update -y >/dev/null 2>&1 || true

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    sudo yum install -y docker git >/dev/null 2>&1 || sudo dnf install -y docker git >/dev/null 2>&1 || true
    sudo service docker start || sudo systemctl start docker
    sudo usermod -a -G docker ec2-user || true
    echo "✅ Docker installed and started"
else
    echo "✅ Docker already installed"
    sudo service docker start || sudo systemctl start docker
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
sudo service docker start || sudo systemctl start docker
sleep 5

# Deploy application using Docker Compose
echo "🚀 Deploying application containers..."
docker-compose down >/dev/null 2>&1 || true
docker-compose pull  >/dev/null 2>&1 || { echo "⚠️  Image pull failed, using local images"; }
docker-compose up -d

echo "⏳ Waiting for services to start (30 seconds)..."
sleep 30

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
docker-compose ps || true
exit 1
EOF
  then
    print_success "Application deployed successfully via SSH!"
    print_status "  API:        http://$PUBLIC_IP:5001"
    print_status "  Grafana:    http://$PUBLIC_IP:3000 (admin/grafana123)"
    print_status "  Prometheus: http://$PUBLIC_IP:9090"

    print_status "Performing external health check..."
    sleep 10
    if curl -f -s "http://$PUBLIC_IP:5001/api/v1/health/" >/dev/null 2>&1; then
      print_success "✅ External health check passed!"
    else
      print_warning "⚠️  External health check failed - services may still be starting"
    fi
  else
    print_error "SSH deployment failed. Falling back to SSM/User Data..."
    deploy_via_user_data
  fi
}

# -----------------------------
# Status / Stop / Terminate / Help
# -----------------------------
show_status() {
  if [[ ! -f "aws-deployment.env" ]]; then
    print_warning "No deployment found. Run setup first."
    return 1
  fi
  # shellcheck disable=SC1091
  source aws-deployment.env
  print_status "AWS Deployment Status"
  echo ""
  echo "🌍 Region: $AWS_REGION"
  echo "🖥️  Instance ID: $INSTANCE_ID"
  echo "🌐 Public IP: $PUBLIC_IP"
  echo "🔑 Key Name (legacy): $KEY_NAME"
  echo "🛡️  Security Group: $SECURITY_GROUP"
  echo "🔌 EIC Enabled: $USE_EIC (user: $EIC_OS_USER)"
  echo ""
  INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" \
                    --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "unknown")
  echo "📊 Instance State: $INSTANCE_STATE"
  if [[ "$INSTANCE_STATE" == "running" ]]; then
    echo ""
    echo "🌐 Service URLs:"
    echo "  API:        http://$PUBLIC_IP:5001"
    echo "  Grafana:    http://$PUBLIC_IP:3000"
    echo "  Prometheus: http://$PUBLIC_IP:9090"
    echo ""
    echo "🔗 SSH Access:"
    if [[ "$USE_EIC" == "true" ]]; then
      echo "  # One-time EIC from any machine with AWS creds:"
      echo "  aws ec2-instance-connect send-ssh-public-key --instance-id $INSTANCE_ID --availability-zone \$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --region $AWS_REGION --query 'Reservations[0].Instances[0].Placement.AvailabilityZone' --output text) --instance-os-user $EIC_OS_USER --ssh-public-key file://~/.ssh/id_ed25519.pub --region $AWS_REGION"
      echo "  ssh -i ~/.ssh/id_ed25519 $EIC_OS_USER@$PUBLIC_IP"
    else
      SSH_KEY_PATH="${HOME:-~}/.ssh/$KEY_NAME.pem"
      if [[ -f "$SSH_KEY_PATH" ]]; then
        echo "  ssh -i $SSH_KEY_PATH $EIC_OS_USER@$PUBLIC_IP"
      else
        echo "  Legacy key not available locally"
      }
    fi
  fi
}

stop_instance() {
  if [[ ! -f "aws-deployment.env" ]]; then
    print_error "aws-deployment.env not found. No instance to stop."
    exit 1
  fi
  # shellcheck disable=SC1091
  source aws-deployment.env
  print_status "Stopping EC2 instance: $INSTANCE_ID"
  aws ec2 stop-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" >/dev/null
  print_success "Instance stop initiated"
}

terminate_instance() {
  if [[ ! -f "aws-deployment.env" ]]; then
    print_error "aws-deployment.env not found. No instance to terminate."
    exit 1
  fi
  # shellcheck disable=SC1091
  source aws-deployment.env
  print_warning "This will permanently delete the EC2 instance!"
  read -p "Are you sure? (y/N): " -n 1 -r; echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_status "Terminating EC2 instance: $INSTANCE_ID"
    aws ec2 terminate-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" >/dev/null
    rm -f aws-deployment.env
    print_success "Instance termination initiated and deployment info cleaned up"
  else
    print_status "Termination cancelled"
  fi
}

show_usage() {
  cat <<USAGE
Usage: $0 [COMMAND]

Commands:
  setup       - Create security group and EC2 instance (EIC by default)
  deploy      - Deploy application to existing EC2 instance (EIC-first)
  full        - Complete setup and deployment
  status      - Show current deployment status
  stop        - Stop the EC2 instance
  terminate   - Terminate the EC2 instance (permanent)
  help        - Show this help message

Environment Variables:
  AWS_REGION           - AWS region (default: us-east-2)
  EC2_INSTANCE_TYPE    - Instance type (default: t3.medium)
  AWS_KEY_NAME         - Key pair name (legacy) (default: mlops-keypair)
  AWS_SECURITY_GROUP   - Security group name (default: mlops-sg)
  INSTANCE_NAME        - Instance name tag (default: mlops-california-housing)
  USE_EIC              - true|false (default: true)
  EIC_OS_USER          - ec2-user|ubuntu|... (default: ec2-user)

Examples:
  USE_EIC=true  $0 full
  USE_EIC=true  $0 deploy
  USE_EIC=false $0 full   # uses classic key pair path (requires existing local private key)
USAGE
}

# -----------------------------
# Main
# -----------------------------
main() {
  local command=${1:-help}
  case "$command" in
    setup)
      check_aws_setup
      create_security_group
      create_key_pair
      setup_ec2_instance
      ;;
    deploy)
      check_aws_setup
      deploy_to_ec2
      ;;
    full)
      check_aws_setup
      create_security_group
      create_key_pair
      setup_ec2_instance
      sleep 60
      deploy_to_ec2
      ;;
    status)     show_status ;;
    stop)       check_aws_setup; stop_instance ;;
    terminate)  check_aws_setup; terminate_instance ;;
    help|-h|--help) show_usage ;;
    *) print_error "Unknown command: $command"; show_usage; exit 1 ;;
  esac
}

main "$@"