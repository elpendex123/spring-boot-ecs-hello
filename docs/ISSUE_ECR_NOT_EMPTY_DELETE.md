# Issue: ECR Repository Not Empty - Cannot Delete

## Problem
When running `terraform destroy`, infrastructure deletion failed with error:
```
RepositoryNotEmptyException: The repository with name 'hello-app-dev' in registry with id '903609216629' cannot be deleted because it still contains images
```

This prevented complete teardown of AWS resources.

## Root Cause
The ECR (Elastic Container Registry) repository had a Docker image pushed to it. Terraform was trying to delete the ECR resource, but AWS doesn't allow deleting non-empty repositories by default.

**Why**: This is a safety feature to prevent accidental data loss. You must explicitly allow force deletion.

## Initial Workaround
Before applying permanent fix, manually deleted the image:
```bash
aws ecr batch-delete-image \
  --repository-name hello-app-dev \
  --image-ids imageTag=latest
```

This allowed `terraform destroy` to proceed, but the issue would reoccur after each image push.

## Permanent Solution
**Add `force_delete = true` to Terraform ECR resource.**

### Before (Failed):
```hcl
# terraform/ecr.tf
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecr"
  }
}
```

### After (Success):
```hcl
# terraform/ecr.tf
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # ← NEW LINE

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecr"
  }
}
```

## What `force_delete = true` Does
- Allows Terraform to delete ECR repository even if it contains images
- Automatically deletes all images in the repository before deleting the repository
- No manual cleanup required
- Safe because this is a development environment

## When to Use `force_delete`

### ✅ Use for Development/Testing
```hcl
force_delete = true  # Dev environment - OK to lose images
```

### ⚠️ Consider for Production
```hcl
# Option 1: Disable force delete
force_delete = false

# Option 2: Use force delete with caution
force_delete = var.enable_force_delete  # Control via variable
```

In production, you might want to:
1. Archive images before deletion
2. Prevent accidental deletion with `prevent_destroy = true`
3. Use separate ECR repository for each environment

## Implementation Details
The `force_delete` parameter in Terraform AWS provider:
- Only applies to `terraform destroy` operation
- Does not affect `terraform apply` (images are preserved)
- Requires explicit confirmation via `terraform destroy` (no auto-approve edge cases)
- Safe because it's only used during intentional destruction

## Impact Timeline
1. **Day 1**: Deployed infrastructure with image to ECR
2. **Day 1**: Tried to destroy → failed (ECR not empty)
3. **Day 1**: Manual cleanup: deleted image, then destroy succeeded
4. **Day 1**: Added `force_delete = true` to ECR resource
5. **Day 2+**: `terraform destroy` now works seamlessly

## Verification
After fix, tested complete destroy/recreate cycle:
```bash
# Push image (fills ECR)
docker push 903609216629.dkr.ecr.us-east-1.amazonaws.com/hello-app-dev:latest

# Destroy (with force_delete = true)
cd terraform
terraform destroy -auto-approve
# ✅ ECR repository deleted successfully

# Recreate (verify it works again)
terraform apply -auto-approve
# ✅ Empty ECR repository created
```

## Related Configuration
This works in conjunction with:
- ECR lifecycle policy (keeps last 10 images)
- Terraform state management (tracks deletion)
- AWS provider settings

## Prevention
**Checklist for ECR resources:**
- [ ] Add `force_delete = true` for development environments
- [ ] Document why force_delete is enabled/disabled
- [ ] Consider environment-based variable for force_delete
- [ ] Test destroy workflow during initial setup
- [ ] Verify images are deleted in AWS console after destroy

## Related Files
- `terraform/ecr.tf` - ECR resource with force_delete
- `docs/TEARDOWN.md` - Teardown procedure documentation

## Alternative: Lifecycle Policy
ECR has a separate lifecycle policy that auto-deletes old images:
```hcl
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
```

This prevents unlimited accumulation but doesn't help with `force_delete` requirement.

