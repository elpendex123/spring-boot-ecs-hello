# Jenkins Pipeline Files

All Jenkins pipeline files for the 8 independent CI/CD jobs.

## Files Overview

### 1. Jenkinsfile.build
Build Spring Boot application, run tests, create Docker image, and push to ECR.
- **Purpose:** Build & push Docker image
- **Type:** SCM-based (from repository)
- **Script Path:** `jenkins/Jenkinsfile.build`
- **Stages:** Initialize AWS, Checkout, Build, Test, Docker Build, Push to ECR
- **Time:** ~8 minutes

### 2. Jenkinsfile.deploy
Deploy Docker image from ECR to ECS service.
- **Purpose:** Deploy to ECS
- **Type:** SCM-based
- **Script Path:** `jenkins/Jenkinsfile.deploy`
- **Parameters:** IMAGE_TAG (text), WAIT_FOR_DEPLOYMENT (checkbox)
- **Stages:** Initialize AWS, Verify Image, Verify Cluster, Update Service, Wait, Verify
- **Time:** ~4 minutes

### 3. Jenkinsfile.check-status
Get comprehensive view of current deployment status.
- **Purpose:** Check deployment status
- **Type:** Inline script (paste contents directly)
- **Stages:** Check ECS Service, Check ALB, Check Targets, Check ECR, Get URL, Check Events
- **Time:** ~30 seconds

### 4. Jenkinsfile.service-status
Quick check if ECS service is UP or DOWN.
- **Purpose:** Quick service status check
- **Type:** Inline script
- **Output:** UP/DOWN/PARTIAL status
- **Time:** ~15 seconds

### 5. Jenkinsfile.bring-up
Scale up ECS tasks to bring services online.
- **Purpose:** Scale up services
- **Type:** Inline script
- **Parameters:** DESIRED_TASK_COUNT (dropdown: 1-5), WAIT_FOR_STABLE (checkbox)
- **Stages:** Initialize AWS, Check Status, Bring Up, Wait, Verify
- **Time:** ~2 minutes

### 6. Jenkinsfile.bring-down
Scale down ECS tasks to save costs (graceful shutdown).
- **Purpose:** Scale down services
- **Type:** Inline script
- **Parameters:** CONFIRM_SHUTDOWN (checkbox - REQUIRED), WAIT_FOR_SHUTDOWN (checkbox)
- **Stages:** Confirmation, Initialize AWS, Check Status, Bring Down, Wait, Verify
- **Time:** ~2 minutes
- **Safety:** Requires confirmation checkbox

### 7. Jenkinsfile.teardown
Destroy all AWS infrastructure (VPC, ALB, ECS, EC2, ECR, etc.).
- **Purpose:** Destroy infrastructure
- **Type:** Inline script
- **Parameters:** 4 checkboxes (DESTROY_INFRASTRUCTURE required)
- **Stages:** Confirmation, Scale Down, Delete ECR, Backup, Destroy, Verify
- **Time:** ~12 minutes
- **Warning:** IRREVERSIBLE - deletes all resources
- **Safety:** Requires confirmation checkbox

### 8. Jenkinsfile.deploy-infra
Create AWS infrastructure from Terraform.
- **Purpose:** Create infrastructure
- **Type:** SCM-based
- **Script Path:** `jenkins/Jenkinsfile.deploy-infra`
- **Parameters:** AUTO_APPROVE (checkbox), SKIP_PLAN (checkbox)
- **Stages:** Initialize AWS, Checkout, Verify, Terraform Init/Format/Validate/Plan/Apply/Capture/Verify
- **Time:** ~8 minutes

## Directory Structure

```
jenkins/
├── README.md                    (This file)
├── Jenkinsfile.build            (Job 1: Build & push)
├── Jenkinsfile.deploy           (Job 2: Deploy to ECS)
├── Jenkinsfile.check-status     (Job 3: Check status)
├── Jenkinsfile.service-status   (Job 4: Quick check)
├── Jenkinsfile.bring-up         (Job 5: Scale up - dropdown)
├── Jenkinsfile.bring-down       (Job 6: Scale down - checkbox)
├── Jenkinsfile.teardown         (Job 7: Destroy - checkboxes)
└── Jenkinsfile.deploy-infra     (Job 8: Deploy infra)
```

## Creating Jenkins Jobs

### For SCM-Based Jobs (1, 2, 8)

1. **New Item** → Pipeline
2. **Definition:** Pipeline script from SCM
3. **SCM:** Git
4. **Repository URL:** https://github.com/elpendex123/spring-boot-ecs-hello.git
5. **Branch Specifier:** `*/main`
6. **Script Path:** `jenkins/Jenkinsfile.build` (or `.deploy`, `.deploy-infra`)
7. Save

### For Inline Jobs (3, 4, 5, 6, 7)

1. **New Item** → Pipeline
2. **Definition:** Pipeline script
3. Copy entire file contents
4. Paste into Script field
5. Save

**See:** `docs/JENKINS_SETUP_GUIDE.md` for detailed step-by-step instructions

## File Sizes

- Jenkinsfile.build:          ~7 KB
- Jenkinsfile.deploy:        ~11 KB
- Jenkinsfile.check-status:  ~10 KB
- Jenkinsfile.service-status: ~6 KB
- Jenkinsfile.bring-up:      ~10 KB
- Jenkinsfile.bring-down:    ~11 KB
- Jenkinsfile.teardown:      ~15 KB
- Jenkinsfile.deploy-infra:  ~13 KB
- **Total:**                ~83 KB

## Documentation

See `docs/` directory for complete documentation:
- `docs/JENKINS_QUICK_START.md` - 5-minute quick reference
- `docs/JENKINS_SETUP_GUIDE.md` - Step-by-step setup (60 min)
- `docs/JENKINS_JOBS.md` - Complete job reference (800+ lines)
- `docs/JENKINS_IMPLEMENTATION_SUMMARY.md` - Features overview
- `docs/JENKINS_IMPLEMENTATION_COMPLETE.md` - Full summary

## Quick Start

1. Read: `docs/JENKINS_QUICK_START.md`
2. Setup: Follow `docs/JENKINS_SETUP_GUIDE.md`
3. Use: Follow typical daily workflow

## Tips

- **Keep Jenkinsfiles in sync** with documentation
- **Test after updating** Jenkinsfile
- **Use version control** for all changes
- **Reference** `docs/JENKINS_JOBS.md` for detailed info

---

**Version:** 1.0.0
**Last Updated:** February 2026
**Status:** Production Ready
