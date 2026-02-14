# Pre-Deployment Checklist

## ✅ Completed Items

### Infrastructure Cleanup
- [x] All VPCs deleted from us-east-1 region
- [x] All orphaned ECR repositories deleted
- [x] All orphaned ECS clusters/services deleted
- [x] All orphaned IAM roles/instance profiles deleted
- [x] All orphaned EC2 instances terminated
- [x] AWS account verified clean

### Code Fixes Applied
- [x] Fixed hardcoded port in health check (using variable reference)
- [x] Removed unsupported `assign_public_ip` parameter from ECS service
- [x] Created comprehensive cleanup script
- [x] Integrated cleanup script into Jenkinsfile failure handling
- [x] Verified all Terraform files exist and are properly configured
- [x] Verified Spring Boot application files exist

### Jenkins Configuration
- [x] AWS credentials configured (aws-credentials)
- [x] Email notifications configured
- [x] Docker permissions configured for Jenkins user
- [x] Jenkinsfile.deploy-infra with cleanup integrated

### Documentation
- [x] DEPLOYMENT_STATUS.md created with comprehensive status
- [x] PRE_DEPLOYMENT_CHECKLIST.md created (this file)
- [x] All issues documented and resolved

---

## Ready to Deploy

All prerequisites have been met. The infrastructure is ready for deployment.

### To Deploy
```bash
# Open Jenkins at http://localhost:8080
# Navigate to: spring-boot-ecs-hello job
# Click: Build Now

# Monitor the console output for progress
```

### Expected Timeline
- Build + Test: ~2 minutes
- Docker Build: ~1 minute
- ECR Push: ~1 minute
- Terraform Apply: ~5-10 minutes
- Infrastructure Verification: ~2 minutes
- **Total**: ~10-15 minutes

### After Deployment
```bash
# Get the ALB URL
cd terraform
ALB_URL=$(terraform output -raw alb_url)

# Test the endpoints
curl $ALB_URL/hello
curl $ALB_URL/hello?name=TestUser
curl $ALB_URL/actuator/health

# View logs
aws logs tail /ecs/hello-app-dev --follow --region us-east-1
```

---

## On Deployment Failure

**Do NOT manually delete resources.** The automated cleanup script will:
1. Scale down ECS service
2. Run terraform destroy
3. Force delete orphaned resources
4. Return account to clean state

You will receive an email notification with failure details.

---

## Verification Checklist (Post-Deployment)

After successful deployment, verify:
- [ ] Jenkins job completed with SUCCESS status
- [ ] Email notification received with success message
- [ ] terraform-outputs.txt file created with resource details
- [ ] Can access `/hello` endpoint via ALB URL
- [ ] CloudWatch logs show application startup messages
- [ ] ECS service shows running tasks in AWS console
- [ ] Target group shows healthy targets
- [ ] Load balancer is active

---

## Rollback/Cleanup

If you need to destroy the infrastructure:

**Option 1: Manual Cleanup**
```bash
cd terraform
terraform destroy -auto-approve
```

**Option 2: Using Cleanup Script**
```bash
./scripts/cleanup-aws-force.sh hello-app dev us-east-1
```

**Option 3: Jenkins Failure (Automatic)**
Infrastructure will auto-cleanup on any deployment failure.

---

## Support Contacts

- **Email**: kike.ruben.coello@gmail.com
- **Project**: spring-boot-ecs-hello
- **Region**: us-east-1

## Deployment Date

**Scheduled**: Whenever user runs Jenkins "Deploy Infrastructure" job
**Status**: Ready to deploy
**Last Updated**: February 14, 2026

---

**⚠️ WARNING**: Do not attempt manual resource deletions. Let automation handle cleanup to prevent orphaned resources.
