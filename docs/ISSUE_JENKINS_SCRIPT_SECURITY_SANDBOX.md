# Issue: Jenkins Script Security Sandbox - docker.tag() Not Allowed

## Problem
Jenkins pipeline failed with error:
```
Scripts not permitted to use method groovy.lang.GroovyObject invokeMethod
java.lang.String java.lang.Object
(org.jenkinsci.plugins.docker.workflow.Docker tag org.codehaus.groovy.runtime.GStringImpl org.codehaus.groovy.runtime.GStringImpl)
```

This error occurred when using the Docker DSL plugin to tag images:
```groovy
stage('Docker Build') {
    steps {
        script {
            docker.build("${ECR_REPO_NAME}:${IMAGE_TAG}")
            docker.tag("${ECR_REPO_NAME}:${IMAGE_TAG}", "${ECR_REPO_NAME}:latest")  // ← BLOCKED
        }
    }
}
```

## Root Cause
Jenkins has a **script security sandbox** that restricts certain Groovy methods for security reasons. The `docker.tag()` method invocation was blocked because it's not whitelisted in the security policy.

The error message indicates:
- Method: `invokeMethod` on `groovy.lang.GroovyObject`
- Plugin: `docker.workflow`
- Jenkins is preventing this method call

## Why This Happens
Jenkins security sandbox protects against malicious pipeline code by:
1. Restricting access to certain methods
2. Requiring explicit approval from Jenkins administrator
3. Preventing reflection/dynamic method invocation

This can be solved by:
- **Option A**: Ask Jenkins admin to approve the method (not preferred)
- **Option B**: Use shell commands instead (preferred)

## Solution
**Replace Docker DSL with shell commands** - they don't trigger security sandbox restrictions.

### Before (Failed):
```groovy
stage('Docker Build') {
    steps {
        echo 'Building Docker image...'
        script {
            docker.build("${ECR_REPO_NAME}:${IMAGE_TAG}")
            docker.tag("${ECR_REPO_NAME}:${IMAGE_TAG}", "${ECR_REPO_NAME}:latest")
        }
    }
}
```

### After (Success):
```groovy
stage('Docker Build') {
    steps {
        echo 'Building Docker image...'
        sh '''
            docker build -t ${ECR_REPO_NAME}:${IMAGE_TAG} .
            docker tag ${ECR_REPO_NAME}:${IMAGE_TAG} ${ECR_REPO_NAME}:latest
        '''
    }
}
```

## Why This Works
- Shell commands via `sh` step bypass the script security sandbox
- `docker build` and `docker tag` are standard CLI commands, not Groovy methods
- No security restrictions on running external commands
- Cleaner and more portable across Jenkins instances

## Benefits of Shell Approach
✅ No security sandbox issues
✅ Works on any Jenkins installation
✅ More readable (actual docker commands)
✅ Easier to debug (can run commands locally)
✅ Familiar syntax for DevOps engineers

## Prevention
**Rule**: When encountering Jenkins script security sandbox errors with plugin DSLs, consider using shell commands instead of the plugin's Groovy API.

## Alternative: Approve Method (Not Recommended)
If you wanted to keep the Docker DSL approach:
1. Go to Jenkins → Manage → In-Process Script Approval
2. Find the blocked method signature
3. Click "Approve"

**Reason not recommended**: This requires admin approval for each new method and reduces security posture.

## Related Files
- `Jenkinsfile` - Current working pipeline using shell commands
- `docs/JENKINS.md` - Jenkins setup guide

## Testing
Verified by successful pipeline execution:
- ✅ Docker image built successfully: `hello-app-dev:4`
- ✅ Image tagged as latest: `hello-app-dev:latest`
- ✅ Both tags pushed to ECR successfully
- ✅ No security sandbox errors

