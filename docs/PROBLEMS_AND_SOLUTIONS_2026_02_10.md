# Problems & Solutions - February 10, 2026

## Session Summary
Successfully completed 3 Jenkins service control jobs (bring-up, bring-down, teardown) with full parameter support, fixed Groovy escaping issues, restored Terraform state, and properly destroyed AWS infrastructure.

---

## Problems Encountered & Solutions

### 1. Groovy String Variable Escaping in Jenkins Declarative Pipeline

**Problem:**
```
org.codehaus.groovy.control.MultipleCompilationErrorsException: illegal string body character after dollar sign
```

When using triple-quoted strings `"""..."""` with embedded shell commands, Groovy tries to interpolate `${}` variables, causing syntax errors.

**Root Cause:**
- Groovy interprets `${VAR}` inside triple-quoted strings as variable interpolation
- When shell commands also use `$()` for command substitution, the escaping becomes complex
- Single `\$` escape is insufficient within triple quotes

**Solution:**
Use single quotes with string concatenation:
```groovy
// WRONG - causes escaping issues
sh """
    cd ${TERRAFORM_DIR}
    RUNNING=\$(aws ecs describe-services --query "services[0].runningCount" --output text)
"""

// CORRECT - no escaping issues
sh '''
    cd ''' + TERRAFORM_DIR + '''
    RUNNING=$(aws ecs describe-services --query services[0].runningCount --output text)
'''
```

**Why it works:**
- Single quotes `'''` prevent Groovy from interpreting any `$` characters
- String concatenation `''' + VAR + '''` passes actual variable values at runtime
- Shell script uses regular `$()` and `$VAR` without escaping

**Files Fixed:**
- `jenkins/Jenkinsfile.bring-down` (5 shell blocks)
- `jenkins/Jenkinsfile.bring-up` (2 shell blocks)
- `jenkins/Jenkinsfile.teardown` (4 shell blocks)

**Impact:** All 3 jobs now execute without Groovy compilation errors.

---

### 2. Terraform State File Empty/Missing in Jenkins Workspace

**Problem:**
```
No changes. No objects need to be destroyed.
Either you have not created any objects yet or the existing objects were already deleted outside of Terraform.
```

Terraform had no record of resources even though AWS infrastructure existed.

**Root Cause:**
- `terraform.tfstate` was in `.gitignore` (correct for local dev)
- When Jenkins checked out the repo, it got a clean working directory
- Jenkins ran `terraform init` which created a new empty state file
- The actual state file with resource tracking stayed only on local machine

**Solution:**
1. Modified `.gitignore` to allow tracking of state files (with comments explaining why)
2. Committed `terraform/terraform.tfstate` and `terraform/terraform.tfstate.backup` to repo
3. Restored the state from backup when it got corrupted
4. Added verification to teardown job to check state file size

**Git Changes:**
```
# .gitignore
# OLD
terraform/terraform.tfstate
terraform/terraform.tfstate.backup

# NEW (commented out)
# terraform/terraform.tfstate
# terraform/terraform.tfstate.backup
```

**Impact:** Terraform now properly tracks and destroys all infrastructure.

---

### 3. Terraform State File Corrupted to Empty State

**Problem:**
State file size reduced from 56,348 bytes to 182 bytes with `"resources": []`

**Root Cause:**
- First teardown attempt ran but failed partway through
- Terraform's state management corrupted/truncated the file
- Subsequent runs saw empty state

**Solution:**
Restored from backup:
```bash
cp terraform/terraform.tfstate.backup terraform/terraform.tfstate
```

**Better Solution for Future:**
Added backup stage in teardown job that creates timestamped backups before destruction.

**Impact:** Terraform could now properly read resources and destroy them.

---

### 4. Load Balancer Not Destroyed by Terraform

**Problem:**
```
Destroy complete! Resources: 14 destroyed.
# But ALB still existed
⚠ Load balancers still exist
```

**Root Cause:**
- Terraform destroy completed successfully but ALB remained
- Possible dependency ordering issue or resource stuck in AWS
- ALB needed explicit deletion

**Solution:**
Added force delete step after Terraform destroy:
```groovy
sh '''
    echo "Force deleting load balancers..."
    ALB_ARNS=$(aws elbv2 describe-load-balancers --region ${AWS_REGION} \
        --query 'LoadBalancers[?contains(LoadBalancerName, `${PROJECT_NAME}`)].LoadBalancerArn' \
        --output text)
    for ARN in $ALB_ARNS; do
        aws elbv2 delete-load-balancer --load-balancer-arn "$ARN" --region ${AWS_REGION}
    done
'''
```

**Impact:** ALBs and target groups now forcefully deleted as part of teardown.

---

### 5. Jenkins Job Parameter Display Issues

**Problem:**
Parameters didn't show up when clicking "Build Now"

**Causes Investigated:**
- Script path not matching exactly (fixed: used `jenkins/Jenkinsfile.bring-down`)
- Repository credentials issues (verified working)
- Pipeline plugins not loaded (verified installed)
- Parameter syntax in Jenkinsfile (verified correct)

**Solution:**
All three issues had different root causes:
1. **Script path**: Must match exact repo path
2. **Escaping errors**: Fixed with single-quote concatenation approach
3. **Repository connectivity**: Jenkins → GitHub SSH/HTTPS working

**Impact:** All 3 jobs now properly display their parameters on first click.

---

## Lessons Learned

### 1. Groovy vs Shell Escaping is Complex
- Triple quotes `"""` allow Groovy interpolation (problematic for shell)
- Single quotes `'''` with concatenation is cleaner than escaping
- Always test parameter-heavy scripts locally first

### 2. Terraform State Must be Tracked for Jenkins Deployment
- State files should be in version control for CI/CD systems
- Create backups before destructive operations
- Include verification steps to catch state corruption early

### 3. AWS Resource Dependencies
- Some resources (ALB) may not delete even when dependencies cleared
- Force delete is more reliable than relying on Terraform
- Add cleanup sweeps for stubborn resources

### 4. Jenkins Pipeline Testing
- Test inline scripts first, then convert to SCM
- Verify parameters appear before running destructive jobs
- Use echo statements extensively for debugging

---

## Architecture Decisions Made

### 1. SCM-Based Jobs Over Inline
**Decision:** All jobs pull from repository instead of inline scripts

**Why:**
- Single source of truth
- Auto-update when code changes
- Easier to version control and test
- Consistent across team

### 2. State File in Repository
**Decision:** Track `terraform.tfstate` in Git (with warning comment)

**Why:**
- Jenkins needs access to state without manual setup
- Enables CI/CD to manage infrastructure
- Backups in same repo as code

### 3. Force Delete Cleanup
**Decision:** Add AWS CLI cleanup after Terraform destroy

**Why:**
- Terraform may miss some resources
- Better guarantee of complete cleanup
- Prevents stranded resources increasing costs

---

## Test Cases That Should Pass

- [ ] bring-up-services: Parameters show correctly
- [ ] bring-up-services: Dropdown selector works (1-5 options)
- [ ] bring-down-services: Required checkbox prevents execution
- [ ] bring-down-services: Tasks scale to 0
- [ ] teardown-infrastructure: Confirmation required
- [ ] teardown-infrastructure: All 14 resources destroyed
- [ ] teardown-infrastructure: ALB force-deleted
- [ ] teardown-infrastructure: Verification shows clean state

---

## Configuration Reference

### Environment Variables
```
AWS_REGION = 'us-east-1'
PROJECT_NAME = 'hello-app'
ENVIRONMENT = 'dev'
```

### Resource Names (for grep/filtering)
```
ECS Cluster: hello-app-dev-cluster
ECS Service: hello-app-dev-service
ECR Repository: hello-app-dev
ALB Name: hello-app-dev-alb
Target Group: hello-app-dev-tg
```

### Key Paths
```
Terraform: terraform/
Jenkinsfiles: jenkins/
Documentation: docs/
```

---
