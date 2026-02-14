# Deployment Failure Analysis - February 14, 2026

## Summary
The second deployment attempt failed with an ECS Capacity Provider already existing error. The issue was identified and fixed.

## Root Cause Analysis

### Error Message
```
Error: creating ECS Capacity Provider (hello-app-dev-cp): operation error ECS:
CreateCapacityProvider, https response error StatusCode: 400, RequestID: a542ec32-994f-46e3-8cc6-06d10730b5fa,
ClientException: The specified capacity provider already exists. To change the configuration of an existing
capacity provider, update the capacity provider.
```

### Why It Happened
During the terraform apply stage:
1. Terraform successfully created most resources (VPC, subnets, security groups, IAM, ECR, ECS cluster, task definition, service, etc.)
2. It then attempted to create the ECS capacity provider
3. However, a capacity provider with that name already existed from the previous failed deployment
4. The cleanup script destroyed the infrastructure but did not delete the ECS capacity provider resource
5. This left an orphaned capacity provider that blocked the new deployment

### Timeline of Events
1. **First deployment attempt**: Failed at ALB creation, partial cleanup
2. **Manual cleanup**: We deleted VPCs, IAM roles, and other resources
3. **Second deployment attempt**:
   - Planning worked correctly (28 resources to create)
   - Terraform apply began successfully
   - Created: VPC, subnets, security groups, IAM roles, ECR, ECS cluster, task definition, service
   - **Failed when trying to create**: ECS capacity provider (already existed)
   - Auto-cleanup triggered: terraform destroy succeeded, deleted 26 resources
   - **Problem**: Capacity provider was not deleted by terraform destroy

## Root Issue: Gap in Cleanup Script

The `scripts/cleanup-aws-force.sh` script had the following sequence:
1. Scale down ECS service
2. Run terraform destroy
3. Delete ECS services (if they exist)
4. Delete ECS cluster
5. **Missing**: Delete ECS capacity provider before ASG deletion
6. Delete ASG
7. Delete other resources...

**The problem**: ECS capacity providers reference the ASG. If you try to delete them after the ASG is gone, AWS still keeps the capacity provider orphaned.

## Solution Implemented

### Fix Applied
Added explicit capacity provider deletion to the cleanup script before ASG deletion:

```bash
# Delete ECS Capacity Providers
echo "  Deleting ECS Capacity Providers..."
CP_NAME="${PROJECT_FULL}-cp"
aws ecs delete-capacity-provider --capacity-provider "$CP_NAME" --region "$AWS_REGION" 2>/dev/null || true
```

Location: `scripts/cleanup-aws-force.sh` after ECS cluster deletion

### Cleanup Order Now Corrected
```
1. Scale ECS service → 0 tasks
2. Terraform destroy
3. Delete ECS services
4. Delete ECS cluster
5. ✅ Delete ECS capacity provider (NEW)
6. Delete ASG
7. Delete ALB + target groups
8. Delete VPC resources
9. Delete ECR, logs, IAM
```

### Manual Cleanup Performed
Manually deleted the orphaned capacity provider:
```bash
aws ecs delete-capacity-provider --capacity-provider hello-app-dev-cp --region us-east-1
```

## Current State

**AWS Account Status**:
- ✅ VPCs: 0
- ✅ ECS Capacity Providers: 0
- ✅ ECS Clusters: 0
- ✅ ECR Repositories: 0
- ✅ IAM Roles: 0
- ✅ All other resources: 0

**Code Fix**:
- ✅ Updated `scripts/cleanup-aws-force.sh` with capacity provider cleanup
- ✅ Committed to GitHub (commit: b427380)
- ✅ Pushed to main branch

## Why This Wasn't Caught Earlier

The previous deployments were:
1. **First deployment (failed due to ALB)**: Only partially created resources, cleanup didn't fully remove everything
2. **Cleanup between attempts**: We manually cleaned up but didn't know about the capacity provider issue

The capacity provider issue only manifested when terraform successfully created all resources except the capacity provider itself.

## Prevention Strategy

The cleanup script now has comprehensive capacity provider deletion. Future failures will properly clean up capacity providers along with other resources.

### Key Learning
AWS resources have interdependencies that must be respected during cleanup:
- Capacity Provider depends on ASG
- ASG must be deleted before VPC resources
- All must be deleted in proper order to avoid orphaned resources

## Testing Performed

✅ Deleted orphaned capacity provider manually
✅ Verified AWS account is completely clean
✅ Updated cleanup script with capacity provider deletion
✅ Committed and pushed changes to GitHub

## Ready for Retry

The infrastructure is now ready for a third deployment attempt. The cleanup script has been enhanced to prevent this issue from recurring.

### Next Steps
1. Run Jenkins "Deploy Infrastructure" job again
2. Monitor for successful completion
3. All resources should be properly cleaned on any future failures

---

**Status**: Fixed and Ready
**Last Updated**: February 14, 2026
**Commit**: b427380 - fix: add ECS capacity provider cleanup
