# Teardown Commands - Manual Reference
**Script:** `scripts/teardown-aws.sh`
**Purpose:** Completely destroy all AWS infrastructure for a project
**Created:** February 11, 2026
**⚠️ WARNING:** These commands are DESTRUCTIVE and IRREVERSIBLE

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
| `$TERRAFORM_DIR` | `./terraform` | Terraform directory | `./terraform` |

---

## ⚠️ CRITICAL: What Gets Destroyed

**Permanent Deletions (Cannot be recovered):**
- ❌ ECS Cluster
- ❌ ECS Service
- ❌ EC2 Instances in ASG
- ❌ Application Load Balancer
- ❌ Target Groups
- ❌ VPC and all Subnets
- ❌ Security Groups
- ❌ IAM Roles and Policies
- ❌ Terraform State (if not backed up)

**Preserved (NOT automatically deleted):**
- ✓ ECR Repository (images persist)
- ✓ CloudWatch Logs
- ✓ S3 Terraform state backups (if configured)

---

## Step 1: Stop ECS Service

### Command in Script
```bash
CLUSTER_NAME="${PROJECT_NAME}-${ENVIRONMENT}-cluster"
SERVICE_NAME="${PROJECT_NAME}-${ENVIRONMENT}-service"

aws ecs update-service \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --desired-count 0 \
    --region "$AWS_REGION" \
    --output text

aws ecs wait services-stable \
    --cluster "$CLUSTER_NAME" \
    --services "$SERVICE_NAME" \
    --region "$AWS_REGION"
```

### What It Does
- Scales the ECS service down to 0 running tasks
- Waits for the service to stabilize (all tasks stopped)
- This gracefully shuts down the application

### Manual Commands

**Scale Service to 0 Tasks (with defaults)**
```bash
aws ecs update-service \
    --cluster hello-app-dev-cluster \
    --service hello-app-dev-service \
    --desired-count 0 \
    --region us-east-1
```

**Expected Output:**
```json
{
    "service": {
        "serviceName": "hello-app-dev-service",
        "clusterArn": "arn:aws:ecs:us-east-1:...",
        "status": "ACTIVE",
        "desiredCount": 0,
        "runningCount": 2
    }
}
```

**Wait for Service to Stop (takes 1-3 minutes)**
```bash
aws ecs wait services-stable \
    --cluster hello-app-dev-cluster \
    --service hello-app-dev-service \
    --region us-east-1
```

**Check Current Service Status**
```bash
aws ecs describe-services \
    --cluster hello-app-dev-cluster \
    --services hello-app-dev-service \
    --region us-east-1 \
    --query 'services[0].[status,desiredCount,runningCount]' \
    --output text
```

**Expected Output (after wait completes):**
```
ACTIVE    0    0
```

### Why This Step is Important
- Allows running tasks to shut down gracefully
- Prevents stuck connections or unfinished operations
- Ensures clean state before destroying infrastructure

---

## Step 2: Run Terraform Destroy

### Command in Script
```bash
TERRAFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../terraform" && pwd)"

cd "$TERRAFORM_DIR"

terraform destroy -auto-approve \
    -var="project_name=$PROJECT_NAME" \
    -var="environment=$ENVIRONMENT" \
    -var="aws_region=$AWS_REGION"
```

### What It Does
- Destroys all AWS resources defined in Terraform
- Requires `-auto-approve` to skip confirmation
- Uses provided variables to match your deployment

### Manual Commands

**Navigate to Terraform Directory**
```bash
cd terraform
```

**Plan the Destroy (preview what will be deleted)**
```bash
terraform plan -destroy \
    -var="project_name=hello-app" \
    -var="environment=dev" \
    -var="aws_region=us-east-1"
```

**Expected Output (truncated):**
```
Terraform will perform the following actions:

  # aws_alb.main will be destroyed
  - resource "aws_lb" "main" {...}

  # aws_ecs_cluster.main will be destroyed
  - resource "aws_ecs_cluster" "main" {...}

  # aws_ecs_service.app will be destroyed
  - resource "aws_ecs_service" "app" {...}

  [... more resources ...]

Plan: 0 to add, 0 to change, 14 to destroy.
```

**Actually Destroy (irreversible!)**
```bash
terraform destroy -auto-approve \
    -var="project_name=hello-app" \
    -var="environment=dev" \
    -var="aws_region=us-east-1"
```

**Expected Output:**
```
aws_security_group.alb: Destroying... [id=sg-0123456789abcdef0]
aws_lb_listener.app: Destroying... [id=arn:aws:elasticloadbalancing:...]
aws_autoscaling_group.ecs: Destroying... [id=hello-app-dev-ecs-asg]
aws_iam_role_policy_attachment.ecs_instance: Destroying... [id=...]
[... more resources being destroyed ...]

Destroy complete! Resources: 14 destroyed.
```

### Track Destroy Progress

If the destroy takes a long time, you can monitor what's happening:

```bash
# In another terminal, check ECS cluster status
aws ecs describe-clusters --clusters hello-app-dev-cluster --region us-east-1

# Check EC2 instances
aws ec2 describe-instances --region us-east-1 --filters "Name=tag:AmazonECSManaged,Values=true"

# Check ALB
aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[?LoadBalancerName=='hello-app-dev-alb']"

# Check VPC
aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:Name,Values=hello-app-dev-vpc"
```

### Troubleshooting Terraform Destroy Issues

**Issue: Terraform destroy hangs or times out**
```bash
# Kill the terraform process (Ctrl+C) and check what's left
aws ec2 describe-security-groups --region us-east-1 --filters "Name=tag:Name,Values=hello-app-dev-*"
```

**Issue: Target group deletion fails**
```bash
# Manually delete target groups
aws elbv2 describe-target-groups --region us-east-1 --query "TargetGroups[?TargetGroupName=='hello-app-dev-tg'].TargetGroupArn" --output text

# Then run terraform destroy again
terraform destroy -auto-approve -var="project_name=hello-app" -var="environment=dev" -var="aws_region=us-east-1"
```

**Issue: ALB still exists after destroy**

This is why the Jenkins teardown job includes force-delete logic. To manually force delete:
```bash
# Find ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[?LoadBalancerName=='hello-app-dev-alb'].LoadBalancerArn" --output text)

# Delete it
aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region us-east-1

# Delete associated target groups
TG_ARN=$(aws elbv2 describe-target-groups --region us-east-1 --query "TargetGroups[?TargetGroupName=='hello-app-dev-tg'].TargetGroupArn" --output text)
aws elbv2 delete-target-group --target-group-arn $TG_ARN --region us-east-1
```

---

## Step 3: Check for Orphaned Resources

### Command in Script
```bash
# Check for orphaned security groups
ORPHANED_SG=$(aws ec2 describe-security-groups \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENVIRONMENT}-*" \
    --query 'length(SecurityGroups)' \
    --output text)

# Check for orphaned ECS tasks
ORPHANED_TASKS=$(aws ecs list-tasks \
    --cluster "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --query 'length(taskArns)' \
    --output text)
```

### What It Does
- Looks for security groups that weren't deleted by Terraform
- Looks for ECS tasks still running in the cluster
- Reports any resources left behind

### Manual Commands

**Find Orphaned Security Groups (with defaults)**
```bash
aws ec2 describe-security-groups \
    --region us-east-1 \
    --filters "Name=tag:Name,Values=hello-app-dev-*" \
    --query 'SecurityGroups[*].[GroupId,GroupName]' \
    --output table
```

**Expected Output (if clean):**
```
(empty table)
```

**Find Orphaned ECS Tasks**
```bash
aws ecs list-tasks \
    --cluster hello-app-dev-cluster \
    --region us-east-1 \
    --query 'taskArns' \
    --output text
```

**Expected Output (if clean):**
```
(empty line)
```

**Find All Remaining Resources for Project (with defaults)**
```bash
aws resourcegroupstaggingapi get-resources \
    --tag-filters Key=Project,Values=hello-app Key=Environment,Values=dev \
    --region us-east-1 \
    --query 'ResourceTagMappingList[].[ResourceARN,ResourceType]' \
    --output table
```

### Manually Clean Up Orphaned Resources

**If orphaned security groups remain:**
```bash
# Find them
SG_ID=$(aws ec2 describe-security-groups \
    --region us-east-1 \
    --filters "Name=tag:Name,Values=hello-app-dev-alb-sg" \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

# Delete it
aws ec2 delete-security-group --group-id $SG_ID --region us-east-1
```

**If orphaned tasks remain:**
```bash
# List tasks
aws ecs list-tasks --cluster hello-app-dev-cluster --region us-east-1

# Stop specific task
aws ecs stop-task \
    --cluster hello-app-dev-cluster \
    --task <TASK_ARN> \
    --region us-east-1
```

**If cluster still exists:**
```bash
# Check if cluster has resources
aws ecs describe-clusters --clusters hello-app-dev-cluster --region us-east-1

# Force delete cluster
aws ecs delete-cluster --cluster hello-app-dev-cluster --region us-east-1
```

---

## Step 4: Manual Cleanup (Not Automatic)

### Command in Script
The script outputs reminders to manually clean up these resources:
```bash
echo "You may still need to manually clean up:"
echo "  - ECR Images (docker images will persist)"
echo "  - CloudWatch Logs"
echo "  - Any AWS resources tagged outside Terraform"
```

### What These Are

**ECR Images** - Docker images in the repository
- These are NOT deleted by Terraform destroy
- Only the repository definition is deleted
- Images consume storage and cost money

**CloudWatch Logs** - Application logs
- These are NOT deleted by Terraform destroy
- They contain historical records and may be needed for debugging
- Logs count toward CloudWatch storage quota

**Other Tagged Resources** - Manually created resources
- Resources created outside of Terraform
- Resources with custom tags

### Manual Cleanup Commands

**Delete All ECR Images (with defaults)**
```bash
# List images first
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

**Delete All Images**
```bash
# Option 1: Delete repository (deletes repository + all images)
aws ecr delete-repository \
    --repository-name hello-app-dev \
    --force \
    --region us-east-1
```

**Expected Output:**
```json
{
    "repository": {
        "repositoryArn": "arn:aws:ecr:us-east-1:123456789012:repository/hello-app-dev",
        "registryId": "123456789012",
        "repositoryName": "hello-app-dev",
        "repositoryUri": "123456789012.dkr.ecr.us-east-1.amazonaws.com/hello-app-dev"
    }
}
```

**Delete Specific Images Only (keep repository)**
```bash
# Delete specific image tag
aws ecr batch-delete-image \
    --repository-name hello-app-dev \
    --image-ids imageTag=latest \
    --region us-east-1

# Delete multiple image tags
aws ecr batch-delete-image \
    --repository-name hello-app-dev \
    --image-ids imageTag=1 imageTag=2 imageTag=3 \
    --region us-east-1
```

**Delete CloudWatch Logs (with defaults)**
```bash
# Delete log group (this deletes all log streams in it)
aws logs delete-log-group \
    --log-group-name /ecs/hello-app-dev \
    --region us-east-1
```

**Verify Cleanup**
```bash
# Check if ECR repository still exists
aws ecr describe-repositories \
    --repository-names hello-app-dev \
    --region us-east-1 || echo "Repository deleted"

# Check if log group still exists
aws logs describe-log-groups \
    --region us-east-1 \
    --query "logGroups[?logGroupName=='/ecs/hello-app-dev']" \
    --output text || echo "Log group deleted"
```

---

## Complete Manual Teardown Sequence

If you want to manually run through the entire teardown process step-by-step:

### Prerequisites Check
```bash
PROJECT_NAME=hello-app
ENVIRONMENT=dev
AWS_REGION=us-east-1
CLUSTER_NAME="$PROJECT_NAME-$ENVIRONMENT-cluster"
SERVICE_NAME="$PROJECT_NAME-$ENVIRONMENT-service"
```

### Step 1: Stop Service
```bash
echo "=== Step 1: Stopping ECS Service ==="
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --desired-count 0 \
    --region $AWS_REGION

echo "Waiting for tasks to stop..."
aws ecs wait services-stable \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --region $AWS_REGION

echo "✓ Service stopped"
```

### Step 2: Destroy with Terraform
```bash
echo "=== Step 2: Terraform Destroy ==="
cd terraform

terraform destroy -auto-approve \
    -var="project_name=$PROJECT_NAME" \
    -var="environment=$ENVIRONMENT" \
    -var="aws_region=$AWS_REGION"

echo "✓ Terraform destroy completed"
cd ..
```

### Step 3: Check for Orphaned Resources
```bash
echo "=== Step 3: Checking for Orphaned Resources ==="

echo "Orphaned Security Groups:"
aws ec2 describe-security-groups \
    --region $AWS_REGION \
    --filters "Name=tag:Name,Values=$PROJECT_NAME-$ENVIRONMENT-*" \
    --query 'SecurityGroups[*].GroupName' \
    --output text

echo "Orphaned Tasks:"
aws ecs list-tasks \
    --cluster $CLUSTER_NAME \
    --region $AWS_REGION \
    --query 'taskArns' \
    --output text || echo "Cluster not found"

echo "✓ Orphaned resource check complete"
```

### Step 4: Manual Cleanup
```bash
echo "=== Step 4: Manual Cleanup ==="

echo "Deleting ECR Repository..."
aws ecr delete-repository \
    --repository-name $PROJECT_NAME-$ENVIRONMENT \
    --force \
    --region $AWS_REGION && echo "✓ ECR repository deleted" || echo "✗ ECR repository not found"

echo "Deleting CloudWatch Logs..."
aws logs delete-log-group \
    --log-group-name /ecs/$PROJECT_NAME-$ENVIRONMENT \
    --region $AWS_REGION && echo "✓ Logs deleted" || echo "✗ Logs not found"

echo "✓ Manual cleanup complete"
```

### Final Verification
```bash
echo "=== Final Verification ==="

echo "Checking for remaining ECS clusters..."
aws ecs list-clusters \
    --region $AWS_REGION \
    --query "clusterArns[?contains(@, '$CLUSTER_NAME')]" \
    --output text | grep -q "$CLUSTER_NAME" && echo "✗ Cluster still exists" || echo "✓ Cluster deleted"

echo "Checking for remaining ALBs..."
aws elbv2 describe-load-balancers \
    --region $AWS_REGION \
    --query "LoadBalancers[?LoadBalancerName=='$PROJECT_NAME-$ENVIRONMENT-alb']" \
    --output text | grep -q "LoadBalancer" && echo "✗ ALB still exists" || echo "✓ ALB deleted"

echo "Checking for remaining VPCs..."
aws ec2 describe-vpcs \
    --region $AWS_REGION \
    --filters "Name=tag:Name,Values=$PROJECT_NAME-$ENVIRONMENT-vpc" \
    --query 'Vpcs[*].VpcId' \
    --output text | grep -q "vpc-" && echo "✗ VPC still exists" || echo "✓ VPC deleted"

echo ""
echo "=== Teardown Complete ==="
```

---

## Cost Impact

**Before Teardown:**
- ECS (EC2): ~$15-30/month
- ALB: ~$20/month
- EC2 Auto Scaling: ~$15-30/month
- CloudWatch: ~$10/month
- **Total: ~$60-90/month**

**After Teardown:**
- No compute resources running
- Only ECR storage remains: ~$1-5/month
- CloudWatch logs: ~$5-10/month if not deleted
- **Total: ~$1-15/month (or $0 if logs deleted)**

**Savings: $45-90/month ✓**

---

## Disaster Recovery: Restore from Backup

If you accidentally ran teardown or need to restore:

### Prerequisites
- Terraform state backed up (S3 or local backup)
- Docker images backed up in ECR or Docker Hub
- Application source code in Git

### Restore Steps

**1. Restore Terraform State**
```bash
# If you have a local backup
cp terraform.tfstate.backup terraform/terraform.tfstate

# If you have S3 backup (configured later)
aws s3 cp s3://hello-app-terraform-state/prod/terraform.tfstate terraform/terraform.tfstate
```

**2. Re-Import State (if needed)**
```bash
cd terraform
terraform init
terraform import aws_ecs_cluster.main hello-app-dev-cluster
# ... repeat for other resources if needed
```

**3. Pull Docker Images from ECR**
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

docker pull 123456789012.dkr.ecr.us-east-1.amazonaws.com/hello-app-dev:latest
```

**4. Reapply Infrastructure**
```bash
cd terraform
terraform plan -out=tfplan
terraform apply tfplan
```

---

## Safety Checklist

Before running any teardown:

- [ ] Exported/backed up any important data
- [ ] Confirmed you're destroying the right environment (dev/staging/prod)
- [ ] Verified you have another copy of the Terraform state
- [ ] Ensured no one is actively using the service
- [ ] Documented what you're deleting and why
- [ ] Checked with team members if applicable
- [ ] Have a restore plan ready (just in case)

---

## Related Commands

### Pause Instead of Destroy
If you want to save costs without destroying everything:

```bash
# Just scale down to 0 without destroying
aws ecs update-service \
    --cluster hello-app-dev-cluster \
    --service hello-app-dev-service \
    --desired-count 0 \
    --region us-east-1

# To bring back up later
aws ecs update-service \
    --cluster hello-app-dev-cluster \
    --service hello-app-dev-service \
    --desired-count 2 \
    --region us-east-1
```

### Destroy Specific Resources Only

```bash
# Destroy specific resource type (not everything)
cd terraform
terraform destroy -auto-approve -target='aws_ecs_service.app'

# Destroy multiple resources
terraform destroy -auto-approve \
    -target='aws_lb.main' \
    -target='aws_lb_target_group.app'
```

### Backup Before Destroy

```bash
# Create backup directory
mkdir -p backups/$(date +%Y%m%d_%H%M%S)

# Backup Terraform state
cp terraform/terraform.tfstate backups/$(date +%Y%m%d_%H%M%S)/terraform.tfstate
cp terraform/terraform.tfstate.backup backups/$(date +%Y%m%d_%H%M%S)/terraform.tfstate.backup

# Backup configuration
cp terraform/*.tf backups/$(date +%Y%m%d_%H%M%S)/

# List backups
ls -lah backups/
```

