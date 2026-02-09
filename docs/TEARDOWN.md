# Teardown Guide: Stopping AWS Resources

This guide explains how to safely shut down and destroy all AWS resources to avoid charges when not using your application.

## Table of Contents

1. [Overview](#overview)
2. [Cost Impact](#cost-impact)
3. [Methods to Teardown](#methods-to-teardown)
4. [Recommended Approach](#recommended-approach)
5. [Verification](#verification)
6. [FAQs](#faqs)

---

## Overview

Your deployed infrastructure incurs AWS charges while running. When you're not actively using the application (like before going to sleep), you should destroy the infrastructure to avoid unnecessary costs.

**What gets destroyed:**
- EC2 instances (t3.small)
- Application Load Balancer (ALB)
- ECS Cluster and Service
- VPC, subnets, and networking resources
- IAM roles and policies
- CloudWatch logs
- Docker images in ECR (optional, with `force_delete = true`)

**What is NOT automatically destroyed:**
- GitHub repository
- Local git repository
- Source code on your machine

---

## Cost Impact

### Running Infrastructure (Hourly Costs)
```
2x EC2 t3.small instances  ≈ $0.042/hour
Application Load Balancer ≈ $0.016/hour
Data transfer             ≈ $0.003/hour
                          ─────────────
                          ≈ $0.061/hour
```

**Daily Cost: ~$1.46**
**Monthly Cost: ~$44**

### After Teardown
**Cost: $0**

---

## Methods to Teardown

### Method 1: Direct Terraform (Fastest & Recommended) ⭐

**Command:**
```bash
cd /home/enrique/CLAUDE/spring_boot_aws_ecs/terraform
terraform destroy -auto-approve
```

**What happens:**
1. Terraform reads current state
2. Plans destruction of all resources
3. Automatically approves (no prompts)
4. Destroys resources in dependency order
5. Updates terraform.tfstate

**Time:** ~5-10 minutes

**Pros:**
- Fast and straightforward
- Terraform manages the process
- Clean state file update
- Predictable order of destruction

**Cons:**
- No intermediate confirmations
- Less visibility into process

---

### Method 2: Using Teardown Script

**Command:**
```bash
./scripts/teardown-aws.sh
```

**What happens:**
1. Prompts for confirmation (type `yes`)
2. Scales ECS service to 0 tasks
3. Waits for tasks to stop
4. Runs `terraform destroy -auto-approve`
5. Checks for orphaned resources
6. Provides cleanup summary

**Time:** ~5-15 minutes (includes confirmation prompt)

**Pros:**
- Graceful shutdown of running tasks
- Clear confirmation step prevents accidents
- Summary of what was destroyed
- Checks for orphaned resources

**Cons:**
- Takes slightly longer
- Requires user input (type `yes`)

---

### Method 3: Step-by-Step Manual

**Step 1: Scale service to 0 (stop running tasks)**
```bash
aws ecs update-service \
  --cluster hello-app-dev-cluster \
  --service hello-app-dev-service \
  --desired-count 0 \
  --region us-east-1
```

**Step 2: Wait for tasks to stop**
```bash
aws ecs wait services-stable \
  --cluster hello-app-dev-cluster \
  --services hello-app-dev-service \
  --region us-east-1
```

**Step 3: Delete infrastructure**
```bash
cd terraform
terraform destroy -auto-approve
```

**Time:** ~10-15 minutes

**Pros:**
- Full control over each step
- Can verify at each stage
- Graceful shutdown

**Cons:**
- More manual steps
- More error-prone

---

## Recommended Approach

### For Quick Teardown (Before Sleep)
```bash
cd /home/enrique/CLAUDE/spring_boot_aws_ecs/terraform
terraform destroy -auto-approve
```

**Why:**
- Fastest method (5-10 minutes)
- No user input required
- Terraform handles everything
- Infrastructure is complex enough that order matters

### For Safer Teardown (During Work)
```bash
./scripts/teardown-aws.sh
```

**Why:**
- Explicit confirmation prevents accidents
- Graceful shutdown of running tasks
- Summary of destroyed resources
- Helpful for documentation

---

## Verification

### Verify Everything is Destroyed

#### Check using Terraform
```bash
cd terraform
terraform state list
```

**Expected output:** Empty (no resources)

#### Check using AWS CLI
```bash
# Check ECS cluster
aws ecs describe-clusters \
  --clusters hello-app-dev-cluster \
  --region us-east-1 \
  --query 'clusters[0].status'

# Check VPC
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=hello-app-dev-vpc" \
  --region us-east-1 \
  --query 'Vpcs[0].VpcId'

# Check ALB
aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --query "LoadBalancers[?LoadBalancerName=='hello-app-dev-alb']"
```

**Expected output:** Empty or "None" for all commands

#### Use management script
```bash
./scripts/list-aws-services.sh
```

**Expected output:** All resources show as "not found"

---

## Recovery: Bringing Resources Back Up

If you need to restart the application after teardown:

### Step 1: Deploy Infrastructure
```bash
cd terraform
terraform apply -auto-approve
```

**Time:** ~3-5 minutes

### Step 2: Push Docker Image
```bash
docker tag hello-app:latest 903609216629.dkr.ecr.us-east-1.amazonaws.com/hello-app-dev:latest
docker push 903609216629.dkr.ecr.us-east-1.amazonaws.com/hello-app-dev:latest
```

**Time:** ~1-2 minutes

### Step 3: Wait for Tasks to Start
```bash
aws ecs wait services-stable \
  --cluster hello-app-dev-cluster \
  --services hello-app-dev-service \
  --region us-east-1
```

**Time:** ~2-3 minutes

### Step 4: Verify Deployment
```bash
./scripts/health-check.sh
```

**Total time to restore:** ~6-10 minutes

---

## Important Notes

### Data Loss
- **Source code is safe** - Everything in git is preserved
- **Logs are deleted** - CloudWatch logs are destroyed (configure longer retention if needed)
- **Docker images are deleted** - ECR repository images are removed (if `force_delete = true`)
- **Terraform state changes** - terraform.tfstate is updated to reflect destroyed resources

### Terraform State File
The `terraform.tfstate` file tracks all deployed resources. After `destroy`:
- File is updated to show 0 resources
- File remains in your repository for history
- Next `terraform apply` will recreate resources

### Preventing Accidental Destruction

If you want to prevent accidental destruction, use:
```bash
cd terraform
terraform destroy  # Without -auto-approve
```

This will show you what will be destroyed and prompt for confirmation.

---

## Cost Monitoring

### Check current charges
```bash
# Via AWS Console
1. Go to AWS Billing Dashboard
2. Check "Estimated charges" for current month
3. See service breakdown
```

### Set up billing alerts (optional)
```bash
# Via AWS Console
1. Go to AWS Billing
2. Click "Billing Preferences"
3. Enable "Receive Billing Alerts"
4. Create CloudWatch alarm for spending threshold
```

---

## Scenarios & Solutions

### Scenario: Want to pause for lunch
**Solution:** Run `terraform destroy -auto-approve` now, redeploy later
**Cost saved:** ~$0.08 for 1.5 hours

### Scenario: Done for the day
**Solution:** Run teardown script before bed
**Cost saved:** ~$1.46 for 24 hours

### Scenario: Want to keep infrastructure but scale down
**Solution:** Manually scale ECS service:
```bash
aws ecs update-service \
  --cluster hello-app-dev-cluster \
  --service hello-app-dev-service \
  --desired-count 0  # Scale to 0 tasks
  --region us-east-1
```
**Cost saved:** ~$0.046/hour (keeps ALB and VPC running)

### Scenario: Accidentally destroyed infrastructure
**Solution:** Redeploy using steps in "Recovery" section above
**No data loss** - All source code is in git

---

## FAQs

**Q: Will I lose my code?**
A: No. Your code is in git on GitHub. Only AWS resources are destroyed.

**Q: Can I destroy just the ECS service and keep the ALB?**
A: Technically yes, but not recommended. It's cleaner to destroy everything and redeploy as needed.

**Q: What if `terraform destroy` hangs?**
A: Press Ctrl+C to stop it. Check AWS Console for partially destroyed resources and clean up manually if needed.

**Q: How long does destroy take?**
A: Usually 5-10 minutes. Longest part is waiting for ALB to detach.

**Q: Can I schedule automatic teardown?**
A: Yes, but requires setup. You could use AWS Lambda + EventBridge for scheduled teardown (advanced).

**Q: Will the application URL work after teardown?**
A: No. The ALB is destroyed so the DNS name becomes invalid. You'll get a new URL when you redeploy.

**Q: Do I need to do anything before destroy?**
A: No. ECS tasks will be gracefully stopped automatically.

**Q: What's the cheapest option?**
A: Destroying everything completely. Running partial infrastructure costs more than you might expect due to ALB charges.

---

## Quick Command Reference

```bash
# Fastest teardown (recommended)
cd terraform && terraform destroy -auto-approve

# Safer teardown with confirmation
./scripts/teardown-aws.sh

# Verify nothing is running
./scripts/list-aws-services.sh

# Redeploy infrastructure
cd terraform && terraform apply -auto-approve

# Monitor deployment
./scripts/health-check.sh
```

---

## Summary

**Before sleeping or taking a break:**
```bash
cd /home/enrique/CLAUDE/spring_boot_aws_ecs/terraform
terraform destroy -auto-approve
```

**To bring it back:**
```bash
cd /home/enrique/CLAUDE/spring_boot_aws_ecs/terraform
terraform apply -auto-approve
# Then push Docker image and wait for tasks to start
```

This approach ensures you only pay for infrastructure when you're actively using it! 💰
