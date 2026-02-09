# Issue: AWS Credentials Not Available in Environment Block

## Problem
Jenkins pipeline failed with error:
```
Unable to locate credentials. You can configure credentials by running "aws configure".
```

The error occurred when trying to get AWS Account ID in the `environment` block of the Jenkinsfile.

## Root Cause
The `environment` block in Jenkins pipelines is evaluated BEFORE any stages execute. At that point, the AWS credentials configured in Jenkins are not yet loaded into the pipeline context.

Specifically, this line failed:
```groovy
environment {
    AWS_ACCOUNT_ID = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
}
```

AWS credentials are only available when:
1. Inside a stage
2. Inside a `withAWS()` block with credentials specified
3. After the `withAWS` context is established

## Solution
**Move AWS Account ID retrieval into a stage with proper credentials context.**

### Before (Failed):
```groovy
pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        AWS_ACCOUNT_ID = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
        // ... other env vars
    }

    stages {
        // ... stages
    }
}
```

### After (Success):
```groovy
pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        PROJECT_NAME = 'hello-app'
        ENVIRONMENT = 'dev'
        // AWS_ACCOUNT_ID moved out - will be set in stage
    }

    stages {
        stage('Initialize AWS') {
            steps {
                script {
                    withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                        def accountId = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
                        env.AWS_ACCOUNT_ID = accountId
                        env.ECR_REPOSITORY = "${accountId}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
                        echo "AWS Account ID: ${env.AWS_ACCOUNT_ID}"
                        echo "ECR Repository: ${env.ECR_REPOSITORY}"
                    }
                }
            }
        }
        // ... rest of stages
    }
}
```

## Key Changes
1. Removed `AWS_ACCOUNT_ID` from `environment` block
2. Created new `Initialize AWS` stage as first stage
3. Used `withAWS(credentials: 'aws-credentials', ...)` to establish credentials context
4. Used `env.AWS_ACCOUNT_ID = accountId` to set environment variable within pipeline
5. Dynamically constructed `env.ECR_REPOSITORY` based on retrieved account ID

## Why This Works
- `withAWS()` block sets up proper AWS authentication
- Shell commands inside `withAWS()` have access to AWS credentials
- Setting `env.VARIABLE_NAME` makes it available to all subsequent stages
- Stage runs AFTER credentials are loaded, unlike `environment` block

## Prevention
**Rule**: Never use AWS CLI commands in the `environment` block. Always move such commands into stages wrapped with `withAWS()`.

## Related Files
- `Jenkinsfile` - Current working pipeline with this fix applied
- `docs/JENKINS.md` - Jenkins setup guide (updated with this pattern)

## Testing
Verified by successful pipeline execution:
- ✅ Initialize AWS stage retrieved account ID
- ✅ Subsequent stages used correct `ECR_REPOSITORY` variable
- ✅ Push to ECR succeeded with correct repository URL

