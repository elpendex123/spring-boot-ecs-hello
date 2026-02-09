#!/bin/bash

set -euo pipefail

# Configuration
PROJECT_NAME="${1:-hello-app}"
ENVIRONMENT="${2:-dev}"
AWS_REGION="${3:-us-east-1}"

echo "========================================="
echo "AWS Services for: $PROJECT_NAME-$ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "========================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print section header
print_header() {
    echo -e "${YELLOW}>>> $1${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# ECS Cluster Status
print_header "ECS Cluster Status"
CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cluster"
if aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$AWS_REGION" &>/dev/null; then
    CLUSTER_STATUS=$(aws ecs describe-clusters --clusters "$CLUSTER_NAME" --region "$AWS_REGION" --query 'clusters[0].status' --output text)
    print_success "Cluster: $CLUSTER_NAME (Status: $CLUSTER_STATUS)"
else
    echo -e "${RED}✗ Cluster not found: $CLUSTER_NAME${NC}"
fi
echo ""

# ECS Service Status
print_header "ECS Service Status"
SERVICE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-service"
if aws ecs list-services --cluster "$CLUSTER_NAME" --region "$AWS_REGION" --query "serviceArns[?contains(@, '$SERVICE_NAME')]" --output text &>/dev/null; then
    SERVICE_DETAILS=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --region "$AWS_REGION" --query 'services[0]')
    RUNNING_COUNT=$(echo "$SERVICE_DETAILS" | jq '.runningCount' 2>/dev/null || echo "0")
    DESIRED_COUNT=$(echo "$SERVICE_DETAILS" | jq '.desiredCount' 2>/dev/null || echo "0")
    SERVICE_STATUS=$(echo "$SERVICE_DETAILS" | jq '.status' -r 2>/dev/null || echo "UNKNOWN")
    print_success "Service: $SERVICE_NAME"
    echo "  Status: $SERVICE_STATUS"
    echo "  Running Tasks: $RUNNING_COUNT / $DESIRED_COUNT"
else
    echo -e "${RED}✗ Service not found: $SERVICE_NAME${NC}"
fi
echo ""

# ECS Tasks
print_header "ECS Tasks"
TASK_ARNS=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --region "$AWS_REGION" --query 'taskArns' --output text 2>/dev/null || echo "")
if [ -n "$TASK_ARNS" ]; then
    TASK_COUNT=$(echo "$TASK_ARNS" | wc -w)
    print_success "Found $TASK_COUNT task(s)"
    for TASK_ARN in $TASK_ARNS; do
        TASK_ID=$(echo "$TASK_ARN" | awk -F'/' '{print $NF}')
        TASK_STATUS=$(aws ecs describe-tasks --cluster "$CLUSTER_NAME" --tasks "$TASK_ARN" --region "$AWS_REGION" --query 'tasks[0].lastStatus' --output text 2>/dev/null || echo "UNKNOWN")
        echo "  - Task: $TASK_ID (Status: $TASK_STATUS)"
    done
else
    echo "  No tasks running"
fi
echo ""

# ALB Status
print_header "Application Load Balancer"
ALB_NAME="${PROJECT_NAME}-${ENVIRONMENT}-alb"
ALB_ARN=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query "LoadBalancers[?LoadBalancerName=='$ALB_NAME'].LoadBalancerArn" --output text 2>/dev/null || echo "")
if [ -n "$ALB_ARN" ]; then
    ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --region "$AWS_REGION" --query 'LoadBalancers[0].DNSName' --output text)
    ALB_STATUS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --region "$AWS_REGION" --query 'LoadBalancers[0].State.Code' --output text)
    print_success "ALB: $ALB_NAME"
    echo "  DNS: $ALB_DNS"
    echo "  URL: http://$ALB_DNS"
    echo "  Status: $ALB_STATUS"
else
    echo -e "${RED}✗ ALB not found: $ALB_NAME${NC}"
fi
echo ""

# Target Group Health
print_header "Target Group Health"
TG_NAME="${PROJECT_NAME}-${ENVIRONMENT}-tg"
TG_ARN=$(aws elbv2 describe-target-groups --region "$AWS_REGION" --query "TargetGroups[?TargetGroupName=='$TG_NAME'].TargetGroupArn" --output text 2>/dev/null || echo "")
if [ -n "$TG_ARN" ]; then
    HEALTH_STATUS=$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --region "$AWS_REGION" --query 'TargetHealthDescriptions' 2>/dev/null || echo "[]")
    TARGET_COUNT=$(echo "$HEALTH_STATUS" | jq 'length')
    print_success "Target Group: $TG_NAME ($TARGET_COUNT targets)"
    echo "$HEALTH_STATUS" | jq -r '.[] | "  - \(.Target.Id): \(.TargetHealth.State)"' 2>/dev/null || echo "  No targets"
else
    echo -e "${RED}✗ Target Group not found: $TG_NAME${NC}"
fi
echo ""

# ECR Repository
print_header "ECR Repository"
ECR_REPO="${PROJECT_NAME}-${ENVIRONMENT}"
ECR_URL=$(aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$AWS_REGION" --query 'repositories[0].repositoryUri' --output text 2>/dev/null || echo "")
if [ -n "$ECR_URL" ]; then
    print_success "Repository: $ECR_URL"
    IMAGE_COUNT=$(aws ecr list-images --repository-name "$ECR_REPO" --region "$AWS_REGION" --query 'length(imageIds)' --output text 2>/dev/null || echo "0")
    echo "  Images: $IMAGE_COUNT"
    aws ecr list-images --repository-name "$ECR_REPO" --region "$AWS_REGION" --query 'imageIds[*].imageTag' --output text 2>/dev/null | tr '\t' '\n' | sed 's/^/    - /' || echo "    No images"
else
    echo -e "${RED}✗ ECR Repository not found: $ECR_REPO${NC}"
fi
echo ""

# VPC and Security Groups
print_header "VPC and Network"
VPC_ID=$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENVIRONMENT}-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null || echo "")
if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    print_success "VPC: $VPC_ID"
    SUBNET_COUNT=$(aws ec2 describe-subnets --region "$AWS_REGION" --filters "Name=vpc-id,Values=$VPC_ID" --query 'length(Subnets)' --output text 2>/dev/null || echo "0")
    echo "  Subnets: $SUBNET_COUNT"
fi
echo ""

# CloudWatch Logs
print_header "CloudWatch Logs"
LOG_GROUP="/ecs/${PROJECT_NAME}-${ENVIRONMENT}"
LOG_STREAMS=$(aws logs describe-log-streams --log-group-name "$LOG_GROUP" --region "$AWS_REGION" --query 'logStreams' --output text 2>/dev/null || echo "")
if [ -n "$LOG_STREAMS" ]; then
    STREAM_COUNT=$(aws logs describe-log-streams --log-group-name "$LOG_GROUP" --region "$AWS_REGION" --query 'length(logStreams)' --output text 2>/dev/null || echo "0")
    print_success "Log Group: $LOG_GROUP ($STREAM_COUNT streams)"
else
    echo -e "${RED}✗ Log Group not found: $LOG_GROUP${NC}"
fi
echo ""

# EC2 Instances
print_header "EC2 Instances (ECS Cluster)"
INSTANCE_COUNT=$(aws ec2 describe-instances --region "$AWS_REGION" --filters "Name=tag:AmazonECSManaged,Values=true" "Name=instance-state-name,Values=running" --query 'length(Reservations[].Instances[])' --output text 2>/dev/null || echo "0")
if [ "$INSTANCE_COUNT" -gt 0 ]; then
    print_success "Running Instances: $INSTANCE_COUNT"
    aws ec2 describe-instances --region "$AWS_REGION" --filters "Name=tag:AmazonECSManaged,Values=true" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,InstanceType]' --output text | sed 's/^/    - Instance: /' || echo "    No instances"
else
    echo "  No running instances"
fi
echo ""

# IAM Roles
print_header "IAM Roles"
EXEC_ROLE="${PROJECT_NAME}-${ENVIRONMENT}-ecs-task-execution-role"
INST_ROLE="${PROJECT_NAME}-${ENVIRONMENT}-ecs-instance-role"
if aws iam get-role --role-name "$EXEC_ROLE" &>/dev/null; then
    print_success "Task Execution Role: $EXEC_ROLE"
fi
if aws iam get-role --role-name "$INST_ROLE" &>/dev/null; then
    print_success "Instance Role: $INST_ROLE"
fi
echo ""

echo "========================================="
echo "Report Complete"
echo "========================================="
