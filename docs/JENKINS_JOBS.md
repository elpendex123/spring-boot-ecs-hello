# Jenkins Jobs Documentation

Complete guide to all Jenkins jobs for the Spring Boot ECS deployment pipeline.

## Table of Contents

1. [Job Overview](#job-overview)
2. [Job Details](#job-details)
3. [Creating Jobs in Jenkins](#creating-jobs-in-jenkins)
4. [Job Workflows](#job-workflows)
5. [Typical Scenarios](#typical-scenarios)
6. [Troubleshooting](#troubleshooting)

---

## Job Overview

### Job Summary Table

| Job Name | Purpose | Stages | Parameters | Trigger |
|----------|---------|--------|-----------|---------|
| **build-and-push-to-ecr** | Build, test, and push to ECR | 6 | None | Manual |
| **deploy-to-ecs** | Deploy image to ECS | 6 | IMAGE_TAG, WAIT_FOR_DEPLOYMENT | Manual |
| **check-deployment-status** | Check current deployment status | 7 | None | Manual |
| **service-status** | Quick check if service is up/down | 1 | None | Manual |
| **bring-up-services** | Scale up ECS tasks | 5 | DESIRED_TASK_COUNT (dropdown), WAIT_FOR_STABLE | Manual |
| **bring-down-services** | Scale down ECS tasks | 5 | CONFIRM_SHUTDOWN, WAIT_FOR_SHUTDOWN | Manual |
| **teardown-infrastructure** | Destroy all AWS resources | 7 | Multiple checkboxes | Manual |
| **deploy-infrastructure** | Create AWS resources from Terraform | 9 | AUTO_APPROVE, SKIP_PLAN | Manual |

---

## Job Details

### 1. build-and-push-to-ecr

**Jenkinsfile:** `Jenkinsfile.build`

**Purpose:** Build Spring Boot application, run tests, create Docker image, and push to AWS ECR

**Stages:**
1. **Initialize AWS** - Get AWS account ID and configure ECR repository URL
2. **Checkout** - Clone code from GitHub
3. **Build** - Compile with Gradle (`./gradlew clean build`)
4. **Test** - Run unit tests with JUnit (`./gradlew test`)
5. **Docker Build** - Build Docker image locally
6. **Push to ECR** - Authenticate with ECR and push image

**Parameters:** None

**Output:**
- Docker image tagged with build number (e.g., `123`)
- Docker image tagged as `latest`
- Both pushed to ECR repository

**Example Output:**
```
✓ AWS Account ID: 123456789012
✓ Docker image built successfully
✓ Docker image pushed to ECR successfully
```

**Typical Build Time:** 6-10 minutes

**When to Use:**
- After code changes
- When you need a new Docker image
- Regular development workflow

**Next Steps After Success:**
- Run `deploy-to-ecs` to deploy new image
- Run `check-deployment-status` to verify

---

### 2. deploy-to-ecs

**Jenkinsfile:** `Jenkinsfile.deploy`

**Purpose:** Deploy Docker image to ECS service

**Parameters:**
- **IMAGE_TAG** (string)
  - Default: `latest`
  - Options: `latest`, build number (e.g., `123`), or any tag
  - Purpose: Specify which Docker image to deploy

- **WAIT_FOR_DEPLOYMENT** (checkbox)
  - Default: `checked`
  - Purpose: Wait up to 10 minutes for deployment to stabilize

**Stages:**
1. **Initialize AWS** - Setup AWS credentials
2. **Verify Image Exists** - Check if image exists in ECR
3. **Verify ECS Cluster** - Ensure cluster is active
4. **Update ECS Service** - Trigger new deployment
5. **Wait for Deployment** - Monitor task startup (if enabled)
6. **Verify Deployment** - Confirm new tasks are running

**Output:**
- Updated ECS service
- Running tasks with new image
- Health check results

**Example Usage:**
```
IMAGE_TAG: latest
WAIT_FOR_DEPLOYMENT: checked
```

**Typical Deploy Time:** 2-5 minutes

**When to Use:**
- After pushing new image to ECR
- To deploy specific build number
- To redeploy current latest image

**Next Steps After Success:**
- Run `check-deployment-status` for details
- Test application via ALB URL

---

### 3. check-deployment-status

**Jenkinsfile:** `Jenkinsfile.check-status`

**Purpose:** Get comprehensive view of current deployment status

**Parameters:** None

**Stages:**
1. **Initialize AWS** - Setup AWS credentials
2. **Check ECS Service Status** - Running vs desired tasks
3. **Check ALB Status** - Load balancer health
4. **Check Target Group Health** - Individual target health
5. **Check ECR Images** - Available Docker images
6. **Get Deployment URL** - ALB DNS name and endpoints
7. **Check Recent Events** - Last 5 ECS service events

**Output Example:**
```
ECS Cluster: hello-app-dev-cluster
  Status: ACTIVE
  Active Services: 1
  Running Tasks: 2

Service: hello-app-dev-service
  Status: ACTIVE
  Running: 2
  Desired: 2

Application URL: http://hello-app-dev-alb-123.us-east-1.elb.amazonaws.com/
Health Check: http://hello-app-dev-alb-123.us-east-1.elb.amazonaws.com/actuator/health
```

**When to Use:**
- Before and after deployments
- To verify all systems are healthy
- To get ALB URL for testing
- To debug deployment issues

**Typical Run Time:** 30-60 seconds

---

### 4. service-status

**Jenkinsfile:** `Jenkinsfile.service-status`

**Purpose:** Quick check if ECS service is UP or DOWN

**Parameters:** None

**Output Examples:**

**Service UP:**
```
✓✓✓ SERVICE STATUS: UP ✓✓✓
  Status: ACTIVE
  Desired Tasks: 2
  Running Tasks: 2
```

**Service DOWN:**
```
❌❌❌ SERVICE STATUS: DOWN ❌❌❌
  Status: ACTIVE
  Desired Tasks: 0
  Running Tasks: 0
```

**Service PARTIAL:**
```
⚠⚠⚠ SERVICE STATUS: PARTIAL (1/2) ⚠⚠⚠
  Status: ACTIVE
  Desired Tasks: 2
  Running Tasks: 1
```

**When to Use:**
- Quick status check before bed
- During troubleshooting
- Before scaling operations

**Typical Run Time:** 10-20 seconds

---

### 5. bring-up-services

**Jenkinsfile:** `Jenkinsfile.bring-up`

**Purpose:** Scale up ECS service tasks to bring services online

**Parameters:**
- **DESIRED_TASK_COUNT** (dropdown - required)
  - Options: 1, 2, 3, 4, 5
  - Default: (no default, must select)
  - Purpose: How many task instances to run

- **WAIT_FOR_STABLE** (checkbox)
  - Default: `checked`
  - Purpose: Wait for all tasks to start before finishing

**Stages:**
1. **Initialize AWS** - Setup AWS credentials
2. **Check Current Service Status** - See current state
3. **Bring Up Services** - Scale to desired count
4. **Wait for Service** - Monitor task startup (if enabled)
5. **Verify Service is Up** - Confirm all tasks running

**Example Usage:**
```
DESIRED_TASK_COUNT: 2 (selected from dropdown)
WAIT_FOR_STABLE: checked
```

**Output:**
```
Current Service Status:
  Desired Tasks: 0
  Running Tasks: 0

Will scale service to: 2 tasks

Service Status:
  Running: 2
  Desired: 2

✓ Service is now UP
```

**Typical Startup Time:** 1-3 minutes

**When to Use:**
- Start of day to bring services online
- After running teardown
- To scale up during heavy load
- Test before disaster scenarios

**Important:**
- **Choose task count carefully** - each task runs an EC2 instance
- 2 tasks is typical for development
- 3+ tasks recommended for production-like testing

---

### 6. bring-down-services

**Jenkinsfile:** `Jenkinsfile.bring-down`

**Purpose:** Scale down ECS service to save costs

**Parameters:**
- **CONFIRM_SHUTDOWN** (checkbox - **REQUIRED**)
  - Default: `unchecked`
  - Purpose: Prevent accidental shutdown
  - **Must check this box to proceed**

- **WAIT_FOR_SHUTDOWN** (checkbox)
  - Default: `checked`
  - Purpose: Wait for all tasks to stop before finishing

**Stages:**
1. **Confirmation Check** - Verify shutdown checkbox is checked
2. **Initialize AWS** - Setup AWS credentials
3. **Check Current Service Status** - See current state
4. **Bring Down Services** - Scale to 0 tasks
5. **Wait for Shutdown** - Monitor task termination (if enabled)
6. **Verify Service is Down** - Confirm all stopped

**⚠️ Safety Features:**
- Must check `CONFIRM_SHUTDOWN` checkbox to proceed
- Unchecked by default to prevent accidents
- Will show error if not confirmed

**Output:**
```
⚠ SHUTDOWN CANCELLED: Confirmation not checked.
Re-run the job and check CONFIRM_SHUTDOWN to proceed.
```

**Cost Savings:**
- Stops all running ECS tasks
- Frees EC2 instances for scaling down
- Typical savings: ~$1-2 per hour

**When to Use:**
- End of day to save costs
- Before deploying infrastructure teardown
- During testing to reduce charges
- Weekend/downtime shutdown

**Typical Shutdown Time:** 1-2 minutes

---

### 7. teardown-infrastructure

**Jenkinsfile:** `Jenkinsfile.teardown`

**Purpose:** Destroy all AWS infrastructure (VPC, ALB, ECS, EC2, etc.)

**⚠️ WARNING:** This is **IRREVERSIBLE**. Deleted resources cannot be recovered.

**Parameters:** Multiple checkboxes for granular control

1. **SCALE_DOWN_SERVICE** (checkbox)
   - Default: `checked`
   - Purpose: Gracefully shut down ECS service first

2. **DELETE_ECR_IMAGES** (checkbox)
   - Default: `checked`
   - Purpose: Delete all Docker images from ECR

3. **DESTROY_INFRASTRUCTURE** (checkbox - **REQUIRED**)
   - Default: `unchecked`
   - Purpose: **Confirm actual infrastructure destruction**
   - **Must check this to proceed**

4. **SAVE_TERRAFORM_STATE** (checkbox)
   - Default: `checked`
   - Purpose: Backup Terraform state before destroying
   - Creates backup in `backups/` directory

**Stages:**
1. **Confirmation Check** - Verify DESTROY_INFRASTRUCTURE is checked
2. **Initialize AWS** - Setup AWS credentials
3. **Scale Down ECS Service** - Stop all tasks (if enabled)
4. **Delete ECR Images** - Remove Docker images (if enabled)
5. **Backup Terraform State** - Save backup (if enabled)
6. **Destroy Infrastructure** - Run `terraform destroy`
7. **Verify Destruction** - Confirm all resources deleted

**Resources Destroyed:**
- VPC and subnets
- Internet Gateway and Route Tables
- Security Groups
- Application Load Balancer
- Target Groups
- ECS Cluster
- Auto Scaling Group
- EC2 instances
- ECR Repository (images deleted first)
- CloudWatch Log Groups
- IAM Roles and Policies

**What's NOT Destroyed:**
- Terraform state backup files (in `backups/`)
- S3 buckets (if any)
- CloudWatch metrics history

**⚠️ Safety Features:**
- Must check `DESTROY_INFRASTRUCTURE` checkbox
- Unchecked by default to prevent accidents
- Terraform plan shown before apply
- Manual confirmation required by default

**Cost Savings:**
- Zero AWS charges after destruction
- Only storage charges for backups

**When to Use:**
- End of day/week to stop all charges
- Before pausing long-term project
- When no longer need infrastructure
- Before creating fresh deployment

**Recovery:**
If infrastructure destroyed by mistake:
1. Run `deploy-infrastructure` to recreate
2. May take 5-10 minutes
3. All data lost (use backups if available)

**Typical Teardown Time:** 10-15 minutes

---

### 8. deploy-infrastructure

**Jenkinsfile:** `Jenkinsfile.deploy-infra`

**Purpose:** Create all AWS infrastructure from Terraform

**Prerequisites:**
- AWS credentials configured in Jenkins
- Terraform files in `terraform/` directory
- Valid AWS account with permissions

**Parameters:**
- **AUTO_APPROVE** (checkbox)
  - Default: `unchecked`
  - Purpose: Skip manual confirmation for apply
  - Recommended: Leave unchecked for safety

- **SKIP_PLAN** (checkbox)
  - Default: `unchecked`
  - Purpose: Skip planning step (faster but risky)
  - Recommended: Leave unchecked for visibility

**Stages:**
1. **Initialize AWS** - Setup AWS credentials
2. **Checkout** - Clone code from GitHub
3. **Verify Terraform Files** - Check terraform/ directory
4. **Terraform Init** - Initialize Terraform
5. **Terraform Format Check** - Check code formatting
6. **Terraform Validate** - Validate configuration
7. **Terraform Plan** - Show what will be created (if enabled)
8. **Terraform Apply** - Create resources
9. **Capture Outputs** - Extract ALB URL and ECR repo

**Output:**
```
Terraform Outputs:
  alb_dns_name = "hello-app-dev-alb-123.us-east-1.elb.amazonaws.com"
  alb_url = "http://hello-app-dev-alb-123.us-east-1.elb.amazonaws.com"
  ecr_repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/hello-app-dev"
  ecs_cluster_name = "hello-app-dev-cluster"
```

**Resources Created:**
- VPC with 2 public subnets
- Internet Gateway
- Security Groups (ALB and ECS tasks)
- Application Load Balancer
- Target Group (port 8081)
- ECS Cluster with Container Insights
- Launch Template for EC2
- Auto Scaling Group (min: 2, max: 4)
- ECS Capacity Provider
- ECR Repository
- CloudWatch Log Group (/ecs/hello-app-dev)
- IAM Roles and Policies

**Typical Deploy Time:** 5-10 minutes

**When to Use:**
- First time setup
- After running teardown-infrastructure
- To recreate fresh infrastructure
- When upgrading infrastructure config

**Next Steps After Success:**
1. Run `build-and-push-to-ecr` to build image
2. Run `deploy-to-ecs` to deploy
3. Run `check-deployment-status` to verify

**Costs:**
- EC2 instances (t3.small): ~$15/month per instance (2 minimum)
- ALB: ~$20/month
- Total: ~$50-70/month for dev environment

---

## Creating Jobs in Jenkins

### Step-by-Step: Create a Job from SCM (Pipeline from Jenkinsfile)

**For:** build-and-push-to-ecr, deploy-to-ecs

1. Jenkins Dashboard → **New Item**
2. Enter job name: `build-and-push-to-ecr`
3. Select **Pipeline**
4. Click **OK**
5. Configure:
   - **Description:** Build and push Docker image to ECR
   - **Definition:** Pipeline script from SCM
   - **SCM:** Git
   - **Repository URL:** https://github.com/elpendex123/spring-boot-ecs-hello.git
   - **Credentials:** (leave empty for public)
   - **Branch Specifier:** `*/main`
   - **Script Path:** `Jenkinsfile.build` (or `.deploy` for deploy job)
6. Click **Save**
7. Test: Click **Build Now**

### Step-by-Step: Create a Job from Inline Script

**For:** check-deployment-status, service-status, bring-up-services, bring-down-services, teardown-infrastructure, deploy-infrastructure

1. Jenkins Dashboard → **New Item**
2. Enter job name: `check-deployment-status`
3. Select **Pipeline**
4. Click **OK**
5. Configure:
   - **Description:** Check current deployment status
   - **Definition:** Pipeline script
   - **Pipeline:**
   ```
   Copy entire contents of Jenkinsfile.check-status
   Paste into the Script text area
   ```
6. Click **Save**
7. Test: Click **Build Now**

Repeat for other inline jobs:
- `service-status` ← use `Jenkinsfile.service-status`
- `bring-up-services` ← use `Jenkinsfile.bring-up`
- `bring-down-services` ← use `Jenkinsfile.bring-down`
- `teardown-infrastructure` ← use `Jenkinsfile.teardown`
- `deploy-infrastructure` ← use `Jenkinsfile.deploy-infra`

---

## Job Workflows

### Workflow 1: Daily Development

**Morning (Start of Day):**
```
bring-up-services (DESIRED_TASK_COUNT: 2)
    ↓
build-and-push-to-ecr
    ↓
deploy-to-ecs (IMAGE_TAG: latest)
    ↓
check-deployment-status
    ↓
✓ Application Ready
```

**During Development:**
```
(Make code changes, commit to GitHub)
    ↓
build-and-push-to-ecr
    ↓
deploy-to-ecs (IMAGE_TAG: latest)
    ↓
service-status
    ↓
Test application via ALB URL
```

**Evening (End of Day):**
```
check-deployment-status (verify all healthy)
    ↓
bring-down-services (CONFIRM_SHUTDOWN: checked)
    ↓
✓ Services Stopped (Save ~$1-2)
```

### Workflow 2: Infrastructure Setup

**Initial Setup:**
```
deploy-infrastructure (AUTO_APPROVE: unchecked)
    ↓
Verify: terraform output shows ALB URL
    ↓
build-and-push-to-ecr
    ↓
deploy-to-ecs (IMAGE_TAG: latest)
    ↓
check-deployment-status
    ↓
✓ Infrastructure Ready
```

### Workflow 3: Complete Teardown & Rebuild

**Teardown:**
```
teardown-infrastructure
  - SCALE_DOWN_SERVICE: checked
  - DELETE_ECR_IMAGES: checked
  - DESTROY_INFRASTRUCTURE: checked (required)
  - SAVE_TERRAFORM_STATE: checked
    ↓
✓ All Resources Deleted
```

**Rebuild (next day):**
```
deploy-infrastructure
    ↓
build-and-push-to-ecr
    ↓
deploy-to-ecs
    ↓
check-deployment-status
    ↓
✓ Fresh Infrastructure Ready
```

### Workflow 4: Testing Different Scales

**Load Testing:**
```
bring-up-services (DESIRED_TASK_COUNT: 4)
    ↓
check-deployment-status
    ↓
Run load tests
    ↓
bring-down-services (CONFIRM_SHUTDOWN: checked)
```

---

## Typical Scenarios

### Scenario 1: Code Change & Deploy

**You made code changes and want to deploy:**

1. Commit and push to GitHub
2. Run `build-and-push-to-ecr`
   - Waits: 6-10 minutes
   - Creates image with new build number (e.g., `build#45`)
3. Run `deploy-to-ecs`
   - Parameter: `IMAGE_TAG: latest` (always builds as latest)
   - Waits: 2-5 minutes
4. Run `check-deployment-status`
   - Verify new image running
   - Get ALB URL
5. Test via ALB URL
6. Done!

**Total Time:** ~15 minutes

---

### Scenario 2: Service is DOWN, Need to Restart

**You find service is not responding:**

1. Run `service-status`
   - Confirms: DOWN (desired: 0, running: 0)
2. Run `bring-up-services`
   - Parameter: `DESIRED_TASK_COUNT: 2`
   - Waits: 1-3 minutes
3. Run `check-deployment-status`
   - Verify service is up
4. Service accessible again

**Total Time:** ~5 minutes

---

### Scenario 3: Save Money - Shut Down at End of Day

**5 PM, time to shut down for day:**

1. Run `check-deployment-status`
   - Verify everything is healthy
2. Run `bring-down-services`
   - Parameter: `CONFIRM_SHUTDOWN: checked`
   - Waits: 1-2 minutes
3. Service is down, charges stopped

**Cost Savings:** ~$1-2 per hour
**Next Morning:** Run `bring-up-services` to restart

---

### Scenario 4: Destroy Everything & Start Fresh

**Weekend, want to clean up and save money:**

1. Run `teardown-infrastructure`
   - Parameters:
     - `SCALE_DOWN_SERVICE: checked`
     - `DELETE_ECR_IMAGES: checked`
     - `DESTROY_INFRASTRUCTURE: checked` (required)
     - `SAVE_TERRAFORM_STATE: checked`
   - Waits: 10-15 minutes
2. All resources destroyed
3. Zero AWS charges

**Monday, Ready to Deploy Again:**
1. Run `deploy-infrastructure`
   - Waits: 5-10 minutes
2. Run `build-and-push-to-ecr`
3. Run `deploy-to-ecs`
4. Back in business!

---

### Scenario 5: Check What's Currently Deployed

**Quick check on current state:**

```
Just run: check-deployment-status
```

Shows:
- ECS service status
- Running vs desired tasks
- ALB URL
- Target health
- Recent events
- Available ECR images

**Time:** 30-60 seconds

---

## Troubleshooting

### Problem: build-and-push-to-ecr Fails

**"docker: permission denied"**
```bash
# Fix: Add jenkins user to docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

**"AWS credentials not found"**
- Check: Jenkins → Manage Jenkins → Manage Credentials
- Verify credential ID is `aws-credentials`
- Re-test with: `test-aws-credentials` job

**"Gradle build fails"**
- Check: Console output for specific errors
- Common: Java version mismatch
- Try: `./gradlew clean build` locally first

---

### Problem: deploy-to-ecs Fails

**"ImageTag not found in ECR"**
- Verify image was pushed: Run `check-deployment-status`
- Check ECR repository for images
- Re-run `build-and-push-to-ecr`

**"ECS cluster not found"**
- Verify infrastructure deployed: `deploy-infrastructure`
- Check: `aws ecs list-clusters --region us-east-1`

**"Tasks not starting"**
- Check CloudWatch logs: `aws logs tail /ecs/hello-app-dev`
- Check target group health: `check-deployment-status`
- Verify security groups allow traffic

---

### Problem: Service Not Responding

1. Run `service-status`
   - If DOWN: Run `bring-up-services`
   - If UP: Run `check-deployment-status` for details
2. Check CloudWatch logs
   ```bash
   aws logs tail /ecs/hello-app-dev --follow
   ```
3. Check ALB target health
   ```bash
   aws elbv2 describe-target-health \
     --target-group-arn <arn> \
     --region us-east-1
   ```

---

### Problem: bring-down-services Won't Run

**"SHUTDOWN CANCELLED: Confirmation not checked"**
- Re-run job
- Check the `CONFIRM_SHUTDOWN` checkbox
- Click Build

This is intentional safety feature!

---

### Problem: teardown-infrastructure Won't Run

**"TEARDOWN CANCELLED: DESTROY_INFRASTRUCTURE not checked"**
- Re-run job
- Check the `DESTROY_INFRASTRUCTURE` checkbox
- Click Build

This is intentional safety feature!

---

## Quick Reference

### Job Cheat Sheet

| Need | Run | Parameters |
|------|-----|-----------|
| Build new image | `build-and-push-to-ecr` | None |
| Deploy latest image | `deploy-to-ecs` | IMAGE_TAG: latest |
| Check health | `check-deployment-status` | None |
| Quick status | `service-status` | None |
| Start services | `bring-up-services` | DESIRED_TASK_COUNT: 2 |
| Stop services | `bring-down-services` | CONFIRM_SHUTDOWN: ✓ |
| Destroy all | `teardown-infrastructure` | DESTROY_INFRASTRUCTURE: ✓ |
| Create infra | `deploy-infrastructure` | (none required) |

### Build Times

| Job | Min | Max | Typical |
|-----|-----|-----|---------|
| build-and-push-to-ecr | 5 min | 15 min | 8 min |
| deploy-to-ecs | 2 min | 8 min | 4 min |
| check-deployment-status | 20 sec | 1 min | 30 sec |
| service-status | 5 sec | 30 sec | 15 sec |
| bring-up-services | 1 min | 5 min | 2 min |
| bring-down-services | 1 min | 3 min | 2 min |
| teardown-infrastructure | 8 min | 20 min | 12 min |
| deploy-infrastructure | 5 min | 15 min | 8 min |

---

## Summary

**Key Points:**
1. ✅ Jobs are independent - run in any order
2. ✅ Parameters provide flexibility (dropdowns, checkboxes)
3. ✅ Safety confirmations prevent accidents
4. ✅ Email notifications on success/failure
5. ✅ Save money by bringing down services when not needed
6. ✅ Tear down entire infrastructure when done

**Typical Daily Workflow:**
```
Morning:   bring-up-services → build-and-push-to-ecr → deploy-to-ecs
Evening:   bring-down-services (SAVE MONEY!)
```

**Cost Optimization:**
- Always `bring-down-services` before leaving
- Use `teardown-infrastructure` on weekends
- Mon morning: `deploy-infrastructure` → fresh start

---

## Getting Help

**Stuck on a job?**
1. Check Console Output (red text = errors)
2. Run `check-deployment-status` for context
3. Review CloudWatch logs
4. Check AWS console for resource status

**Common Commands:**
```bash
# Check ECS service
aws ecs describe-services --cluster hello-app-dev-cluster --services hello-app-dev-service

# Check logs
aws logs tail /ecs/hello-app-dev --follow

# Check ALB
aws elbv2 describe-load-balancers --region us-east-1 | jq '.LoadBalancers[0].DNSName'

# List ECS tasks
aws ecs list-tasks --cluster hello-app-dev-cluster
```

---

**Last Updated:** February 2026
**Version:** 1.0.0
**Author:** Enrique Coello
