# Tomorrow's TODO - Jenkins Pipeline Refactor

## Current Status (End of Day)
✅ Infrastructure: Deployed and verified (now tearing down)
✅ CI/CD Pipeline: First complete build successful
✅ Docker Image: Built and pushed to ECR
✅ ECS Deployment: Application running on AWS
✅ Documentation: Issues documented and solution guides created

## Tomorrow's Task: Refactor Jenkins Pipeline

The current `spring-boot-ecs-hello` job runs everything in one pipeline. We need to split it into 5 separate jobs for better control and flexibility.

---

## Step-by-Step TODO

### Phase 1: Understand the Refactor Plan (5 min)
- [ ] Read: `docs/JENKINS_REFACTOR_PLAN.md`
- [ ] Understand the 5 new jobs to create
- [ ] Review the workflow diagram

### Phase 2: Deploy Fresh Infrastructure (5-10 min)
**Before creating jobs, we need AWS resources to test against:**
```bash
cd terraform
terraform apply -auto-approve
```
- This creates ECS cluster, ALB, VPC, etc.
- Wait for deployment to complete

### Phase 3: Create Job 1 - `build-and-push-to-ecr` (30 min)
**Purpose**: Build, test, containerize, and push image to ECR (replaces current full pipeline)

**Steps**:
1. Rename current `spring-boot-ecs-hello` job to `build-and-push-to-ecr`
   - Go to Jenkins job configuration
   - Change name to `build-and-push-to-ecr`
   - Keep the current Jenkinsfile as is
2. Verify it still builds and pushes successfully:
   - Click **Build Now**
   - Check Console Output
   - Verify image appears in ECR

### Phase 4: Create Job 2 - `check-deployment-status` (20 min)
**Purpose**: Check if application is deployed and current status

**Configuration**:
- Job name: `check-deployment-status`
- Type: Pipeline
- Trigger: Manual only (no webhook)
- Pipeline script: Inline (see below)

**Script** (use this inline):
```groovy
pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
    }

    stages {
        stage('Check ECS Service') {
            steps {
                script {
                    withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                        sh '''
                            echo "=== ECS Service Status ==="
                            aws ecs describe-services \
                              --cluster hello-app-dev-cluster \
                              --services hello-app-dev-service \
                              --region ${AWS_REGION} \
                              --query 'services[0].[serviceName,status,runningCount,desiredCount]' \
                              --output table

                            echo ""
                            echo "=== Recent Events ==="
                            aws ecs describe-services \
                              --cluster hello-app-dev-cluster \
                              --services hello-app-dev-service \
                              --region ${AWS_REGION} \
                              --query 'services[0].events[0:3].[createdAt,message]' \
                              --output table
                        '''
                    }
                }
            }
        }

        stage('Check ALB Health') {
            steps {
                script {
                    withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                        sh '''
                            echo "=== ALB Status ==="
                            aws elbv2 describe-load-balancers \
                              --region ${AWS_REGION} \
                              --query "LoadBalancers[?LoadBalancerName=='hello-app-dev-alb'].[DNSName,State.Code]" \
                              --output table

                            echo ""
                            echo "=== Target Health ==="
                            TG_ARN=$(aws elbv2 describe-target-groups \
                              --region ${AWS_REGION} \
                              --names hello-app-dev-tg \
                              --query 'TargetGroups[0].TargetGroupArn' \
                              --output text)

                            aws elbv2 describe-target-health \
                              --target-group-arn $TG_ARN \
                              --region ${AWS_REGION} \
                              --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Description]' \
                              --output table
                        '''
                    }
                }
            }
        }
    }
}
```

### Phase 5: Create Job 3 - `deploy-to-ecs` (20 min)
**Purpose**: Deploy latest ECR image to ECS

**Configuration**:
- Job name: `deploy-to-ecs`
- Type: Pipeline
- Trigger: Manual only
- Pipeline script: Inline (see below)

**Script**:
```groovy
pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
    }

    stages {
        stage('Deploy') {
            steps {
                script {
                    withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                        sh '''
                            echo "Deploying latest image to ECS..."
                            aws ecs update-service \
                              --cluster hello-app-dev-cluster \
                              --service hello-app-dev-service \
                              --force-new-deployment \
                              --region ${AWS_REGION}

                            echo "Deployment initiated. Waiting for tasks to stabilize..."
                            aws ecs wait services-stable \
                              --cluster hello-app-dev-cluster \
                              --services hello-app-dev-service \
                              --region ${AWS_REGION}

                            echo "✅ Deployment completed!"
                        '''
                    }
                }
            }
        }
    }
}
```

### Phase 6: Create Job 4 - `teardown-infrastructure` (15 min)
**Purpose**: Destroy all AWS resources

**Configuration**:
- Job name: `teardown-infrastructure`
- Type: Pipeline
- Trigger: Manual only
- Pipeline script: Inline (see below)

**Script**:
```groovy
pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
    }

    stages {
        stage('Confirm Teardown') {
            steps {
                script {
                    input(message: 'Destroy all AWS resources?', ok: 'Yes, destroy everything')
                }
            }
        }

        stage('Scale to Zero') {
            steps {
                script {
                    withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                        sh '''
                            echo "Scaling ECS service to 0..."
                            aws ecs update-service \
                              --cluster hello-app-dev-cluster \
                              --service hello-app-dev-service \
                              --desired-count 0 \
                              --region ${AWS_REGION}

                            echo "Waiting for tasks to stop..."
                            aws ecs wait services-stable \
                              --cluster hello-app-dev-cluster \
                              --services hello-app-dev-service \
                              --region ${AWS_REGION}

                            echo "✅ All tasks stopped"
                        '''
                    }
                }
            }
        }

        stage('Destroy Infrastructure') {
            steps {
                sh '''
                    cd terraform
                    echo "Destroying infrastructure with Terraform..."
                    terraform destroy -auto-approve
                    echo "✅ Infrastructure destroyed"
                '''
            }
        }
    }
}
```

### Phase 7: Test All Jobs (30 min)
1. **Test `build-and-push-to-ecr`**:
   - Click Build Now
   - Verify it completes successfully
   - Check ECR has new image

2. **Test `check-deployment-status`**:
   - Click Build Now
   - Verify it shows service status
   - Verify it shows ALB and targets

3. **Test `deploy-to-ecs`**:
   - Click Build Now
   - Verify deployment completes
   - Use `check-deployment-status` to verify tasks running

4. **Test `teardown-infrastructure`**:
   - Click Build Now
   - Confirm the prompt
   - Verify it completes without errors
   - Check AWS console shows no resources

### Phase 8: Document the Refactor (10 min)
Create `docs/JENKINS_JOBS.md` with:
- Overview of each job
- How to use each job
- Typical workflow examples
- Troubleshooting tips

---

## Typical Workflow (After Refactor)

### Morning - Start Work
```bash
# 1. Deploy infrastructure
# Jenkins: Run "deploy-infrastructure" (if not already running)

# 2. Check status
# Jenkins: Run "check-deployment-status"
# Output shows current state

# 3. Make code changes locally
vim src/main/java/.../HelloController.java

# 4. Push to GitHub
git add . && git commit -m "Update message" && git push origin main

# 5. Build and push new image
# Jenkins: Run "build-and-push-to-ecr"
# Waits for build to complete

# 6. Check what's deployed
# Jenkins: Run "check-deployment-status"
# Output: Shows old version still running

# 7. Deploy new version
# Jenkins: Run "deploy-to-ecs"
# Waits for deployment to complete

# 8. Verify new version
curl $(cd terraform && terraform output -raw alb_url)/hello
```

### Evening - Before Sleep
```bash
# 1. Check status one more time
# Jenkins: Run "check-deployment-status"

# 2. Tear down to save money
# Jenkins: Run "teardown-infrastructure"
# Confirm the prompt
# Wait for completion
```

### Next Morning
```bash
# 1. Re-deploy infrastructure
# Jenkins: Run "deploy-infrastructure"

# 2. Continue work from step 3 above
```

---

## Files to Review Before Starting

1. `docs/JENKINS_REFACTOR_PLAN.md` - The refactor plan
2. `docs/ISSUE_JENKINS_SCRIPT_SECURITY_SANDBOX.md` - Shell over Groovy
3. `Jenkinsfile` - Current working pipeline (reference)

## Files to Create Tomorrow

1. `Jenkinsfile.build` - Build stage (extract from Jenkinsfile)
2. `Jenkinsfile.deploy` - Deploy stage (extract from Jenkinsfile)
3. `Jenkinsfile.check` - Check deployment status (new)
4. `Jenkinsfile.teardown` - Teardown infrastructure (new)
5. `docs/JENKINS_JOBS.md` - Job documentation (new)

---

## Estimated Time: 2-3 hours

- Phase 1: 5 min
- Phase 2: 5-10 min
- Phase 3: 30 min
- Phase 4: 20 min
- Phase 5: 20 min
- Phase 6: 15 min
- Phase 7: 30 min
- Phase 8: 10 min

**Total**: ~2.5-3 hours

---

## Before You Start Tomorrow

1. Run teardown script (manual terminal command): `yes | ./scripts/teardown-aws.sh`
2. Verify infrastructure is destroyed: `aws ecs describe-clusters --region us-east-1`
3. Read `JENKINS_REFACTOR_PLAN.md`
4. Review issues documentation
5. Have Jenkinsfile open for reference

---

## Questions to Answer

- Do you want all 5 jobs or a subset?
- Should `deploy-infrastructure` job be created? (currently manual)
- Any additional status checks needed in `check-deployment-status`?
- Should jobs send email notifications?
- Should jobs have approval gates?

---

**Good luck! You've got this! 🚀**

