# Issue: ECS Service - assign_public_ip Not Supported for EC2 Launch Type

## Problem
When running `terraform apply` to deploy ECS infrastructure, the operation failed with error:
```
Error: Error creating ECS service: InvalidParameterException: Assign public IP is not supported for this launch type
```

This error occurred in the ECS service network configuration.

## Root Cause
The Terraform configuration had `assign_public_ip = true` in the ECS service network configuration. This parameter is **only valid for Fargate launch type**, not for EC2 launch type.

The infrastructure was configured to use EC2 launch type (self-managed instances), so the public IP assignment parameter is not applicable and causes an error.

## Background: EC2 vs Fargate

| Aspect | EC2 Launch Type | Fargate Launch Type |
|--------|-----------------|-------------------|
| Compute | Self-managed EC2 instances | Serverless (AWS managed) |
| Networking | Via VPC/instance security groups | Via Fargate networking |
| Public IP | Set on instance level | Set via `assign_public_ip` parameter |
| Use case | Cost-effective, full control | Simpler, no instance management |

## Solution
**Remove `assign_public_ip = true` from ECS service network configuration.**

### Before (Failed):
```hcl
# terraform/ecs.tf
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-${var.environment}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "EC2"  # ← EC2 launch type

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true  # ← ERROR: Not valid for EC2
  }

  # ... rest of config
}
```

### After (Success):
```hcl
# terraform/ecs.tf
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-${var.environment}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "EC2"  # ← EC2 launch type

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs_tasks.id]
    # assign_public_ip removed - not needed for EC2
  }

  # ... rest of config
}
```

## Why It Works
For EC2 launch type:
- Tasks run on EC2 instances that you manage
- Public IP (if needed) is assigned to the instance itself, not the task
- Task networking is via the instance's ENI (Elastic Network Interface)
- Network configuration specifies subnets and security groups, not public IP

## Public IP for EC2 Tasks (Alternative)
If you need public IP for EC2 tasks:

### Option 1: Set on instance level
```hcl
resource "aws_launch_template" "ecs" {
  # ... other config
  associate_public_ip_address = true  # Set on EC2 instance
}
```

### Option 2: Set on subnet level
```hcl
resource "aws_subnet" "public" {
  map_public_ip_on_launch = true  # New instances get public IPs
}
```

### Option 3: Use Fargate if needed
```hcl
resource "aws_ecs_service" "app" {
  launch_type = "FARGATE"  # Switch to Fargate

  network_configuration {
    assign_public_ip = true  # Valid for Fargate
  }
}
```

## Decision: Why EC2?
This project uses EC2 launch type because:
- ✅ Cost-effective for consistent workloads
- ✅ Full control over instances
- ✅ Can use t3.small instances (cheaper than Fargate)
- ✅ Suitable for development/learning
- ⚠️ Requires managing instance availability

Alternative (Fargate):
- ✅ No instance management
- ✅ Simpler operations
- ⚠️ Higher cost for small workloads
- ⚠️ Less control over compute

## Impact
- **Design**: EC2 launch type with self-managed instances
- **Networking**: Public IP handled at instance level via launch template
- **Public Access**: Available through ALB on public subnets

## Verification
After fix, tested deployment:
```bash
cd terraform
terraform plan  # ✅ No errors
terraform apply # ✅ Infrastructure created successfully
```

**Results**:
- ✅ ECS cluster created
- ✅ Auto Scaling Group launched EC2 instances
- ✅ ECS service started on instances
- ✅ Tasks registered with ALB
- ✅ Health checks passing

## Prevention
**Checklist for ECS configuration:**
- [ ] Verify launch type: EC2 or Fargate
- [ ] If EC2: Remove `assign_public_ip` from network_configuration
- [ ] If EC2: Consider public IP at instance level if needed
- [ ] If Fargate: Keep `assign_public_ip` parameter for networking
- [ ] Test terraform plan before apply
- [ ] Verify service is active after apply

## Related Files
- `terraform/ecs.tf` - ECS service configuration
- `terraform/variables.tf` - Launch type configuration
- `terraform/vpc.tf` - Subnet and networking configuration

## Learning Points
1. **Launch type matters**: Different parameters for EC2 vs Fargate
2. **Error messages help**: Message clearly indicated "not supported for this launch type"
3. **Network layers**: Public IP can be set at subnet, instance, or task level depending on launch type
4. **Test early**: Running `terraform plan` catches these errors before applying

