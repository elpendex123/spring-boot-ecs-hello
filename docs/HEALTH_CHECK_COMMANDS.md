# Health Check Commands - Manual Reference
**Script:** `scripts/health-check.sh`
**Purpose:** Check health of ECS service, ALB, and API endpoint
**Created:** February 11, 2026

---

## Variables

These are the variables used in all commands below. Replace them with your actual values:

| Variable | Default | Meaning | Example |
|----------|---------|---------|---------|
| `$PROJECT_NAME` | `hello-app` | Project identifier | `hello-app` |
| `$ENVIRONMENT` | `dev` | Environment name | `dev`, `staging`, `prod` |
| `$AWS_REGION` | `us-east-1` | AWS region | `us-east-1`, `us-west-2` |
| `$CLUSTER_NAME` | `{PROJECT_NAME}-{ENVIRONMENT}-cluster` | ECS cluster name | `hello-app-dev-cluster` |
| `$SERVICE_NAME` | `{PROJECT_NAME}-{ENVIRONMENT}-service` | ECS service name | `hello-app-dev-service` |
| `$ALB_NAME` | `{PROJECT_NAME}-{ENVIRONMENT}-alb` | Load balancer name | `hello-app-dev-alb` |
| `$TG_NAME` | `{PROJECT_NAME}-{ENVIRONMENT}-tg` | Target group name | `hello-app-dev-tg` |
| `$LOG_GROUP` | `/ecs/{PROJECT_NAME}-{ENVIRONMENT}` | CloudWatch log group | `/ecs/hello-app-dev` |

### Default Values Example

If you run the script with defaults:
```bash
./scripts/health-check.sh
```

The variables will be:
- `PROJECT_NAME=hello-app`
- `ENVIRONMENT=dev`
- `AWS_REGION=us-east-1`
- `CLUSTER_NAME=hello-app-dev-cluster`
- `SERVICE_NAME=hello-app-dev-service`
- `ALB_NAME=hello-app-dev-alb`
- `TG_NAME=hello-app-dev-tg`
- `LOG_GROUP=/ecs/hello-app-dev`

### Custom Values Example

If you run with custom parameters:
```bash
./scripts/health-check.sh my-app staging eu-west-1
```

The variables will be:
- `PROJECT_NAME=my-app`
- `ENVIRONMENT=staging`
- `AWS_REGION=eu-west-1`
- `CLUSTER_NAME=my-app-staging-cluster`
- `SERVICE_NAME=my-app-staging-service`
- `ALB_NAME=my-app-staging-alb`
- `TG_NAME=my-app-staging-tg`
- `LOG_GROUP=/ecs/my-app-staging`

---

## 1. Check ECS Service Health

### Command in Script
```bash
SERVICE_STATUS=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$AWS_REGION" \
    --query 'services[0].status' \
    --output text)

RUNNING=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$AWS_REGION" \
    --query 'services[0].runningCount' \
    --output text)

DESIRED=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$AWS_REGION" \
    --query 'services[0].desiredCount' \
    --output text)
```

### What It Does
- Gets the current status of the ECS service (ACTIVE, DRAINING, INACTIVE)
- Gets the number of tasks currently running
- Gets the desired number of tasks that should be running

### Manual Commands

**With defaults (hello-app, dev, us-east-1):**
```bash
aws ecs describe-services \
    --cluster hello-app-dev-cluster \
    --services hello-app-dev-service \
    --region us-east-1 \
    --query 'services[0].status' \
    --output text

aws ecs describe-services \
    --cluster hello-app-dev-cluster \
    --services hello-app-dev-service \
    --region us-east-1 \
    --query 'services[0].runningCount' \
    --output text

aws ecs describe-services \
    --cluster hello-app-dev-cluster \
    --services hello-app-dev-service \
    --region us-east-1 \
    --query 'services[0].desiredCount' \
    --output text
```

**Expected Output:**
```
ACTIVE
2
2
```

### What It Means
- Service status: `ACTIVE` ✓ (good) or `DRAINING` / `INACTIVE` ✗ (bad)
- Running: Should equal Desired
- If Running < Desired: Deployment in progress or scaling

---

## 2. Check Application Load Balancer Health

### Command in Script
```bash
ALB_ARN=$(aws elbv2 describe-load-balancers \
    --region "$AWS_REGION" \
    --query "LoadBalancers[?LoadBalancerName=='$ALB_NAME'].LoadBalancerArn" \
    --output text)

ALB_STATUS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --region "$AWS_REGION" \
    --query 'LoadBalancers[0].State.Code' \
    --output text)
```

### What It Does
- Finds the ALB's ARN (Amazon Resource Name) by name
- Gets the ALB's current state

### Manual Commands

**Step 1: Get ALB ARN (with defaults)**
```bash
aws elbv2 describe-load-balancers \
    --region us-east-1 \
    --query "LoadBalancers[?LoadBalancerName=='hello-app-dev-alb'].LoadBalancerArn" \
    --output text
```

**Expected Output:**
```
arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/hello-app-dev-alb/1234567890abcdef
```

**Step 2: Get ALB Status**
```bash
aws elbv2 describe-load-balancers \
    --load-balancer-arns arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/hello-app-dev-alb/1234567890abcdef \
    --region us-east-1 \
    --query 'LoadBalancers[0].State.Code' \
    --output text
```

**Expected Output:**
```
active
```

### What It Means
- `active` ✓ (ALB is running and ready)
- `provisioning` ⏳ (ALB is being created)
- `failed` ✗ (ALB failed to start)

---

## 3. Check Target Group Health

### Command in Script
```bash
TG_ARN=$(aws elbv2 describe-target-groups \
    --region "$AWS_REGION" \
    --query "TargetGroups[?TargetGroupName=='$TG_NAME'].TargetGroupArn" \
    --output text)

HEALTHY_TARGETS=$(aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --region "$AWS_REGION" \
    --query "length([TargetHealthDescriptions[?TargetHealth.State=='healthy']])" \
    --output text)

TOTAL_TARGETS=$(aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --region "$AWS_REGION" \
    --query "length(TargetHealthDescriptions)" \
    --output text)
```

### What It Does
- Finds the Target Group ARN by name
- Counts how many targets are in "healthy" state
- Counts total number of targets

### Manual Commands

**Step 1: Get Target Group ARN (with defaults)**
```bash
aws elbv2 describe-target-groups \
    --region us-east-1 \
    --query "TargetGroups[?TargetGroupName=='hello-app-dev-tg'].TargetGroupArn" \
    --output text
```

**Expected Output:**
```
arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/hello-app-dev-tg/1234567890abcdef
```

**Step 2: Get Healthy Target Count**
```bash
aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/hello-app-dev-tg/1234567890abcdef \
    --region us-east-1 \
    --query "length([TargetHealthDescriptions[?TargetHealth.State=='healthy']])" \
    --output text
```

**Expected Output:**
```
2
```

**Step 3: Get Total Target Count**
```bash
aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/hello-app-dev-tg/1234567890abcdef \
    --region us-east-1 \
    --query "length(TargetHealthDescriptions)" \
    --output text
```

**Expected Output:**
```
2
```

### What It Means
- Healthy targets = Total targets ✓ (all targets passing health checks)
- Healthy targets < Total targets ⚠️ (some targets failing, check logs)
- No targets ✗ (service may not be deployed)

### Get Detailed Target Health Info

To see WHY a target might be unhealthy:
```bash
aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/hello-app-dev-tg/1234567890abcdef \
    --region us-east-1
```

**Expected Output:**
```json
{
    "TargetHealthDescriptions": [
        {
            "Target": {
                "Id": "10.0.0.123",
                "Port": 8080
            },
            "HealthCheckPort": "8080",
            "TargetHealth": {
                "State": "healthy",
                "Reason": "N/A",
                "Description": "N/A"
            }
        }
    ]
}
```

---

## 4. Check API Endpoint Health

### Command in Script
```bash
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --region "$AWS_REGION" \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/actuator/health")
```

### What It Does
- Gets the DNS name of the ALB
- Makes a curl request to the health endpoint
- Returns the HTTP status code

### Manual Commands

**Step 1: Get ALB DNS Name (with defaults)**
```bash
aws elbv2 describe-load-balancers \
    --load-balancer-arns arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/hello-app-dev-alb/1234567890abcdef \
    --region us-east-1 \
    --query 'LoadBalancers[0].DNSName' \
    --output text
```

**Expected Output:**
```
hello-app-dev-alb-1234567890.us-east-1.elb.amazonaws.com
```

**Step 2: Test API Health Endpoint**
```bash
curl -s -o /dev/null -w "%{http_code}" "http://hello-app-dev-alb-1234567890.us-east-1.elb.amazonaws.com/actuator/health"
```

**Expected Output:**
```
200
```

### Get Full Health Response

To see the actual health data (not just the status code):
```bash
curl "http://hello-app-dev-alb-1234567890.us-east-1.elb.amazonaws.com/actuator/health"
```

**Expected Output:**
```json
{
    "status": "UP"
}
```

### Get Application Endpoint

To see the actual application response:
```bash
curl "http://hello-app-dev-alb-1234567890.us-east-1.elb.amazonaws.com/hello"
```

**Expected Output:**
```json
{
    "message": "Hello, World!",
    "timestamp": "2026-02-11T10:30:45.123456",
    "version": "1.0.0"
}
```

### What It Means
- HTTP 200 ✓ (API is responding)
- HTTP 503 ✗ (Service Unavailable - targets not healthy)
- HTTP 504 ✗ (Gateway Timeout - no response from targets)
- Timeout/No response ✗ (DNS might be resolving, but targets not available)

---

## 5. Check CloudWatch Logs

### Command in Script
```bash
LOG_GROUP="/ecs/${PROJECT_NAME}-${ENVIRONMENT}"

aws logs describe-log-groups \
    --region "$AWS_REGION" \
    --query "logGroups[?logGroupName=='$LOG_GROUP']" \
    --output text

STREAM_COUNT=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP" \
    --region "$AWS_REGION" \
    --query 'length(logStreams)' \
    --output text)
```

### What It Does
- Checks if the log group exists
- Counts how many log streams have entries

### Manual Commands

**Step 1: Check If Log Group Exists (with defaults)**
```bash
aws logs describe-log-groups \
    --region us-east-1 \
    --query "logGroups[?logGroupName=='/ecs/hello-app-dev']" \
    --output text
```

**Expected Output (if exists):**
```
2026-02-11 /ecs/hello-app-dev 0 1707594645000 1707594645000 20
```

**Step 2: Count Log Streams**
```bash
aws logs describe-log-streams \
    --log-group-name /ecs/hello-app-dev \
    --region us-east-1 \
    --query 'length(logStreams)' \
    --output text
```

**Expected Output:**
```
2
```

### Get Log Stream Names

To see the actual log stream names:
```bash
aws logs describe-log-streams \
    --log-group-name /ecs/hello-app-dev \
    --region us-east-1 \
    --query 'logStreams[].logStreamName' \
    --output text
```

**Expected Output:**
```
ecs/hello-app-dev-container/123abc456def
ecs/hello-app-dev-container/789ghi012jkl
```

### Get Recent Logs

To see the recent log entries from a specific stream:
```bash
aws logs tail /ecs/hello-app-dev --follow --region us-east-1
```

Or get the last 50 lines:
```bash
aws logs tail /ecs/hello-app-dev --max-items 50 --region us-east-1
```

### What It Means
- Log group exists ✓ (application is logging)
- Log streams > 0 ✓ (tasks are producing logs)
- No log group ✗ (check if service is deployed)
- Log streams = 0 ✗ (check if tasks are actually running)

---

## Quick Reference: Running All Health Checks

### With Default Values
```bash
# Service Status
aws ecs describe-services --cluster hello-app-dev-cluster --services hello-app-dev-service --region us-east-1 --query 'services[0].[status,runningCount,desiredCount]' --output table

# ALB Status
aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[?LoadBalancerName=='hello-app-dev-alb'].State.Code" --output text

# Target Health
ALB_ARN=$(aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[?LoadBalancerName=='hello-app-dev-alb'].LoadBalancerArn" --output text)
aws elbv2 describe-target-health --target-group-arn $(aws elbv2 describe-target-groups --region us-east-1 --query "TargetGroups[?TargetGroupName=='hello-app-dev-tg'].TargetGroupArn" --output text) --region us-east-1 --query "TargetHealthDescriptions[].TargetHealth.State" --output text

# API Health
ALB_DNS=$(aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[?LoadBalancerName=='hello-app-dev-alb'].DNSName" --output text)
curl -s "http://$ALB_DNS/actuator/health"

# Logs
aws logs describe-log-streams --log-group-name /ecs/hello-app-dev --region us-east-1 --query 'length(logStreams)' --output text
```

---

## Troubleshooting Common Issues

### Service Shows "Running: 0/2"
**Problem:** No tasks are running
**Check:**
1. View deployment errors: `aws ecs describe-services --cluster hello-app-dev-cluster --services hello-app-dev-service --region us-east-1 --query 'services[0].deployments'`
2. Check recent logs: `aws logs tail /ecs/hello-app-dev --max-items 100`
3. Check if cluster has capacity: `aws ecs list-container-instances --cluster hello-app-dev-cluster --region us-east-1`

### Targets Show "Unhealthy"
**Problem:** ALB marked targets as unhealthy
**Check:**
1. View target health reasons: `aws elbv2 describe-target-health --target-group-arn TG_ARN --region us-east-1`
2. SSH into EC2 instance and check container: `docker ps`
3. View container logs: `docker logs CONTAINER_ID`

### HTTP 503 from API
**Problem:** Service Unavailable
**Check:**
1. Verify targets are healthy: `aws elbv2 describe-target-health --target-group-arn TG_ARN --region us-east-1`
2. Check ALB security group: `aws ec2 describe-security-groups --region us-east-1 --filters Name=group-name,Values=hello-app-dev-alb-sg`
3. Check if service is deployed: `aws ecs describe-services --cluster hello-app-dev-cluster --services hello-app-dev-service --region us-east-1`

### No Log Streams
**Problem:** Application not producing logs
**Check:**
1. Verify log group exists: `aws logs describe-log-groups --region us-east-1 --query "logGroups[?logGroupName=='/ecs/hello-app-dev']"`
2. Check task logs directly: `aws ecs describe-tasks --cluster hello-app-dev-cluster --tasks TASK_ARN --region us-east-1 --query 'tasks[0].containers[0]'`
3. Check CloudWatch Logs permissions in task role

