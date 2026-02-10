# List AWS Services Commands - Manual Reference
**Script:** `scripts/list-aws-services.sh`
**Purpose:** List and display all AWS resources created by the project
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
| `$ECR_REPO` | `{PROJECT_NAME}-{ENVIRONMENT}` | ECR repository name | `hello-app-dev` |
| `$LOG_GROUP` | `/ecs/{PROJECT_NAME}-{ENVIRONMENT}` | CloudWatch log group | `/ecs/hello-app-dev` |
| `$VPC_TAG` | `{PROJECT_NAME}-{ENVIRONMENT}-vpc` | VPC name tag | `hello-app-dev-vpc` |
| `$EXEC_ROLE` | `{PROJECT_NAME}-{ENVIRONMENT}-ecs-task-execution-role` | Task execution role | `hello-app-dev-ecs-task-execution-role` |
| `$INST_ROLE` | `{PROJECT_NAME}-{ENVIRONMENT}-ecs-instance-role` | Instance role | `hello-app-dev-ecs-instance-role` |

### Default Values Example

If you run the script with defaults:
```bash
./scripts/list-aws-services.sh
```

All variables use default values for `hello-app-dev` in `us-east-1`.

### Custom Values Example

If you run with custom parameters:
```bash
./scripts/list-aws-services.sh my-app staging eu-west-1
```

The variables will be:
- `PROJECT_NAME=my-app`
- `ENVIRONMENT=staging`
- `AWS_REGION=eu-west-1`
- All resource names updated accordingly

---

## 1. ECS Cluster Status

### Command in Script
```bash
CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cluster"
CLUSTER_STATUS=$(aws ecs describe-clusters \
    --clusters "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --query 'clusters[0].status' \
    --output text)
```

### What It Does
- Gets the ECS cluster information
- Returns the status of the cluster

### Manual Commands

**Get Cluster Status (with defaults)**
```bash
aws ecs describe-clusters \
    --clusters hello-app-dev-cluster \
    --region us-east-1 \
    --query 'clusters[0].status' \
    --output text
```

**Expected Output:**
```
ACTIVE
```

### Get Full Cluster Details

For comprehensive cluster information:
```bash
aws ecs describe-clusters \
    --clusters hello-app-dev-cluster \
    --region us-east-1
```

**Expected Output:**
```json
{
    "clusters": [
        {
            "clusterArn": "arn:aws:ecs:us-east-1:123456789012:cluster/hello-app-dev-cluster",
            "clusterName": "hello-app-dev-cluster",
            "status": "ACTIVE",
            "registeredContainerInstancesCount": 2,
            "runningTasksCount": 2,
            "pendingTasksCount": 0,
            "activeServicesCount": 1
        }
    ]
}
```

---

## 2. ECS Service Status

### Command in Script
```bash
SERVICE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-service"
SERVICE_DETAILS=$(aws ecs describe-services \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$AWS_REGION" \
    --query 'services[0]')

RUNNING_COUNT=$(echo "$SERVICE_DETAILS" | jq '.runningCount')
DESIRED_COUNT=$(echo "$SERVICE_DETAILS" | jq '.desiredCount')
SERVICE_STATUS=$(echo "$SERVICE_DETAILS" | jq '.status' -r)
```

### What It Does
- Gets complete service details
- Extracts running task count, desired task count, and service status

### Manual Commands

**Get Service Status and Task Counts (with defaults)**
```bash
aws ecs describe-services \
    --cluster hello-app-dev-cluster \
    --services hello-app-dev-service \
    --region us-east-1 \
    --query 'services[0].[status,runningCount,desiredCount]' \
    --output text
```

**Expected Output:**
```
ACTIVE    2    2
```

### Get Full Service Details

For comprehensive service information:
```bash
aws ecs describe-services \
    --cluster hello-app-dev-cluster \
    --services hello-app-dev-service \
    --region us-east-1
```

**Expected Output (truncated):**
```json
{
    "services": [
        {
            "serviceName": "hello-app-dev-service",
            "serviceArn": "arn:aws:ecs:us-east-1:123456789012:service/hello-app-dev-cluster/hello-app-dev-service",
            "status": "ACTIVE",
            "desiredCount": 2,
            "runningCount": 2,
            "taskDefinition": "arn:aws:ecs:us-east-1:123456789012:task-definition/hello-app-dev:1"
        }
    ]
}
```

---

## 3. ECS Tasks

### Command in Script
```bash
TASK_ARNS=$(aws ecs list-tasks \
    --cluster "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --query 'taskArns' \
    --output text)

# For each task:
for TASK_ARN in $TASK_ARNS; do
    TASK_ID=$(echo "$TASK_ARN" | awk -F'/' '{print $NF}')
    TASK_STATUS=$(aws ecs describe-tasks \
        --cluster "$CLUSTER_NAME" \
        --tasks "$TASK_ARN" \
        --region "$AWS_REGION" \
        --query 'tasks[0].lastStatus' \
        --output text)
done
```

### What It Does
- Lists all task ARNs running in the cluster
- For each task, gets the task ID and last known status

### Manual Commands

**List All Task ARNs (with defaults)**
```bash
aws ecs list-tasks \
    --cluster hello-app-dev-cluster \
    --region us-east-1 \
    --query 'taskArns' \
    --output text
```

**Expected Output:**
```
arn:aws:ecs:us-east-1:123456789012:task/hello-app-dev-cluster/1234567890abcdef1234567890abcdef
arn:aws:ecs:us-east-1:123456789012:task/hello-app-dev-cluster/fedcba0987654321fedcba0987654321
```

**Get Task Details for Specific Task**
```bash
aws ecs describe-tasks \
    --cluster hello-app-dev-cluster \
    --tasks arn:aws:ecs:us-east-1:123456789012:task/hello-app-dev-cluster/1234567890abcdef1234567890abcdef \
    --region us-east-1
```

**Expected Output (truncated):**
```json
{
    "tasks": [
        {
            "taskArn": "arn:aws:ecs:us-east-1:123456789012:task/hello-app-dev-cluster/1234567890abcdef1234567890abcdef",
            "lastStatus": "RUNNING",
            "desiredStatus": "RUNNING",
            "containerInstanceArn": "arn:aws:ecs:us-east-1:123456789012:container-instance/hello-app-dev-cluster/12345678",
            "containers": [
                {
                    "name": "hello-app-container",
                    "image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/hello-app-dev:latest"
                }
            ]
        }
    ]
}
```

### Get Formatted Task List

To get a table view of all tasks with their status:
```bash
aws ecs list-tasks \
    --cluster hello-app-dev-cluster \
    --region us-east-1 \
    --query 'taskArns' \
    --output text | tr '\t' '\n' | while read TASK_ARN; do
    TASK_ID=$(echo "$TASK_ARN" | awk -F'/' '{print $NF}')
    STATUS=$(aws ecs describe-tasks --cluster hello-app-dev-cluster --tasks "$TASK_ARN" --region us-east-1 --query 'tasks[0].lastStatus' --output text)
    echo "Task ID: $TASK_ID | Status: $STATUS"
done
```

---

## 4. Application Load Balancer

### Command in Script
```bash
ALB_NAME="${PROJECT_NAME}-${ENVIRONMENT}-alb"
ALB_ARN=$(aws elbv2 describe-load-balancers \
    --region "$AWS_REGION" \
    --query "LoadBalancers[?LoadBalancerName=='$ALB_NAME'].LoadBalancerArn" \
    --output text)

ALB_DNS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --region "$AWS_REGION" \
    --query 'LoadBalancers[0].DNSName' \
    --output text)

ALB_STATUS=$(aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --region "$AWS_REGION" \
    --query 'LoadBalancers[0].State.Code' \
    --output text)
```

### What It Does
- Finds the ALB by name and gets its ARN
- Gets the DNS name of the ALB
- Gets the current state of the ALB

### Manual Commands

**Get ALB ARN (with defaults)**
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

**Get ALB DNS Name**
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

**Get ALB Status**
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

### Get Full ALB Details
```bash
aws elbv2 describe-load-balancers \
    --region us-east-1 \
    --query "LoadBalancers[?LoadBalancerName=='hello-app-dev-alb']"
```

---

## 5. Target Group Health

### Command in Script
```bash
TG_NAME="${PROJECT_NAME}-${ENVIRONMENT}-tg"
TG_ARN=$(aws elbv2 describe-target-groups \
    --region "$AWS_REGION" \
    --query "TargetGroups[?TargetGroupName=='$TG_NAME'].TargetGroupArn" \
    --output text)

HEALTH_STATUS=$(aws elbv2 describe-target-health \
    --target-group-arn "$TG_ARN" \
    --region "$AWS_REGION" \
    --query 'TargetHealthDescriptions')

TARGET_COUNT=$(echo "$HEALTH_STATUS" | jq 'length')
```

### What It Does
- Finds the Target Group by name and gets its ARN
- Gets health information for all targets
- Counts the number of targets

### Manual Commands

**Get Target Group ARN (with defaults)**
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

**Get Target Health Status**
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
        },
        {
            "Target": {
                "Id": "10.0.1.456",
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

**Count Targets**
```bash
aws elbv2 describe-target-health \
    --target-group-arn arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/hello-app-dev-tg/1234567890abcdef \
    --region us-east-1 \
    --query 'length(TargetHealthDescriptions)' \
    --output text
```

**Expected Output:**
```
2
```

---

## 6. ECR Repository

### Command in Script
```bash
ECR_REPO="${PROJECT_NAME}-${ENVIRONMENT}"
ECR_URL=$(aws ecr describe-repositories \
    --repository-names "$ECR_REPO" \
    --region "$AWS_REGION" \
    --query 'repositories[0].repositoryUri' \
    --output text)

IMAGE_COUNT=$(aws ecr list-images \
    --repository-name "$ECR_REPO" \
    --region "$AWS_REGION" \
    --query 'length(imageIds)' \
    --output text)

# List all image tags
aws ecr list-images \
    --repository-name "$ECR_REPO" \
    --region "$AWS_REGION" \
    --query 'imageIds[*].imageTag' \
    --output text
```

### What It Does
- Gets the ECR repository URI
- Counts the number of images in the repository
- Lists all image tags in the repository

### Manual Commands

**Get ECR Repository URI (with defaults)**
```bash
aws ecr describe-repositories \
    --repository-names hello-app-dev \
    --region us-east-1 \
    --query 'repositories[0].repositoryUri' \
    --output text
```

**Expected Output:**
```
123456789012.dkr.ecr.us-east-1.amazonaws.com/hello-app-dev
```

**Count Images in Repository**
```bash
aws ecr list-images \
    --repository-name hello-app-dev \
    --region us-east-1 \
    --query 'length(imageIds)' \
    --output text
```

**Expected Output:**
```
5
```

**List All Image Tags**
```bash
aws ecr list-images \
    --repository-name hello-app-dev \
    --region us-east-1 \
    --query 'imageIds[*].imageTag' \
    --output text
```

**Expected Output:**
```
latest    1    2    3    4
```

**Get Detailed Image Information**
```bash
aws ecr describe-images \
    --repository-name hello-app-dev \
    --region us-east-1
```

**Expected Output (truncated):**
```json
{
    "imageDetails": [
        {
            "registryId": "123456789012",
            "repositoryName": "hello-app-dev",
            "imageId": {
                "imageDigest": "sha256:abcdef123456...",
                "imageTag": "latest"
            },
            "imageSizeInBytes": 245123456,
            "imagePushedAt": "2026-02-11T10:30:45.000000+00:00"
        }
    ]
}
```

---

## 7. VPC and Network

### Command in Script
```bash
VPC_ID=$(aws ec2 describe-vpcs \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENVIRONMENT}-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text)

SUBNET_COUNT=$(aws ec2 describe-subnets \
    --region "$AWS_REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query 'length(Subnets)' \
    --output text)
```

### What It Does
- Finds the VPC by its tag name
- Counts the number of subnets in the VPC

### Manual Commands

**Get VPC ID (with defaults)**
```bash
aws ec2 describe-vpcs \
    --region us-east-1 \
    --filters "Name=tag:Name,Values=hello-app-dev-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text
```

**Expected Output:**
```
vpc-1234567890abcdef0
```

**Count Subnets**
```bash
aws ec2 describe-subnets \
    --region us-east-1 \
    --filters "Name=vpc-id,Values=vpc-1234567890abcdef0" \
    --query 'length(Subnets)' \
    --output text
```

**Expected Output:**
```
2
```

**List All Subnets**
```bash
aws ec2 describe-subnets \
    --region us-east-1 \
    --filters "Name=vpc-id,Values=vpc-1234567890abcdef0" \
    --query 'Subnets[].[SubnetId,CidrBlock,AvailabilityZone]' \
    --output table
```

**Expected Output:**
```
|  SubnetId         | CidrBlock    | AvailabilityZone |
|-------------------|--------------|------------------|
|  subnet-123abc    | 10.0.0.0/24  | us-east-1a       |
|  subnet-456def    | 10.0.1.0/24  | us-east-1b       |
```

### Get Security Groups

To see security groups for the ALB:
```bash
aws ec2 describe-security-groups \
    --region us-east-1 \
    --filters "Name=group-name,Values=hello-app-dev-alb-sg" \
    --query 'SecurityGroups[0]'
```

To see security groups for ECS tasks:
```bash
aws ec2 describe-security-groups \
    --region us-east-1 \
    --filters "Name=group-name,Values=hello-app-dev-ecs-tasks-sg" \
    --query 'SecurityGroups[0]'
```

---

## 8. CloudWatch Logs

### Command in Script
```bash
LOG_GROUP="/ecs/${PROJECT_NAME}-${ENVIRONMENT}"

LOG_STREAMS=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP" \
    --region "$AWS_REGION" \
    --query 'logStreams' \
    --output text)

STREAM_COUNT=$(aws logs describe-log-streams \
    --log-group-name "$LOG_GROUP" \
    --region "$AWS_REGION" \
    --query 'length(logStreams)' \
    --output text)
```

### What It Does
- Gets all log streams in the log group
- Counts the total number of log streams

### Manual Commands

**Get Log Group Details (with defaults)**
```bash
aws logs describe-log-groups \
    --region us-east-1 \
    --query "logGroups[?logGroupName=='/ecs/hello-app-dev']"
```

**Expected Output:**
```json
{
    "logGroups": [
        {
            "logGroupName": "/ecs/hello-app-dev",
            "creationTime": 1707594645000,
            "retentionInDays": 7,
            "metricFilterCount": 0,
            "arn": "arn:aws:logs:us-east-1:123456789012:log-group:/ecs/hello-app-dev"
        }
    ]
}
```

**Count Log Streams**
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

**List Log Stream Names**
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

**View Recent Logs**
```bash
aws logs tail /ecs/hello-app-dev --max-items 50 --region us-east-1
```

**Stream Logs in Real-Time**
```bash
aws logs tail /ecs/hello-app-dev --follow --region us-east-1
```

---

## 9. EC2 Instances (ECS Cluster)

### Command in Script
```bash
INSTANCE_COUNT=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=tag:AmazonECSManaged,Values=true" \
                "Name=instance-state-name,Values=running" \
    --query 'length(Reservations[].Instances[])' \
    --output text)

# Get instance details:
aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=tag:AmazonECSManaged,Values=true" \
                "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,InstanceType]' \
    --output text
```

### What It Does
- Counts running EC2 instances tagged as ECS managed
- Gets instance ID, private IP, and instance type for each

### Manual Commands

**Count Running Instances (with defaults)**
```bash
aws ec2 describe-instances \
    --region us-east-1 \
    --filters "Name=tag:AmazonECSManaged,Values=true" \
              "Name=instance-state-name,Values=running" \
    --query 'length(Reservations[].Instances[])' \
    --output text
```

**Expected Output:**
```
2
```

**List Running Instances with Details**
```bash
aws ec2 describe-instances \
    --region us-east-1 \
    --filters "Name=tag:AmazonECSManaged,Values=true" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,InstanceType,State.Name]' \
    --output table
```

**Expected Output:**
```
|  InstanceId    | PrivateIpAddress | InstanceType | State  |
|----------------|------------------|--------------|--------|
|  i-123abc456   | 10.0.0.123       | t3.small     | running |
|  i-789def012   | 10.0.1.456       | t3.small     | running |
```

**SSH into an Instance**
```bash
# First get the instance ID and public IP
aws ec2 describe-instances \
    --region us-east-1 \
    --instance-ids i-123abc456 \
    --query 'Reservations[0].Instances[0].[PublicIpAddress,KeyName]'

# Then SSH
ssh -i ~/.ssh/YOUR_KEY_PAIR.pem ec2-user@PUBLIC_IP
```

---

## 10. IAM Roles

### Command in Script
```bash
EXEC_ROLE="${PROJECT_NAME}-${ENVIRONMENT}-ecs-task-execution-role"
INST_ROLE="${PROJECT_NAME}-${ENVIRONMENT}-ecs-instance-role"

aws iam get-role --role-name "$EXEC_ROLE"
aws iam get-role --role-name "$INST_ROLE"
```

### What It Does
- Checks if the task execution role exists
- Checks if the instance role exists

### Manual Commands

**Get Task Execution Role Details (with defaults)**
```bash
aws iam get-role \
    --role-name hello-app-dev-ecs-task-execution-role
```

**Expected Output:**
```json
{
    "Role": {
        "RoleName": "hello-app-dev-ecs-task-execution-role",
        "Arn": "arn:aws:iam::123456789012:role/hello-app-dev-ecs-task-execution-role",
        "CreateDate": "2026-02-10T10:30:45+00:00",
        "AssumeRolePolicyDocument": {...}
    }
}
```

**Get Instance Role Details (with defaults)**
```bash
aws iam get-role \
    --role-name hello-app-dev-ecs-instance-role
```

**List Policies Attached to Execution Role**
```bash
aws iam list-attached-role-policies \
    --role-name hello-app-dev-ecs-task-execution-role
```

**List Policies Attached to Instance Role**
```bash
aws iam list-attached-role-policies \
    --role-name hello-app-dev-ecs-instance-role
```

---

## Quick Reference: Summary of All Resources

### Get a Complete Inventory (with defaults)

**All commands in order:**

```bash
# 1. ECS Cluster
echo "=== ECS Cluster ==="
aws ecs describe-clusters --clusters hello-app-dev-cluster --region us-east-1 --query 'clusters[0].{Name:clusterName,Status:status,RegisteredInstances:registeredContainerInstancesCount,RunningTasks:runningTasksCount,ActiveServices:activeServicesCount}' --output table

# 2. ECS Service
echo "=== ECS Service ==="
aws ecs describe-services --cluster hello-app-dev-cluster --services hello-app-dev-service --region us-east-1 --query 'services[0].{Name:serviceName,Status:status,DesiredCount:desiredCount,RunningCount:runningCount}' --output table

# 3. ECS Tasks
echo "=== ECS Tasks ==="
aws ecs list-tasks --cluster hello-app-dev-cluster --region us-east-1 --query 'length(taskArns)' --output text

# 4. ALB
echo "=== Application Load Balancer ==="
aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[?LoadBalancerName=='hello-app-dev-alb'].{Name:LoadBalancerName,DNS:DNSName,Status:State.Code}" --output table

# 5. Target Group
echo "=== Target Group ==="
TG_ARN=$(aws elbv2 describe-target-groups --region us-east-1 --query "TargetGroups[?TargetGroupName=='hello-app-dev-tg'].TargetGroupArn" --output text)
aws elbv2 describe-target-health --target-group-arn $TG_ARN --region us-east-1 --query "TargetHealthDescriptions[*].TargetHealth.State" --output table

# 6. ECR Repository
echo "=== ECR Repository ==="
aws ecr describe-repositories --repository-names hello-app-dev --region us-east-1 --query 'repositories[0].{Name:repositoryName,URI:repositoryUri,CreatedAt:createdAt}' --output table

# 7. Images in ECR
echo "=== Docker Images ==="
aws ecr list-images --repository-name hello-app-dev --region us-east-1 --query 'imageIds[*].imageTag' --output text

# 8. VPC
echo "=== VPC ==="
aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:Name,Values=hello-app-dev-vpc" --query 'Vpcs[0].{VpcId:VpcId,CidrBlock:CidrBlock,State:State}' --output table

# 9. Subnets
echo "=== Subnets ==="
VPC_ID=$(aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:Name,Values=hello-app-dev-vpc" --query 'Vpcs[0].VpcId' --output text)
aws ec2 describe-subnets --region us-east-1 --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].[SubnetId,CidrBlock,AvailabilityZone]' --output table

# 10. CloudWatch Logs
echo "=== CloudWatch Logs ==="
aws logs describe-log-groups --region us-east-1 --query "logGroups[?logGroupName=='/ecs/hello-app-dev'].{LogGroup:logGroupName,RetentionDays:retentionInDays,CreatedDate:creationTime}" --output table

# 11. Log Streams
echo "=== Log Streams ==="
aws logs describe-log-streams --log-group-name /ecs/hello-app-dev --region us-east-1 --query 'length(logStreams)' --output text

# 12. EC2 Instances
echo "=== EC2 Instances ==="
aws ec2 describe-instances --region us-east-1 --filters "Name=tag:AmazonECSManaged,Values=true" "Name=instance-state-name,Values=running" --query 'Reservations[].Instances[].[InstanceId,PrivateIpAddress,InstanceType]' --output table

# 13. IAM Roles
echo "=== IAM Roles ==="
aws iam get-role --role-name hello-app-dev-ecs-task-execution-role --query 'Role.RoleName' --output text
aws iam get-role --role-name hello-app-dev-ecs-instance-role --query 'Role.RoleName' --output text
```

---

## Resource Naming Convention

All resources follow this naming pattern:

```
{PROJECT_NAME}-{ENVIRONMENT}-{RESOURCE_TYPE}
```

### Examples with Defaults (hello-app, dev)

| Resource | Name |
|----------|------|
| ECS Cluster | `hello-app-dev-cluster` |
| ECS Service | `hello-app-dev-service` |
| ALB | `hello-app-dev-alb` |
| Target Group | `hello-app-dev-tg` |
| ECR Repository | `hello-app-dev` |
| Log Group | `/ecs/hello-app-dev` |
| VPC | `hello-app-dev-vpc` (tag: Name) |
| Security Group (ALB) | `hello-app-dev-alb-sg` |
| Security Group (ECS) | `hello-app-dev-ecs-tasks-sg` |
| Task Execution Role | `hello-app-dev-ecs-task-execution-role` |
| Instance Role | `hello-app-dev-ecs-instance-role` |

---

## Filtering and Searching

### Find All Resources with Project Tag

```bash
# Find all resources tagged with project name
aws resourcegroupstaggingapi get-resources \
    --tag-filters Key=Project,Values=hello-app \
    --region us-east-1 \
    --query 'ResourceTagMappingList[].ResourceARN' \
    --output text
```

### Find All Resources in Environment

```bash
aws resourcegroupstaggingapi get-resources \
    --tag-filters Key=Environment,Values=dev \
    --region us-east-1 \
    --query 'ResourceTagMappingList[].[ResourceARN,Tags]' \
    --output table
```

---

## Cleanup and Resource Deletion

If you need to manually delete resources (use with caution!):

```bash
# Delete ECS Service (doesn't delete the task definition)
aws ecs delete-service --cluster hello-app-dev-cluster --service hello-app-dev-service --force --region us-east-1

# Delete ECS Cluster
aws ecs delete-cluster --cluster hello-app-dev-cluster --region us-east-1

# Delete ALB
ALB_ARN=$(aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[?LoadBalancerName=='hello-app-dev-alb'].LoadBalancerArn" --output text)
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region us-east-1

# Delete Target Group
TG_ARN=$(aws elbv2 describe-target-groups --region us-east-1 --query "TargetGroups[?TargetGroupName=='hello-app-dev-tg'].TargetGroupArn" --output text)
aws elbv2 delete-target-group --target-group-arn $TG_ARN --region us-east-1

# Delete ECR Repository (fails if not empty)
aws ecr delete-repository --repository-name hello-app-dev --region us-east-1

# Delete ECR Repository (force delete with images)
aws ecr delete-repository --repository-name hello-app-dev --force --region us-east-1

# Delete CloudWatch Log Group
aws logs delete-log-group --log-group-name /ecs/hello-app-dev --region us-east-1
```

