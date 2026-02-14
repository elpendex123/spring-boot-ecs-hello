#!/bin/bash

set -euo pipefail

# Configuration
PROJECT_NAME="${1:-hello-app}"
ENVIRONMENT="${2:-dev}"
AWS_REGION="${3:-us-east-1}"

echo "========================================="
echo "Health Check: $PROJECT_NAME-$ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

HEALTHY=true

# Check ECS Service Health
echo -n "Checking ECS Service... "
CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cluster"
SERVICE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-service"

SERVICE_STATUS=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --region "$AWS_REGION" --query 'services[0].status' --output text 2>/dev/null || echo "UNKNOWN")
RUNNING=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --region "$AWS_REGION" --query 'services[0].runningCount' --output text 2>/dev/null || echo "0")
DESIRED=$(aws ecs describe-services --cluster "$CLUSTER_NAME" --services "$SERVICE_NAME" --region "$AWS_REGION" --query 'services[0].desiredCount' --output text 2>/dev/null || echo "0")

if [ "$SERVICE_STATUS" = "ACTIVE" ] && [ "$RUNNING" -eq "$DESIRED" ] && [ "$RUNNING" -gt 0 ]; then
    echo -e "${GREEN}HEALTHY${NC} ($RUNNING/$DESIRED tasks running)"
else
    echo -e "${RED}UNHEALTHY${NC} (Status: $SERVICE_STATUS, Running: $RUNNING/$DESIRED)"
    HEALTHY=false
fi

# Check ALB Health
echo -n "Checking Application Load Balancer... "
ALB_NAME="${PROJECT_NAME}-${ENVIRONMENT}-alb"
ALB_ARN=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query "LoadBalancers[?LoadBalancerName=='$ALB_NAME'].LoadBalancerArn" --output text 2>/dev/null || echo "")

if [ -n "$ALB_ARN" ]; then
    ALB_STATUS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --region "$AWS_REGION" --query 'LoadBalancers[0].State.Code' --output text)
    if [ "$ALB_STATUS" = "active" ]; then
        echo -e "${GREEN}HEALTHY${NC} (Status: $ALB_STATUS)"
    else
        echo -e "${RED}UNHEALTHY${NC} (Status: $ALB_STATUS)"
        HEALTHY=false
    fi
else
    echo -e "${RED}NOT FOUND${NC}"
    HEALTHY=false
fi

# Check Target Group Health
echo -n "Checking Target Group... "
TG_NAME="${PROJECT_NAME}-${ENVIRONMENT}-tg"
TG_ARN=$(aws elbv2 describe-target-groups --region "$AWS_REGION" --query "TargetGroups[?TargetGroupName=='$TG_NAME'].TargetGroupArn" --output text 2>/dev/null || echo "")

if [ -n "$TG_ARN" ]; then
    HEALTHY_TARGETS=$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --region "$AWS_REGION" --query "length(TargetHealthDescriptions[?TargetHealth.State=='healthy'])" --output text 2>/dev/null || echo "0")
    TOTAL_TARGETS=$(aws elbv2 describe-target-health --target-group-arn "$TG_ARN" --region "$AWS_REGION" --query "length(TargetHealthDescriptions)" --output text 2>/dev/null || echo "0")

    if [ "$HEALTHY_TARGETS" -eq "$TOTAL_TARGETS" ] && [ "$TOTAL_TARGETS" -gt 0 ]; then
        echo -e "${GREEN}HEALTHY${NC} ($HEALTHY_TARGETS/$TOTAL_TARGETS healthy)"
    else
        echo -e "${RED}UNHEALTHY${NC} ($HEALTHY_TARGETS/$TOTAL_TARGETS healthy)"
        HEALTHY=false
    fi
else
    echo -e "${YELLOW}NOT FOUND${NC} (May not be deployed yet)"
fi

# Check API Health
echo -n "Checking API Endpoint... "
ALB_DNS=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --region "$AWS_REGION" --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null || echo "")

if [ -n "$ALB_DNS" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/actuator/health" 2>/dev/null || echo "000")

    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}HEALTHY${NC} (HTTP $HTTP_CODE)"
    else
        echo -e "${RED}UNHEALTHY${NC} (HTTP $HTTP_CODE)"
        HEALTHY=false
    fi
else
    echo -e "${YELLOW}UNABLE TO TEST${NC} (No ALB DNS)"
fi

# Check CloudWatch Logs
echo -n "Checking CloudWatch Logs... "
LOG_GROUP="/ecs/${PROJECT_NAME}-${ENVIRONMENT}"

if aws logs describe-log-groups --region "$AWS_REGION" --query "logGroups[?logGroupName=='$LOG_GROUP']" --output text &>/dev/null; then
    STREAM_COUNT=$(aws logs describe-log-streams --log-group-name "$LOG_GROUP" --region "$AWS_REGION" --query 'length(logStreams)' --output text 2>/dev/null || echo "0")
    if [ "$STREAM_COUNT" -gt 0 ]; then
        echo -e "${GREEN}HEALTHY${NC} ($STREAM_COUNT log streams)"
    else
        echo -e "${YELLOW}NO STREAMS${NC}"
    fi
else
    echo -e "${YELLOW}NOT FOUND${NC}"
fi

# Final Summary
echo ""
echo "========================================="
if [ "$HEALTHY" = true ]; then
    echo -e "${GREEN}✓ All systems HEALTHY${NC}"
    exit 0
else
    echo -e "${RED}✗ Some systems UNHEALTHY${NC}"
    exit 1
fi
