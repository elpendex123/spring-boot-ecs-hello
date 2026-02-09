# Jenkins Pipeline Refactor - TODO for Tomorrow

## Overview
The current `spring-boot-ecs-hello` pipeline runs all stages in one job. This needs to be split into separate jobs for better control and flexibility.

## Current Single Pipeline
- Initialize AWS
- Build (Gradle)
- Test (JUnit)
- Docker Build
- Push to ECR
- Deploy to ECS
- Cleanup

**Problem**: All or nothing. If infrastructure already exists, you can't selectively deploy.

## Desired Job Structure

### Job 1: `build-and-push-to-ecr` (Replaces current full pipeline)
**Purpose**: Build, test, containerize, and push to ECR
**Stages**:
1. Initialize AWS
2. Checkout
3. Build (Gradle)
4. Test (JUnit)
5. Docker Build
6. Push to ECR
7. Cleanup

**Output**: Docker image in ECR tagged with build number and `latest`

**Configuration**:
- Manual trigger only (no webhook)
- Build Triggers: None
- Pipeline: From SCM (git)
- Script Path: `Jenkinsfile.build`

---

### Job 2: `check-deployment-status`
**Purpose**: Check if application is deployed and get current status
**Stages**:
1. Check ECS service status
2. Check ALB status
3. Check target health
4. Get deployment info

**Output**: Console shows:
- ECS running tasks vs desired
- Target health status
- ALB DNS name
- Latest deployment info

**Configuration**:
- Manual trigger only
- Pipeline: Inline script (not from SCM)

---

### Job 3: `deploy-to-ecs`
**Purpose**: Deploy latest ECR image to ECS service
**Stages**:
1. Initialize AWS
2. Check if image exists in ECR
3. Verify ECS cluster exists
4. Update ECS service with force-new-deployment
5. Wait for deployment to stabilize
6. Verify new deployment

**Output**:
- Deployment status
- New task count
- Health check results

**Configuration**:
- Manual trigger only
- Pipeline: Inline script (needs to ask for image tag: latest or specific build number)

---

### Job 4: `teardown-infrastructure`
**Purpose**: Destroy all AWS resources
**Stages**:
1. Scale ECS service to 0 (graceful shutdown)
2. Wait for tasks to stop
3. Run terraform destroy with confirmation
4. Verify all resources destroyed

**Output**: Confirmation that all resources are destroyed

**Configuration**:
- Manual trigger only
- Pipeline: Inline script
- Add confirmation prompt

---

### Job 5: `deploy-infrastructure` (Optional)
**Purpose**: Create fresh infrastructure from Terraform
**Stages**:
1. Verify Terraform files
2. Run terraform init
3. Run terraform plan
4. Run terraform apply with approval
5. Get outputs (ALB URL, ECR repo, etc.)

**Output**: Infrastructure deployed, shows ALB URL and ECR repository

**Configuration**:
- Manual trigger only
- Pipeline: Inline script

---

## Implementation Order (Tomorrow)

1. **Create `Jenkinsfile.build`** - Extract build stages from current Jenkinsfile
2. **Create `Jenkinsfile.deploy`** - Deploy stage only
3. **Create `check-deployment-status` job** - Inline pipeline script
4. **Create `teardown-infrastructure` job** - Inline pipeline script
5. **Update/rename current job** - Rename to `build-and-push-to-ecr`
6. **Test each job** - Verify each works independently
7. **Document job workflows** - How to use each job

---

## Workflow Tomorrow

### Typical Development Flow

**Day 1 - Setup**:
- Run `deploy-infrastructure` → creates AWS resources
- Run `build-and-push-to-ecr` → builds and pushes Docker image
- Run `deploy-to-ecs` → deploys to ECS

**Day 2+ - Code Changes**:
- Make code changes locally
- Commit and push to GitHub
- Run `build-and-push-to-ecr` (builds new image, pushes to ECR)
- Run `check-deployment-status` (verify current state)
- Run `deploy-to-ecs` (deploys new image)

**Before Sleep**:
- Run `check-deployment-status` (verify everything is running)
- Run `teardown-infrastructure` (destroy AWS resources to save money)

**Next Day**:
- Run `deploy-infrastructure` (recreate AWS resources)
- Run `build-and-push-to-ecr` (build and push)
- Run `deploy-to-ecs` (deploy)

---

## Files to Create/Modify

| File | Status | Purpose |
|------|--------|---------|
| `Jenkinsfile` | Keep | Current full pipeline (for reference) |
| `Jenkinsfile.build` | Create | Build + Push to ECR stages |
| `Jenkinsfile.deploy` | Create | Deploy to ECS stage |
| `Jenkinsfile.check` | Create | Check deployment status |
| `Jenkinsfile.teardown` | Create | Teardown infrastructure |
| `docs/JENKINS_JOBS.md` | Create | Documentation for each job |

---

## Benefits of Refactor

✅ **Flexibility**: Deploy without rebuilding
✅ **Safety**: Check status before deploying
✅ **Cost Control**: Explicit teardown job
✅ **Debugging**: Isolate issues by stage
✅ **Reusability**: Each job can run independently
✅ **Workflow**: Clear process for daily development

---

## Next Steps

1. Read this document
2. Decide if you want all 5 jobs or subset
3. Start implementing `Jenkinsfile.build` first
4. Create corresponding Jenkins jobs
5. Test each job independently
6. Update documentation

---

**Estimated Time**: 2-3 hours to implement all jobs

