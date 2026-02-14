#!/bin/bash
#
# Force cleanup of AWS resources - for automated cleanup (no interactive confirmation)
# Usage: ./cleanup-aws-force.sh [project_name] [environment] [aws_region]
#

set -euo pipefail

# Configuration
PROJECT_NAME="${1:-hello-app}"
ENVIRONMENT="${2:-dev}"
AWS_REGION="${3:-us-east-1}"
PROJECT_FULL="${PROJECT_NAME}-${ENVIRONMENT}"

echo "========================================="
echo "Force AWS Infrastructure Cleanup"
echo "Project: $PROJECT_FULL"
echo "Region: $AWS_REGION"
echo "========================================="
echo ""

# Step 1: Scale down ECS Service
echo "Step 1: Scaling down ECS Service..."
CLUSTER_NAME="${PROJECT_FULL}-cluster"
SERVICE_NAME="${PROJECT_FULL}-service"

if aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --region "$AWS_REGION" &>/dev/null 2>&1; then
    echo "  Scaling service to 0 tasks..."
    aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "$SERVICE_NAME" \
        --desired-count 0 \
        --region "$AWS_REGION" \
        --output text > /dev/null 2>&1 || true

    echo "  Waiting for tasks to stop..."
    aws ecs wait services-stable \
        --cluster "$CLUSTER_NAME" \
        --services "$SERVICE_NAME" \
        --region "$AWS_REGION" 2>/dev/null || true

    echo "✓ ECS Service scaled down"
else
    echo "  Service not found (already deleted or doesn't exist)"
fi
echo ""

# Step 2: Run Terraform Destroy
echo "Step 2: Running Terraform Destroy..."
TERRAFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"

if [ -d "$TERRAFORM_DIR" ]; then
    cd "$TERRAFORM_DIR"

    if [ -f "terraform.tfstate" ] && [ -s "terraform.tfstate" ]; then
        echo "  Destroying Terraform-managed resources..."
        if terraform destroy -auto-approve -lock=false 2>&1 | tail -5; then
            echo "✓ Terraform destroy completed"
        else
            echo "⚠ Terraform destroy had issues - continuing with force cleanup"
        fi
    else
        echo "  terraform.tfstate not found or empty - skipping terraform destroy"
    fi
else
    echo "⚠ Terraform directory not found at $TERRAFORM_DIR"
fi
echo ""

# Step 3: Force cleanup of any remaining orphaned resources
echo "Step 3: Force cleanup of orphaned resources..."

# Deregister ECS Task Definitions
echo "  Deregistering ECS Task Definitions..."
for task_def in $(aws ecs list-task-definitions --region "$AWS_REGION" --family-prefix "${PROJECT_FULL}" --query 'taskDefinitionArns' --output text 2>/dev/null || echo ""); do
    aws ecs deregister-task-definition --task-definition "$task_def" --region "$AWS_REGION" 2>/dev/null || true
done

# Delete ECS Services (if terraform didn't fully remove them)
echo "  Deleting ECS Services..."
ECS_SERVICES=$(aws ecs list-services --cluster "$CLUSTER_NAME" --region "$AWS_REGION" --query 'serviceArns' --output text 2>/dev/null || echo "")
for SERVICE_ARN in $ECS_SERVICES; do
    SERVICE=$(echo "$SERVICE_ARN" | awk -F'/' '{print $NF}')
    aws ecs delete-service --cluster "$CLUSTER_NAME" --service "$SERVICE" --force --region "$AWS_REGION" 2>/dev/null || true
done

# Delete ECS Cluster
echo "  Deleting ECS Cluster..."
aws ecs delete-cluster --cluster "$CLUSTER_NAME" --region "$AWS_REGION" 2>/dev/null || true

# Delete ECS Capacity Providers
echo "  Deleting ECS Capacity Providers..."
CP_NAME="${PROJECT_FULL}-cp"
aws ecs delete-capacity-provider --capacity-provider "$CP_NAME" --region "$AWS_REGION" 2>/dev/null || true

# Delete Auto Scaling Groups (terminates instances)
echo "  Deleting Auto Scaling Groups..."
ASG_NAME="${PROJECT_FULL}-ecs-asg"
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name "$ASG_NAME" --force-delete --region "$AWS_REGION" 2>/dev/null || true
sleep 10

# Delete Load Balancer
echo "  Deleting Load Balancers..."
ALB_ARN=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query "LoadBalancers[?LoadBalancerName=='${PROJECT_FULL}-alb'].LoadBalancerArn" --output text 2>/dev/null || echo "")
if [ ! -z "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
    # Delete listeners first
    LISTENER_ARNS=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" --query 'Listeners[].ListenerArn' --output text 2>/dev/null || echo "")
    for LISTENER_ARN in $LISTENER_ARNS; do
        aws elbv2 delete-listener --listener-arn "$LISTENER_ARN" --region "$AWS_REGION" 2>/dev/null || true
    done
    # Delete ALB
    aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" 2>/dev/null || true
fi

# Delete Target Groups
echo "  Deleting Target Groups..."
TG_ARNS=$(aws elbv2 describe-target-groups --region "$AWS_REGION" --query "TargetGroups[?TargetGroupName=='${PROJECT_FULL}-tg'].TargetGroupArn" --output text 2>/dev/null || echo "")
for TG_ARN in $TG_ARNS; do
    aws elbv2 delete-target-group --target-group-arn "$TG_ARN" --region "$AWS_REGION" 2>/dev/null || true
done

# Delete Subnets
echo "  Deleting Subnets..."
SUBNET_IDS=$(aws ec2 describe-subnets --region "$AWS_REGION" --filters "Name=tag:Project,Values=$PROJECT_NAME" "Name=tag:Environment,Values=$ENVIRONMENT" --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")
for SUBNET_ID in $SUBNET_IDS; do
    aws ec2 delete-subnet --subnet-id "$SUBNET_ID" --region "$AWS_REGION" 2>/dev/null || true
done

# Delete Route Tables
echo "  Deleting Route Tables..."
RT_IDS=$(aws ec2 describe-route-tables --region "$AWS_REGION" --filters "Name=tag:Project,Values=$PROJECT_NAME" "Name=tag:Environment,Values=$ENVIRONMENT" --query 'RouteTables[].RouteTableId' --output text 2>/dev/null || echo "")
for RT_ID in $RT_IDS; do
    # Disassociate from subnets
    ASSOCS=$(aws ec2 describe-route-tables --route-table-ids "$RT_ID" --region "$AWS_REGION" --query 'RouteTables[0].Associations[?Main==false].RouteTableAssociationId' --output text 2>/dev/null || echo "")
    for ASSOC in $ASSOCS; do
        aws ec2 disassociate-route-table --association-id "$ASSOC" --region "$AWS_REGION" 2>/dev/null || true
    done
    aws ec2 delete-route-table --route-table-id "$RT_ID" --region "$AWS_REGION" 2>/dev/null || true
done

# Delete Internet Gateways
echo "  Deleting Internet Gateways..."
IGW_IDS=$(aws ec2 describe-internet-gateways --region "$AWS_REGION" --filters "Name=tag:Project,Values=$PROJECT_NAME" "Name=tag:Environment,Values=$ENVIRONMENT" --query 'InternetGateways[].InternetGatewayId' --output text 2>/dev/null || echo "")
for IGW_ID in $IGW_IDS; do
    # Detach from VPCs
    VPC_IDS=$(aws ec2 describe-internet-gateways --internet-gateway-ids "$IGW_ID" --region "$AWS_REGION" --query 'InternetGateways[0].Attachments[].VpcId' --output text 2>/dev/null || echo "")
    for VPC_ID in $VPC_IDS; do
        aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --region "$AWS_REGION" 2>/dev/null || true
    done
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --region "$AWS_REGION" 2>/dev/null || true
done

# Delete Security Groups
echo "  Deleting Security Groups..."
SG_IDS=$(aws ec2 describe-security-groups --region "$AWS_REGION" --filters "Name=tag:Project,Values=$PROJECT_NAME" "Name=tag:Environment,Values=$ENVIRONMENT" --query 'SecurityGroups[].GroupId' --output text 2>/dev/null || echo "")
for SG_ID in $SG_IDS; do
    aws ec2 delete-security-group --group-id "$SG_ID" --region "$AWS_REGION" 2>/dev/null || true
done

# Delete VPC
echo "  Deleting VPCs..."
VPC_IDS=$(aws ec2 describe-vpcs --region "$AWS_REGION" --filters "Name=tag:Project,Values=$PROJECT_NAME" "Name=tag:Environment,Values=$ENVIRONMENT" --query 'Vpcs[].VpcId' --output text 2>/dev/null || echo "")
for VPC_ID in $VPC_IDS; do
    aws ec2 delete-vpc --vpc-id "$VPC_ID" --region "$AWS_REGION" 2>/dev/null || true
done

# Delete ECR Repository
echo "  Deleting ECR Repository..."
aws ecr delete-repository --repository-name "$PROJECT_FULL" --force --region "$AWS_REGION" 2>/dev/null || true

# Delete CloudWatch Log Groups
echo "  Deleting CloudWatch Log Groups..."
aws logs delete-log-group --log-group-name "/ecs/${PROJECT_FULL}" --region "$AWS_REGION" 2>/dev/null || true

# Delete IAM Roles
echo "  Deleting IAM Roles..."
for ROLE in "${PROJECT_FULL}-ecs-task-execution-role" "${PROJECT_FULL}-ecs-task-role" "${PROJECT_FULL}-ecs-instance-role"; do
    # Detach all managed policies
    POLICIES=$(aws iam list-attached-role-policies --role-name "$ROLE" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo "")
    for POLICY_ARN in $POLICIES; do
        aws iam detach-role-policy --role-name "$ROLE" --policy-arn "$POLICY_ARN" 2>/dev/null || true
    done
    # Delete the role
    aws iam delete-role --role-name "$ROLE" 2>/dev/null || true
done

# Delete IAM Instance Profiles
echo "  Deleting IAM Instance Profiles..."
PROFILE_NAME="${PROJECT_FULL}-ecs-instance-profile"
aws iam delete-instance-profile --instance-profile-name "$PROFILE_NAME" 2>/dev/null || true

# Delete Launch Templates
echo "  Deleting Launch Templates..."
LT_IDS=$(aws ec2 describe-launch-templates --region "$AWS_REGION" --filters "Name=tag:Project,Values=$PROJECT_NAME" "Name=tag:Environment,Values=$ENVIRONMENT" --query 'LaunchTemplates[].LaunchTemplateId' --output text 2>/dev/null || echo "")
for LT_ID in $LT_IDS; do
    aws ec2 delete-launch-template --launch-template-id "$LT_ID" --region "$AWS_REGION" 2>/dev/null || true
done

echo "✓ Orphaned resources cleanup completed"
echo ""

echo "========================================="
echo "✓ Force Cleanup Complete"
echo "========================================="
echo ""
echo "Note: If there are still resources remaining:"
echo "  1. Check AWS Console for resources not tagged with Project/Environment"
echo "  2. Some resources may still be terminating (EC2, ALB creation takes time)"
echo "  3. Run this script again after a few minutes"
echo ""
