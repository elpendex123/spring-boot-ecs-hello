# Jenkins Jobs Setup Guide

Quick guide to create all 8 Jenkins jobs in your Jenkins instance.

## Prerequisites

- Jenkins running at http://localhost:8080
- AWS credentials configured (`aws-credentials`)
- Docker permission configured for Jenkins user
- Email notifications configured

---

## Jobs to Create

### 1. build-and-push-to-ecr (From SCM)

**Steps:**
1. Jenkins Dashboard → **New Item**
2. Job name: `build-and-push-to-ecr`
3. Type: **Pipeline**
4. Click **OK**
5. Configuration:
   - **Definition:** Pipeline script from SCM
   - **SCM:** Git
   - **Repository URL:** https://github.com/elpendex123/spring-boot-ecs-hello.git
   - **Branch Specifier:** `*/main`
   - **Script Path:** `jenkins/Jenkinsfile.build`
6. **Save**
7. Test: **Build Now**

---

### 2. deploy-to-ecs (From SCM)

**Steps:**
1. Jenkins Dashboard → **New Item**
2. Job name: `deploy-to-ecs`
3. Type: **Pipeline**
4. Click **OK**
5. Configuration:
   - **Definition:** Pipeline script from SCM
   - **SCM:** Git
   - **Repository URL:** https://github.com/elpendex123/spring-boot-ecs-hello.git
   - **Branch Specifier:** `*/main`
   - **Script Path:** `jenkins/Jenkinsfile.deploy`
6. **Save**
7. Test: **Build Now** (will ask for IMAGE_TAG parameter)

---

### 3. check-deployment-status (Inline Script)

**Steps:**
1. Jenkins Dashboard → **New Item**
2. Job name: `check-deployment-status`
3. Type: **Pipeline**
4. Click **OK**
5. Configuration:
   - **Definition:** Pipeline script
   - **Script:** (Copy entire contents of `jenkins/Jenkinsfile.check-status` and paste here)
6. **Save**
7. Test: **Build Now**

---

### 4. service-status (Inline Script)

**Steps:**
1. Jenkins Dashboard → **New Item**
2. Job name: `service-status`
3. Type: **Pipeline**
4. Click **OK**
5. Configuration:
   - **Definition:** Pipeline script
   - **Script:** (Copy entire contents of `jenkins/Jenkinsfile.service-status` and paste here)
6. **Save**
7. Test: **Build Now**

---

### 5. bring-up-services (Inline Script)

**Steps:**
1. Jenkins Dashboard → **New Item**
2. Job name: `bring-up-services`
3. Type: **Pipeline**
4. Click **OK**
5. Configuration:
   - **Definition:** Pipeline script
   - **Script:** (Copy entire contents of `jenkins/Jenkinsfile.bring-up` and paste here)
6. **Save**
7. Test: **Build Now** (will ask for DESIRED_TASK_COUNT parameter)

---

### 6. bring-down-services (Inline Script)

**Steps:**
1. Jenkins Dashboard → **New Item**
2. Job name: `bring-down-services`
3. Type: **Pipeline**
4. Click **OK**
5. Configuration:
   - **Definition:** Pipeline script
   - **Script:** (Copy entire contents of `jenkins/Jenkinsfile.bring-down` and paste here)
6. **Save**
7. Test: **Build Now** (will ask for CONFIRM_SHUTDOWN parameter)

---

### 7. teardown-infrastructure (Inline Script)

**Steps:**
1. Jenkins Dashboard → **New Item**
2. Job name: `teardown-infrastructure`
3. Type: **Pipeline**
4. Click **OK**
5. Configuration:
   - **Definition:** Pipeline script
   - **Script:** (Copy entire contents of `jenkins/Jenkinsfile.teardown` and paste here)
6. **Save**
7. Test: **Build Now** (will ask for multiple parameters)

---

### 8. deploy-infrastructure (Inline Script)

**Steps:**
1. Jenkins Dashboard → **New Item**
2. Job name: `deploy-infrastructure`
3. Type: **Pipeline**
4. Click **OK**
5. Configuration:
   - **Definition:** Pipeline script from SCM
   - **SCM:** Git
   - **Repository URL:** https://github.com/elpendex123/spring-boot-ecs-hello.git
   - **Branch Specifier:** `*/main`
   - **Script Path:** `jenkins/Jenkinsfile.deploy-infra`
6. **Save**
7. Test: **Build Now**

---

## Quick Copy-Paste for Inline Jobs

### For job 3: check-deployment-status

Open `jenkins/Jenkinsfile.check-status` in your repository and copy the entire contents.

In Jenkins:
1. Paste into Script field
2. Click Save

### For job 4: service-status

Open `jenkins/Jenkinsfile.service-status` in your repository and copy the entire contents.

In Jenkins:
1. Paste into Script field
2. Click Save

### For job 5: bring-up-services

Open `jenkins/Jenkinsfile.bring-up` in your repository and copy the entire contents.

In Jenkins:
1. Paste into Script field
2. Click Save

### For job 6: bring-down-services

Open `jenkins/Jenkinsfile.bring-down` in your repository and copy the entire contents.

In Jenkins:
1. Paste into Script field
2. Click Save

### For job 7: teardown-infrastructure

Open `jenkins/Jenkinsfile.teardown` in your repository and copy the entire contents.

In Jenkins:
1. Paste into Script field
2. Click Save

---

## Verify Jobs Created

After creating all jobs:

1. Go to Jenkins Dashboard
2. You should see these jobs listed:
   ```
   build-and-push-to-ecr
   deploy-to-ecs
   check-deployment-status
   service-status
   bring-up-services
   bring-down-services
   teardown-infrastructure
   deploy-infrastructure
   ```

3. Click on each job to verify parameters are visible

---

## Test Each Job

### Test 1: build-and-push-to-ecr
```
Click: Build Now
Wait: 6-10 minutes
Check: Console Output for ✓ success
```

### Test 2: deploy-to-ecs
```
Click: Build Now
Parameters appear:
  - IMAGE_TAG: latest
  - WAIT_FOR_DEPLOYMENT: checked
Click: Build
Wait: 2-5 minutes
Check: Console Output for ✓ success
```

### Test 3: check-deployment-status
```
Click: Build Now
Wait: 30-60 seconds
Check: Console Output shows full deployment status
```

### Test 4: service-status
```
Click: Build Now
Wait: 10-20 seconds
Check: Console Output shows UP/DOWN status
```

### Test 5: bring-up-services
```
Click: Build Now
Parameters appear:
  - DESIRED_TASK_COUNT: (dropdown with 1-5)
  - WAIT_FOR_STABLE: checked
Select: DESIRED_TASK_COUNT = 2
Click: Build
Wait: 1-3 minutes
Check: Console Output shows ✓ SERVICE UP
```

### Test 6: bring-down-services
```
Click: Build Now
Parameters appear:
  - CONFIRM_SHUTDOWN: unchecked
  - WAIT_FOR_SHUTDOWN: checked
Check: CONFIRM_SHUTDOWN
Click: Build
Wait: 1-2 minutes
Check: Console Output shows ✓ SERVICE DOWN
```

### Test 7: teardown-infrastructure
```
Click: Build Now
Parameters appear:
  - SCALE_DOWN_SERVICE: checked
  - DELETE_ECR_IMAGES: checked
  - DESTROY_INFRASTRUCTURE: unchecked
  - SAVE_TERRAFORM_STATE: checked
Check: DESTROY_INFRASTRUCTURE
Click: Build
Wait: 10-15 minutes
Check: Console Output shows ✓ DESTROYED
```

### Test 8: deploy-infrastructure
```
Click: Build Now
Parameters appear:
  - AUTO_APPROVE: unchecked
  - SKIP_PLAN: unchecked
Click: Build
Wait: 5-10 minutes
Check: Console Output shows ALB URL and ECR repo
```

---

## After Creating All Jobs

1. Verify all 8 jobs appear in Jenkins Dashboard
2. Run quick test on each job
3. Read `docs/JENKINS_JOBS.md` for detailed job descriptions
4. Bookmark Jenkins Dashboard for quick access
5. Create Slack/email shortcuts (optional)

---

## Quick Reference URLs

| Job | URL |
|-----|-----|
| Dashboard | http://localhost:8080/ |
| build-and-push-to-ecr | http://localhost:8080/job/build-and-push-to-ecr/ |
| deploy-to-ecs | http://localhost:8080/job/deploy-to-ecs/ |
| check-deployment-status | http://localhost:8080/job/check-deployment-status/ |
| service-status | http://localhost:8080/job/service-status/ |
| bring-up-services | http://localhost:8080/job/bring-up-services/ |
| bring-down-services | http://localhost:8080/job/bring-down-services/ |
| teardown-infrastructure | http://localhost:8080/job/teardown-infrastructure/ |
| deploy-infrastructure | http://localhost:8080/job/deploy-infrastructure/ |

---

## Troubleshooting Setup

### Pipeline Script Validation Error

**Error:** "org.jenkinsci.plugins.workflow.common.StepExecutionException"

**Fix:**
1. Go to **Manage Jenkins** → **Script Approval**
2. Approve any pending scripts
3. Retry job

---

### Parameter Not Showing

**For SCM-based jobs:**
1. Script Path must match exactly
2. Jenkinsfile must contain `parameters` block
3. Rebuild job configuration

**For inline jobs:**
1. Copy entire Jenkinsfile content
2. Ensure `parameters` section is included
3. Save and try again

---

### AWS Credentials Error

**Error:** "InvalidParameterException" or "Access Denied"

**Fix:**
1. Go to **Manage Jenkins** → **Manage Credentials**
2. Verify credential ID is `aws-credentials`
3. Test with this pipeline:
   ```groovy
   pipeline {
       agent any
       stages {
           stage('Test') {
               steps {
                   script {
                       withAWS(credentials: 'aws-credentials', region: 'us-east-1') {
                           sh 'aws sts get-caller-identity'
                       }
                   }
               }
           }
       }
   }
   ```

---

## Typical Setup Time

| Task | Time |
|------|------|
| Create all 8 jobs | 10-15 min |
| Test each job | 30-45 min |
| Verify everything working | 10 min |
| **Total** | **50-70 min** |

---

## Next Steps

1. Complete job creation (this guide)
2. Read `docs/JENKINS_JOBS.md` for details
3. Follow typical daily workflow:
   - Morning: bring-up-services → build-and-push-to-ecr → deploy-to-ecs
   - Evening: bring-down-services (save costs)
4. Bookmark Jenkins dashboard
5. Set up Slack notifications (optional)

---

**Ready to create jobs? Start with job #1: build-and-push-to-ecr**

---

**Last Updated:** February 2026
**Version:** 1.0.0
