#!/bin/bash
#
# Complete AWS Resource Check - Lists ALL resources in every category
# Usage: ./check-aws-resources.sh [project_name] [environment] [aws_region]
#

set -euo pipefail

# Configuration
PROJECT_NAME="${1:-hello-app}"
ENVIRONMENT="${2:-dev}"
AWS_REGION="${3:-us-east-1}"
PROJECT_FULL="${PROJECT_NAME}-${ENVIRONMENT}"

echo "=========================================="
echo "AWS Resource Check"
echo "Project: $PROJECT_FULL"
echo "Region: $AWS_REGION"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

TOTAL_RESOURCES=0

# Function to check and report resources
check_resources() {
    local category=$1
    local command=$2
    local filter=${3:-""}

    echo -n "Checking $category... "

    if [ -z "$filter" ]; then
        count=$(eval "$command" 2>/dev/null | wc -w)
    else
        count=$(eval "$command" 2>/dev/null | grep -c "$filter" || echo "0")
    fi

    if [ "$count" -gt 0 ]; then
        echo -e "${RED}FOUND: $count${NC}"
        TOTAL_RESOURCES=$((TOTAL_RESOURCES + count))
        return 0
    else
        echo -e "${GREEN}0${NC}"
        return 1
    fi
}

# 1. ECS Task Definitions
echo ">>> ECS RESOURCES"
echo ""

if check_resources "ECS Task Definitions" "aws ecs list-task-definitions --region $AWS_REGION --family-prefix $PROJECT_FULL --query 'taskDefinitionArns' --output text" "$PROJECT_FULL"; then
    aws ecs list-task-definitions --region $AWS_REGION --family-prefix $PROJECT_FULL --query 'taskDefinitionArns' --output text | tr '\t' '\n' | sed 's/^/  ✗ /'
fi
echo ""

# 2. ECS Clusters
if check_resources "ECS Clusters" "aws ecs list-clusters --region $AWS_REGION --query 'clusterArns' --output text" "$PROJECT_FULL"; then
    aws ecs list-clusters --region $AWS_REGION --query 'clusterArns' --output text | tr '\t' '\n' | grep $PROJECT_FULL | sed 's/^/  ✗ /'
fi
echo ""

# 3. ECS Services
if check_resources "ECS Services" "aws ecs list-services --cluster $PROJECT_FULL-cluster --region $AWS_REGION --query 'serviceArns' --output text" "$PROJECT_FULL" 2>/dev/null || echo "0"; then
    aws ecs list-services --cluster $PROJECT_FULL-cluster --region $AWS_REGION --query 'serviceArns' --output text 2>/dev/null | tr '\t' '\n' | grep $PROJECT_FULL | sed 's/^/  ✗ /' || true
fi
echo ""

# 4. ECS Capacity Providers
if check_resources "ECS Capacity Providers" "aws ecs describe-capacity-providers --region $AWS_REGION --query 'capacityProviders[].name' --output text" "$PROJECT_FULL"; then
    aws ecs describe-capacity-providers --region $AWS_REGION --query 'capacityProviders[].name' --output text | tr '\t' '\n' | grep $PROJECT_FULL | sed 's/^/  ✗ /'
fi
echo ""

# 5. Load Balancers
echo ">>> LOAD BALANCING"
echo ""

if check_resources "Load Balancers" "aws elbv2 describe-load-balancers --region $AWS_REGION --query 'LoadBalancers[].LoadBalancerName' --output text" "$PROJECT_FULL"; then
    aws elbv2 describe-load-balancers --region $AWS_REGION --query 'LoadBalancers[].LoadBalancerName' --output text | tr '\t' '\n' | grep $PROJECT_FULL | sed 's/^/  ✗ /'
fi
echo ""

# 6. Target Groups
if check_resources "Target Groups" "aws elbv2 describe-target-groups --region $AWS_REGION --query 'TargetGroups[].TargetGroupName' --output text" "$PROJECT_FULL"; then
    aws elbv2 describe-target-groups --region $AWS_REGION --query 'TargetGroups[].TargetGroupName' --output text | tr '\t' '\n' | grep $PROJECT_FULL | sed 's/^/  ✗ /'
fi
echo ""

# 7. ECR Repositories
echo ">>> CONTAINER REGISTRY"
echo ""

if check_resources "ECR Repositories" "aws ecr describe-repositories --region $AWS_REGION --query 'repositories[].repositoryName' --output text" "$PROJECT_FULL"; then
    aws ecr describe-repositories --region $AWS_REGION --query 'repositories[].repositoryName' --output text | tr '\t' '\n' | grep $PROJECT_FULL | sed 's/^/  ✗ /'
fi
echo ""

# 8. IAM Roles
echo ">>> IAM RESOURCES"
echo ""

if check_resources "IAM Roles" "aws iam list-roles --query 'Roles[].RoleName' --output text" "$PROJECT_FULL"; then
    aws iam list-roles --query 'Roles[].RoleName' --output text | tr '\t' '\n' | grep $PROJECT_FULL | sed 's/^/  ✗ /'
fi
echo ""

# 9. IAM Instance Profiles
if check_resources "IAM Instance Profiles" "aws iam list-instance-profiles --query 'InstanceProfiles[].InstanceProfileName' --output text" "$PROJECT_FULL"; then
    aws iam list-instance-profiles --query 'InstanceProfiles[].InstanceProfileName' --output text | tr '\t' '\n' | grep $PROJECT_FULL | sed 's/^/  ✗ /'
fi
echo ""

# 10. CloudWatch Logs
echo ">>> MONITORING & LOGS"
echo ""

if check_resources "CloudWatch Log Groups" "aws logs describe-log-groups --region $AWS_REGION --query 'logGroups[].logGroupName' --output text" "$PROJECT_FULL"; then
    aws logs describe-log-groups --region $AWS_REGION --query 'logGroups[].logGroupName' --output text | tr '\t' '\n' | grep $PROJECT_FULL | sed 's/^/  ✗ /'
fi
echo ""

# 11. VPC Resources
echo ">>> NETWORKING"
echo ""

# VPCs
if check_resources "VPCs" "aws ec2 describe-vpcs --region $AWS_REGION --filters 'Name=tag:Name,Values=*$PROJECT_FULL*' --query 'Vpcs[].VpcId' --output text"; then
    aws ec2 describe-vpcs --region $AWS_REGION --filters "Name=tag:Name,Values=*$PROJECT_FULL*" --query 'Vpcs[].VpcId' --output text | tr '\t' '\n' | sed 's/^/  ✗ /'
fi
echo ""

# Subnets
if check_resources "Subnets" "aws ec2 describe-subnets --region $AWS_REGION --filters 'Name=tag:Name,Values=*$PROJECT_FULL*' --query 'Subnets[].SubnetId' --output text"; then
    aws ec2 describe-subnets --region $AWS_REGION --filters "Name=tag:Name,Values=*$PROJECT_FULL*" --query 'Subnets[].SubnetId' --output text | tr '\t' '\n' | sed 's/^/  ✗ /'
fi
echo ""

# Route Tables
if check_resources "Route Tables" "aws ec2 describe-route-tables --region $AWS_REGION --filters 'Name=tag:Name,Values=*$PROJECT_FULL*' --query 'RouteTables[].RouteTableId' --output text"; then
    aws ec2 describe-route-tables --region $AWS_REGION --filters "Name=tag:Name,Values=*$PROJECT_FULL*" --query 'RouteTables[].RouteTableId' --output text | tr '\t' '\n' | sed 's/^/  ✗ /'
fi
echo ""

# Internet Gateways
if check_resources "Internet Gateways" "aws ec2 describe-internet-gateways --region $AWS_REGION --filters 'Name=tag:Name,Values=*$PROJECT_FULL*' --query 'InternetGateways[].InternetGatewayId' --output text"; then
    aws ec2 describe-internet-gateways --region $AWS_REGION --filters "Name=tag:Name,Values=*$PROJECT_FULL*" --query 'InternetGateways[].InternetGatewayId' --output text | tr '\t' '\n' | sed 's/^/  ✗ /'
fi
echo ""

# Security Groups
if check_resources "Security Groups" "aws ec2 describe-security-groups --region $AWS_REGION --filters 'Name=tag:Name,Values=*$PROJECT_FULL*' --query 'SecurityGroups[].GroupId' --output text"; then
    aws ec2 describe-security-groups --region $AWS_REGION --filters "Name=tag:Name,Values=*$PROJECT_FULL*" --query 'SecurityGroups[].GroupId' --output text | tr '\t' '\n' | sed 's/^/  ✗ /'
fi
echo ""

# 12. EC2 Resources
echo ">>> EC2 INSTANCES & TEMPLATES"
echo ""

# Auto Scaling Groups
if check_resources "Auto Scaling Groups" "aws autoscaling describe-auto-scaling-groups --region $AWS_REGION --query 'AutoScalingGroups[].AutoScalingGroupName' --output text" "$PROJECT_FULL"; then
    aws autoscaling describe-auto-scaling-groups --region $AWS_REGION --query 'AutoScalingGroups[].AutoScalingGroupName' --output text | tr '\t' '\n' | grep $PROJECT_FULL | sed 's/^/  ✗ /'
fi
echo ""

# Launch Templates
if check_resources "Launch Templates" "aws ec2 describe-launch-templates --region $AWS_REGION --query 'LaunchTemplates[].LaunchTemplateName' --output text" "$PROJECT_FULL"; then
    aws ec2 describe-launch-templates --region $AWS_REGION --query 'LaunchTemplates[].LaunchTemplateName' --output text | tr '\t' '\n' | grep $PROJECT_FULL | sed 's/^/  ✗ /'
fi
echo ""

# EC2 Instances (only running/stopped, not terminated)
if check_resources "EC2 Instances" "aws ec2 describe-instances --region $AWS_REGION --filters 'Name=instance-state-name,Values=running,stopped' 'Name=tag:Name,Values=*$PROJECT_FULL*' --query 'Reservations[].Instances[].InstanceId' --output text"; then
    aws ec2 describe-instances --region $AWS_REGION --filters "Name=instance-state-name,Values=running,stopped" "Name=tag:Name,Values=*$PROJECT_FULL*" --query 'Reservations[].Instances[].InstanceId' --output text | tr '\t' '\n' | sed 's/^/  ✗ /'
fi
echo ""

# 13. Summary
echo "=========================================="
if [ $TOTAL_RESOURCES -eq 0 ]; then
    echo -e "${GREEN}✓ No resources found${NC}"
    echo "AWS account is CLEAN"
    exit 0
else
    echo -e "${RED}✗ Found $TOTAL_RESOURCES total resources${NC}"
    echo "AWS account still has active resources"
    exit 1
fi
