# Jenkins Jobs - Quick Start Card

Fast reference for Jenkins job setup and usage.

---

## 8 Jobs Created

### SCM-Based (3 jobs - from repository)
| # | Job Name | Jenkinsfile | Purpose |
|---|----------|-------------|---------|
| 1 | build-and-push-to-ecr | `Jenkinsfile.build` | Build & push Docker image |
| 2 | deploy-to-ecs | `Jenkinsfile.deploy` | Deploy image to ECS |
| 8 | deploy-infrastructure | `Jenkinsfile.deploy-infra` | Create AWS resources |

### Inline (5 jobs - paste script directly)
| # | Job Name | Jenkinsfile | Purpose |
|---|----------|-------------|---------|
| 3 | check-deployment-status | `Jenkinsfile.check-status` | Full deployment status |
| 4 | service-status | `Jenkinsfile.service-status` | Quick UP/DOWN check |
| 5 | bring-up-services | `Jenkinsfile.bring-up` | Scale up (dropdown: 1-5) |
| 6 | bring-down-services | `Jenkinsfile.bring-down` | Scale down (checkbox confirm) |
| 7 | teardown-infrastructure | `Jenkinsfile.teardown` | Destroy all (checkboxes) |

---

## Setup (60 minutes)

### For Each SCM Job:
```
Jenkins → New Item → Pipeline
Definition: Pipeline script from SCM
SCM: Git
URL: https://github.com/elpendex123/spring-boot-ecs-hello.git
Script Path: Jenkinsfile.build (or .deploy, .deploy-infra)
```

### For Each Inline Job:
```
Jenkins → New Item → Pipeline
Definition: Pipeline script
(Copy entire Jenkinsfile content)
Save
```

**See:** `docs/JENKINS_SETUP_GUIDE.md` for detailed steps

---

## Daily Usage

### Morning (Start Services)
```
bring-up-services
  └─ DESIRED_TASK_COUNT: 2 (dropdown)
```

### Develop (Build & Deploy)
```
build-and-push-to-ecr
  └─ Wait 8 minutes
deploy-to-ecs
  └─ IMAGE_TAG: latest
  └─ Wait 4 minutes
```

### Check Anytime
```
service-status      (30 seconds)
    or
check-deployment-status (60 seconds)
```

### Evening (Save Money)
```
bring-down-services
  └─ Check: CONFIRM_SHUTDOWN
```

---

## Parameters at a Glance

| Job | Parameters |
|-----|-----------|
| build-and-push-to-ecr | None |
| deploy-to-ecs | `IMAGE_TAG` (text: "latest" default), `WAIT_FOR_DEPLOYMENT` (✓) |
| check-deployment-status | None |
| service-status | None |
| bring-up-services | `DESIRED_TASK_COUNT` (dropdown: 1-5), `WAIT_FOR_STABLE` (✓) |
| bring-down-services | `CONFIRM_SHUTDOWN` (checkbox req), `WAIT_FOR_SHUTDOWN` (✓) |
| teardown-infrastructure | 4 checkboxes (DESTROY_INFRASTRUCTURE required) |
| deploy-infrastructure | `AUTO_APPROVE` (☐), `SKIP_PLAN` (☐) |

**Legend:** ✓ = checked by default, ☐ = unchecked by default

---

## Build Times

```
build-and-push-to-ecr   ~8 min  (first time: 15 min)
deploy-to-ecs           ~4 min
check-deployment-status ~30 sec
service-status          ~15 sec
bring-up-services       ~2 min
bring-down-services     ~2 min
teardown-infrastructure ~12 min
deploy-infrastructure   ~8 min
```

---

## Safety Features

### Checkboxes Required (Default Unchecked)
- `bring-down-services` ← Must check to proceed
- `teardown-infrastructure` ← Must check DESTROY_INFRASTRUCTURE

Prevents accidental shutdown/deletion!

---

## Typical Workflows

### Full Setup (First Time)
```
deploy-infrastructure (5 min)
  ↓
build-and-push-to-ecr (8 min)
  ↓
deploy-to-ecs (4 min)
  ↓
check-deployment-status (1 min)
─────────────────────────
Total: ~18 minutes
```

### Daily Cycle
```
Morning:
  bring-up-services → build-and-push-to-ecr → deploy-to-ecs
  └─ ~15 minutes total

Evening:
  bring-down-services
  └─ Saves ~$1-2/hour
```

### Emergency Recovery
```
Service Down?
  └─ service-status (check status)
  └─ bring-up-services (start service)
  └─ check-deployment-status (verify)
  └─ ~5 minutes total
```

### Weekend Cleanup
```
Friday 5 PM:
  teardown-infrastructure (DESTROY_INFRASTRUCTURE: ✓)
  └─ Saves 100% for 2 days
Monday 9 AM:
  deploy-infrastructure → build → deploy
  └─ Fresh start!
```

---

## Quick Troubleshooting

| Problem | Check |
|---------|-------|
| Job not showing parameters | Verify Jenkinsfile syntax, Script Path correct |
| AWS credential error | Jenkins → Manage Credentials → verify `aws-credentials` |
| Docker permission denied | `sudo usermod -aG docker jenkins && sudo systemctl restart jenkins` |
| Service not starting | `aws logs tail /ecs/hello-app-dev` |
| Teardown fails | Check Console Output, may need manual cleanup in AWS |

**Full guide:** `docs/JENKINS_JOBS.md`

---

## Cost Optimization

```
✓ Without shutdown:  ~$50-70/month
✓ With nightly down: ~$30-40/month (40% savings)
✓ With weekend down: ~$20-25/month (60% savings)
```

**Strategy:** Always `bring-down-services` before leaving!

---

## URLs

| Item | URL |
|------|-----|
| Jenkins Dashboard | http://localhost:8080/ |
| Job 1 (build) | http://localhost:8080/job/build-and-push-to-ecr/ |
| Job 2 (deploy) | http://localhost:8080/job/deploy-to-ecs/ |
| Job 3 (check) | http://localhost:8080/job/check-deployment-status/ |
| Job 4 (status) | http://localhost:8080/job/service-status/ |
| Job 5 (up) | http://localhost:8080/job/bring-up-services/ |
| Job 6 (down) | http://localhost:8080/job/bring-down-services/ |
| Job 7 (teardown) | http://localhost:8080/job/teardown-infrastructure/ |
| Job 8 (deploy infra) | http://localhost:8080/job/deploy-infrastructure/ |

---

## Documentation

| Document | Purpose |
|----------|---------|
| `docs/JENKINS_SETUP_GUIDE.md` | Step-by-step job creation (60 min) |
| `docs/JENKINS_JOBS.md` | Detailed job reference (800+ lines) |
| `docs/JENKINS_IMPLEMENTATION_SUMMARY.md` | Overview and features |
| `JENKINS_QUICK_START.md` | This card |

---

## Checklist - First Time Setup

- [ ] Read this Quick Start
- [ ] Create 8 Jenkins jobs (follow JENKINS_SETUP_GUIDE.md)
- [ ] Test each job
- [ ] Bookmark Jenkins dashboard
- [ ] Run first full workflow:
  - deploy-infrastructure
  - build-and-push-to-ecr
  - deploy-to-ecs
  - check-deployment-status
- [ ] Read detailed docs for advanced usage

---

## Remember

✅ **Jobs are independent** - run in any order
✅ **Safe by default** - dangerous actions need confirmation
✅ **Fast feedback** - status jobs run in seconds
✅ **Cost conscious** - explicit shutdown job
✅ **Well documented** - 2000+ lines of guides
✅ **Email alerts** - know when jobs pass/fail

---

**Status:** Ready for Production
**Version:** 1.0.0
**Created:** February 2026

See `docs/JENKINS_JOBS.md` for complete documentation.
