# Issue: Jenkins Post Block - Missing FilePath Context

## Problem
Jenkins pipeline post block failed with error:
```
org.jenkinsci.plugins.workflow.steps.MissingContextVariableException: Required context class hudson.FilePath is missing
Perhaps you forgot to surround the sh step with a step that provides this, such as: node
```

This error occurred in the `always` post block:
```groovy
post {
    always {
        echo 'Cleaning up...'
        sh 'docker system prune -f'  // ← Failed
    }
}
```

## Root Cause
In Jenkins declarative pipelines, the `post` block runs OUTSIDE the normal node context. This means:
1. The workspace (FilePath) is not available
2. Shell commands (`sh` step) require a workspace context
3. `echo` works (it's a log message), but `sh` commands fail

## Why This Matters
The `post` block executes after all stages complete to handle cleanup/notifications. By design, it's not inside a node/workspace context.

## Solution
**Wrap shell commands in `script` block, which re-establishes the context.**

### Before (Failed):
```groovy
post {
    always {
        echo 'Cleaning up...'
        sh 'docker system prune -f'
    }
}
```

### After (Success):
```groovy
post {
    always {
        script {
            echo 'Cleaning up...'
            sh 'docker system prune -f'
        }
    }
}
```

## Why This Works
- `script` block re-establishes the pipeline context including FilePath
- Shell commands can now run properly
- `echo` still works as before
- Cleanup runs after all stages complete

## Alternative Solutions (Not Recommended)

### Option A: Use `node` block
```groovy
post {
    always {
        node {
            sh 'docker system prune -f'
        }
    }
}
```
**Problem**: Creates new node allocation, wastes resources

### Option B: Skip cleanup in post
```groovy
post {
    always {
        echo 'Skipping cleanup'
    }
}
```
**Problem**: Docker images accumulate, wastes space

## Best Practice
Use `script` block in post section when you need to run shell commands. It's lightweight and maintains the current context.

## Full Example
```groovy
pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                sh 'echo Building...'
            }
        }
    }

    post {
        success {
            script {
                echo 'Build succeeded!'
                sh 'docker images | head -5'
            }
        }
        failure {
            script {
                echo 'Build failed!'
                sh 'docker ps -a | head -5'
            }
        }
        always {
            script {
                echo 'Cleaning up...'
                sh 'docker system prune -f'
            }
        }
    }
}
```

## Prevention
**Rule**: When using `sh` step in post block, always wrap it with `script { }` block.

## Related Files
- `Jenkinsfile` - Current working pipeline with this fix applied
- `docs/JENKINS.md` - Jenkins setup guide

## Testing
Verified by successful pipeline execution:
- ✅ Post block executed successfully
- ✅ Docker cleanup ran without errors
- ✅ 22.51MB of disk space reclaimed

