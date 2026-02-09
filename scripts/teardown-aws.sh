#!/bin/bash

set -euo pipefail

# Configuration
PROJECT_NAME="${1:-hello-app}"
ENVIRONMENT="${2:-dev}"
AWS_REGION="${3:-us-east-1}"

echo "========================================="
echo "AWS Infrastructure Teardown"
echo "Project: $PROJECT_NAME-$ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Confirmation
echo -e "${RED}WARNING: This will destroy all AWS resources for $PROJECT_NAME-$ENVIRONMENT${NC}"
echo "This includes:"
echo "  - ECS Cluster and Services"
echo "  - EC2 Instances"
echo "  - Application Load Balancer"
echo "  - VPC, Subnets, and Security Groups"
echo "  - IAM Roles"
echo "  - CloudWatch Logs"
echo ""
read -p "Type 'yes' to confirm teardown: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Teardown cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting teardown...${NC}"
echo ""

# Step 1: Stop ECS Service
echo "Step 1: Stopping ECS Service..."
CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cluster"
SERVICE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-service"

if aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --region "$AWS_REGION" &>/dev/null 2>&1; then
    echo "  Scaling service to 0 tasks..."
    aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "$SERVICE_NAME" \
        --desired-count 0 \
        --region "$AWS_REGION" \
        --output text > /dev/null 2>&1 || true

    echo "  Waiting for tasks to stop (this may take a few minutes)..."
    aws ecs wait services-stable \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --region "$AWS_REGION" 2>/dev/null || true

    echo -e "${GREEN}✓ ECS Service stopped${NC}"
else
    echo "  Service not found, skipping..."
fi
echo ""

# Step 2: Run Terraform Destroy
echo "Step 2: Destroying Terraform Infrastructure..."
TERRAFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"

if [ -d "$TERRAFORM_DIR" ]; then
    cd "$TERRAFORM_DIR"

    if [ -f "terraform.tfstate" ]; then
        echo "  Running terraform destroy..."
        terraform destroy -auto-approve -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -var="aws_region=$AWS_REGION" 2>&1 | tail -10

        echo -e "${GREEN}✓ Terraform destroy completed${NC}"
    else
        echo "  terraform.tfstate not found, skipping..."
    fi
else
    echo -e "${RED}✗ Terraform directory not found at $TERRAFORM_DIR${NC}"
fi
echo ""

# Step 3: Clean up orphaned resources
echo "Step 3: Checking for orphaned resources..."

# Check for orphaned security groups
ORPHANED_SG=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENVIRONMENT}-*" --query 'length(SecurityGroups)' --output text 2>/dev/null || echo "0")
if [ "$ORPHANED_SG" -gt 0 ]; then
    echo "  Found $ORPHANED_SG orphaned security groups"
fi

# Check for orphaned ECS resources
ORPHANED_TASKS=$(aws ecs list-tasks --cluster "$CLUSTER_NAME" --region "$AWS_REGION" --query 'length(taskArns)' --output text 2>/dev/null || echo "0")
if [ "$ORPHANED_TASKS" -gt 0 ]; then
    echo "  Found $ORPHANED_TASKS orphaned tasks"
fi

if [ "$ORPHANED_SG" -eq 0 ] && [ "$ORPHANED_TASKS" -eq 0 ]; then
    echo -e "${GREEN}✓ No significant orphaned resources detected${NC}"
fi
echo ""

# Step 4: Summary
echo "========================================="
echo -e "${GREEN}Teardown Complete${NC}"
echo "========================================="
echo ""
echo "Summary:"
echo "  - ECS Service: Scaled to 0 tasks"
echo "  - Infrastructure: Destroyed via Terraform"
echo ""
echo "You may still need to manually clean up:"
echo "  - ECR Images (docker images will persist)"
echo "  - CloudWatch Logs"
echo "  - Any AWS resources tagged outside Terraform"
echo ""
echo "To remove ECR images:"
echo "  aws ecr describe-images --repository-name $PROJECT_NAME-$ENVIRONMENT --region $AWS_REGION"
echo ""
