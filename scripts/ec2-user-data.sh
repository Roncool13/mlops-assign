#!/bin/bash

# EC2 User Data Script for MLOps Setup
# This script runs when the EC2 instance first starts

set -e

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "Starting MLOps EC2 setup..."

# Update system
yum update -y

# Install essential packages
yum install -y docker git curl wget unzip

# Start and enable Docker
service docker start
chkconfig docker on
usermod -a -G docker ec2-user

# Install Docker Compose
DOCKER_COMPOSE_VERSION="2.21.0"
curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install AWS CLI v2
cd /tmp
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Install SSM Agent (usually pre-installed on Amazon Linux 2)
yum install -y amazon-ssm-agent
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# Create application directory
mkdir -p /opt/mlops
chown ec2-user:ec2-user /opt/mlops

# Create systemd service for auto-start
cat > /etc/systemd/system/mlops-api.service << 'EOF'
[Unit]
Description=MLOps California Housing API
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ec2-user/california-housing-api
ExecStartPre=/usr/local/bin/docker-compose down
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=ec2-user
Group=ec2-user

[Install]
WantedBy=multi-user.target
EOF

# Enable the service (but don't start it yet - wait for deployment)
systemctl enable mlops-api.service

# Install CloudWatch agent for monitoring
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Configure CloudWatch agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "metrics": {
        "namespace": "MLOps/CaliforniaHousing",
        "metrics_collected": {
            "cpu": {
                "measurement": [
                    "cpu_usage_idle",
                    "cpu_usage_iowait",
                    "cpu_usage_user",
                    "cpu_usage_system"
                ],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": [
                    "used_percent"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "diskio": {
                "measurement": [
                    "io_time"
                ],
                "metrics_collection_interval": 60,
                "resources": [
                    "*"
                ]
            },
            "mem": {
                "measurement": [
                    "mem_used_percent"
                ],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/user-data.log",
                        "log_group_name": "/mlops/ec2/user-data",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/home/ec2-user/california-housing-api/logs/*.log",
                        "log_group_name": "/mlops/application/logs",
                        "log_stream_name": "{instance_id}/{hostname}"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config \
    -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
    -s

# Create health check script
cat > /home/ec2-user/health-check.sh << 'EOF'
#!/bin/bash
# Simple health check script for the MLOps API

API_URL="http://localhost:5001/api/v1/health/"
HEALTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $API_URL 2>/dev/null || echo "000")

if [ "$HEALTH_STATUS" = "200" ]; then
    echo "✅ API Health Check: HEALTHY"
    exit 0
else
    echo "❌ API Health Check: UNHEALTHY (Status: $HEALTH_STATUS)"
    exit 1
fi
EOF

chmod +x /home/ec2-user/health-check.sh
chown ec2-user:ec2-user /home/ec2-user/health-check.sh

# Set up cron job for health checks
echo "*/5 * * * * /home/ec2-user/health-check.sh >> /var/log/health-check.log 2>&1" | crontab -u ec2-user -

# Create environment file for easy access
cat > /home/ec2-user/.env << 'EOF'
# MLOps Environment Variables
export MLOPS_ENV=production
export API_HOST=0.0.0.0
export API_PORT=5001
export PROMETHEUS_PORT=9090
export GRAFANA_PORT=3000
export NODE_EXPORTER_PORT=9100
EOF

# Source environment in .bashrc
echo "source ~/.env" >> /home/ec2-user/.bashrc

# Set ownership
chown -R ec2-user:ec2-user /home/ec2-user/

# Signal completion (if using CloudFormation)
# /opt/aws/bin/cfn-signal -e $? --stack ${AWS::StackName} --resource Instance --region ${AWS::Region} 2>/dev/null || true

echo "✅ MLOps EC2 setup completed successfully"
echo "Instance is ready for deployment"

# Final status
echo "=== Setup Summary ==="
echo "Docker: $(docker --version)"
echo "Docker Compose: $(docker-compose --version)"
echo "AWS CLI: $(aws --version)"
echo "SSM Agent: $(systemctl is-active amazon-ssm-agent)"
echo "CloudWatch Agent: $(systemctl is-active amazon-cloudwatch-agent)"
echo "===================="
