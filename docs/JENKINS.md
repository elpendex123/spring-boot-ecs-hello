# Jenkins Pipeline Setup Guide

This guide walks you through setting up a complete CI/CD pipeline in Jenkins that automatically builds, tests, dockerizes, and deploys your application to AWS ECS.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Install Jenkins Plugins](#step-1-install-jenkins-plugins)
3. [Step 2: Configure AWS Credentials](#step-2-configure-aws-credentials)
4. [Step 3: Configure Email Notifications](#step-3-configure-email-notifications)
5. [Step 4: Configure Docker](#step-4-configure-docker)
6. [Step 5: Create Pipeline Job](#step-5-create-pipeline-job)
7. [Step 6: Test the Pipeline](#step-6-test-the-pipeline)
8. [Step 7: Set Up GitHub Webhook](#step-7-set-up-github-webhook)
9. [Pipeline Stages Explained](#pipeline-stages-explained)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, ensure you have:

- Jenkins installed and running (http://localhost:8080)
- GitHub account with your repository: https://github.com/elpendex123/spring-boot-ecs-hello
- AWS Account with appropriate permissions
- IAM user for Jenkins with access keys

**AWS IAM User Permissions (jenkins-ecs-deploy):**
- AmazonECS_FullAccess
- AmazonEC2ContainerRegistryFullAccess
- AmazonEC2FullAccess
- ElasticLoadBalancingFullAccess

---

## Step 1: Install Jenkins Plugins

### Access Jenkins
1. Open Jenkins: http://localhost:8080
2. Log in with your admin credentials

### Install Required Plugins

1. Click **Manage Jenkins** (left sidebar)
2. Click **Manage Plugins**
3. Go to **Available** tab
4. Search for and install these plugins:

#### Essential Plugins
- **Pipeline** (usually pre-installed)
- **Pipeline: Stage View**
- **Git Plugin**
- **Docker Pipeline**
- **Docker Commons**
- **AWS Steps**

#### Notification Plugins
- **Email Extension Plugin**
- **Slack Notification** (optional, for Slack alerts)

### Installation Steps for Each Plugin

1. Check the checkbox next to the plugin name
2. Click **Download now and install after restart**
3. Check **Restart Jenkins when installation is complete and no jobs are running**
4. Jenkins will restart automatically

**Verification:**
After Jenkins restarts, go to **Manage Jenkins** → **Manage Plugins** → **Installed** and confirm all plugins are listed.

---

## Step 2: Configure AWS Credentials

Jenkins needs AWS credentials to authenticate with your AWS account.

### Add AWS Credentials

1. Go to **Manage Jenkins** → **Manage Credentials**
2. Click on **(global)** domain
3. Click **Add Credentials** (left sidebar)
4. Fill in the form:
   - **Kind:** AWS Credentials
   - **ID:** `aws-credentials` (important: must match Jenkinsfile)
   - **Description:** AWS credentials for ECS deployment
   - **Access Key ID:** Your IAM user's access key
   - **Secret Access Key:** Your IAM user's secret key
5. Click **OK**

### Find Your AWS Access Keys

If you don't have access keys, create them:

```bash
# Create access key for jenkins-ecs-deploy user
aws iam create-access-key --user-name jenkins-ecs-deploy

# Output will include:
# - AccessKeyId
# - SecretAccessKey
```

**Important:** Store the secret access key securely. Jenkins will encrypt it.

### Verify Credentials

1. Create a new pipeline job
2. In Pipeline section, add this test stage:
```groovy
stage('Test AWS Credentials') {
    steps {
        script {
            withAWS(credentials: 'aws-credentials', region: 'us-east-1') {
                sh 'aws sts get-caller-identity'
            }
        }
    }
}
```
3. Run the job - you should see successful output with your AWS account details

---

## Step 3: Configure Email Notifications

Jenkins can send build success/failure notifications via email.

### Configure Email Service

1. Go to **Manage Jenkins** → **Configure System**
2. Scroll to **Extended E-mail Notification**
3. Fill in:
   - **SMTP server:** `localhost`
   - **SMTP port:** `25`
   - **Default user e-mail suffix:** `@gmail.com` (or your domain)
   - **Default Content Type:** `HTML (text/html)`
4. Scroll to **E-mail Notification**
5. Fill in:
   - **SMTP server:** `localhost`
   - **Default user e-mail suffix:** `@gmail.com`
6. Click **Test configuration**
   - **Test e-mail recipient:** Your email address
   - Click **Test configuration**
7. Click **Save**

### Verify Email Setup

Check your email - you should receive a test email from Jenkins.

**Note:** Email notifications are already configured in the Jenkinsfile for success/failure events.

---

## Step 4: Configure Docker

Jenkins needs permission to run Docker commands.

### Add Jenkins User to Docker Group

```bash
# Add jenkins user to docker group
sudo usermod -aG docker jenkins

# Restart Jenkins service
sudo systemctl restart jenkins

# Verify (wait for Jenkins to start)
sudo -u jenkins docker ps
```

**Expected output:** List of running containers (or empty list)

### Test Docker Access

1. Create a test pipeline job
2. Add a stage:
```groovy
stage('Test Docker') {
    steps {
        sh 'docker --version'
        sh 'docker ps'
    }
}
```
3. Run the job - should show Docker version and containers

---

## Step 5: Create Pipeline Job

### Create New Job

1. Click **New Item** (Jenkins dashboard)
2. Enter job name: `spring-boot-ecs-hello`
3. Select **Pipeline**
4. Click **OK**

### Configure Pipeline

1. **General Tab:**
   - **Description:** Spring Boot ECS Deployment Pipeline
   - **GitHub project:** https://github.com/elpendex123/spring-boot-ecs-hello

2. **Build Triggers Tab:**
   - Check **GitHub hook trigger for GITScm polling**
   - (This enables webhook - we'll set it up later)

3. **Pipeline Tab:**
   - **Definition:** Pipeline script from SCM
   - **SCM:** Git
   - **Repository URL:** https://github.com/elpendex123/spring-boot-ecs-hello.git
   - **Credentials:** (leave empty for public repo, or add GitHub credentials)
   - **Branch Specifier:** `*/main`
   - **Script Path:** `Jenkinsfile`

4. Click **Save**

### Verify Pipeline Configuration

1. Click **Build Now**
2. Jenkins will:
   - Clone your GitHub repository
   - Find and execute the Jenkinsfile
   - Run all pipeline stages

3. Watch the build progress:
   - Click **#1** (or build number) under Build History
   - Click **Console Output** to see detailed logs
   - Click **Stage View** to see pipeline visualization

---

## Step 6: Test the Pipeline

### First Manual Build

1. From your job page, click **Build Now**
2. A new build starts - Jenkins clones the repo and runs Jenkinsfile
3. Monitor progress in **Console Output**

### Expected Pipeline Stages

The Jenkinsfile runs these stages:

1. **Checkout** - Clone code from GitHub
2. **Build** - Compile with Gradle
3. **Test** - Run unit tests
4. **Docker Build** - Build Docker image
5. **Push to ECR** - Push image to AWS ECR
6. **Deploy to ECS** - Update ECS service

### Typical Build Times

- **Checkout:** 5-10 seconds
- **Build:** 2-3 minutes (first time, cached after)
- **Test:** 1-2 minutes
- **Docker Build:** 1-2 minutes
- **Push to ECR:** 1-2 minutes
- **Deploy to ECS:** 10-20 seconds
- **Total:** 6-10 minutes

### Verify Deployment

After the build completes:

1. Check CloudWatch logs:
```bash
aws logs tail /ecs/hello-app-dev --follow --region us-east-1
```

2. Test the API:
```bash
ALB_URL=$(aws elbv2 describe-load-balancers --region us-east-1 --query "LoadBalancers[?LoadBalancerName=='hello-app-dev-alb'].DNSName" --output text)
curl http://$ALB_URL/hello
```

3. Use health check script:
```bash
./scripts/health-check.sh
```

---

## Step 7: Set Up GitHub Webhook

Webhook automatically triggers Jenkins builds when you push to GitHub.

### Create GitHub Webhook

1. Go to your GitHub repository: https://github.com/elpendex123/spring-boot-ecs-hello
2. Click **Settings** → **Webhooks**
3. Click **Add webhook**
4. Fill in:
   - **Payload URL:** `http://<YOUR_JENKINS_IP>:8080/github-webhook/`
   - **Content type:** `application/json`
   - **Events:** Select:
     - Push events
     - Pull requests
   - **Active:** Checked
5. Click **Add webhook**

**Note:** If Jenkins is on your local machine (not accessible from internet), webhook won't work. You can trigger builds manually instead.

### Test Webhook

1. Make a small change to your code:
```bash
echo "# Updated" >> README.md
git add README.md
git commit -m "Test webhook"
git push origin main
```

2. Watch Jenkins automatically start a new build
3. The build should complete in 6-10 minutes

---

## Pipeline Stages Explained

### Stage 1: Checkout
```groovy
stage('Checkout') {
    steps {
        echo 'Checking out code from GitHub...'
        checkout scm
    }
}
```
- Clones your GitHub repository
- Uses branch specified in job configuration (`main`)
- Checks out the Jenkinsfile for execution

### Stage 2: Build
```groovy
stage('Build') {
    steps {
        echo 'Building Spring Boot application...'
        sh './gradlew clean build'
    }
}
```
- Runs `./gradlew clean build`
- Compiles Java code
- Packages as JAR file
- Output: `build/libs/hello-app-1.0.0.jar`

### Stage 3: Test
```groovy
stage('Test') {
    steps {
        echo 'Running tests...'
        sh './gradlew test'
    }
}
```
- Executes all unit tests
- Uses JUnit 5
- Publishes test results in Jenkins

### Stage 4: Docker Build
```groovy
stage('Docker Build') {
    steps {
        script {
            docker.build("${ECR_REPO_NAME}:${IMAGE_TAG}")
            docker.tag("${ECR_REPO_NAME}:${IMAGE_TAG}", "${ECR_REPO_NAME}:latest")
        }
    }
}
```
- Builds Docker image using Dockerfile
- Tags with build number and latest
- Image name: `hello-app-dev:1`, `hello-app-dev:latest`

### Stage 5: Push to ECR
```groovy
stage('Push to ECR') {
    steps {
        script {
            withAWS(credentials: 'aws-credentials', region: 'us-east-1') {
                // Login to ECR
                sh '''
                    aws ecr get-login-password --region us-east-1 | \
                    docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
                '''

                // Tag and push
                sh '''
                    docker tag hello-app-dev:${BUILD_NUMBER} <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/hello-app-dev:${BUILD_NUMBER}
                    docker tag hello-app-dev:${BUILD_NUMBER} <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/hello-app-dev:latest
                    docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/hello-app-dev:${BUILD_NUMBER}
                    docker push <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/hello-app-dev:latest
                '''
            }
        }
    }
}
```
- Authenticates with AWS ECR
- Tags Docker image with AWS account ID
- Pushes both tagged version and `latest`

### Stage 6: Deploy to ECS
```groovy
stage('Deploy to ECS') {
    steps {
        script {
            withAWS(credentials: 'aws-credentials', region: 'us-east-1') {
                sh '''
                    aws ecs update-service \
                        --cluster hello-app-dev-cluster \
                        --service hello-app-dev-service \
                        --force-new-deployment \
                        --region us-east-1
                '''
            }
        }
    }
}
```
- Updates ECS service with new image
- Pulls latest image from ECR
- Gracefully restarts tasks with new version
- Maintains zero-downtime deployment

### Post-Build Actions

**Success:**
- Sends success email with deployment details
- Includes image URI and build URL

**Failure:**
- Sends failure email with error details
- Links to console output for debugging

**Always:**
- Cleans up Docker images: `docker system prune -f`

---

## Troubleshooting

### Issue: Jenkins can't clone GitHub repo
**Solution:**
1. Check GitHub repository is public
2. Or add GitHub credentials to Jenkins:
   - **Manage Jenkins** → **Manage Credentials**
   - Add GitHub credentials (username + personal access token)
   - Update job configuration with credentials

### Issue: Docker permission denied
**Error:** `docker: permission denied while trying to connect to the Docker daemon`

**Solution:**
```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### Issue: AWS credentials not working
**Error:** `InvalidParameterException` or `Access Denied`

**Solution:**
1. Verify access key ID and secret are correct
2. Confirm IAM user has required permissions
3. Test credentials manually:
```bash
aws sts get-caller-identity --profile jenkins-ecs
```

### Issue: ECR login failing
**Error:** `no basic auth credentials`

**Solution:**
1. Verify IAM user has `AmazonEC2ContainerRegistryFullAccess`
2. Check AWS region in Jenkinsfile matches your region
3. Test ECR login manually:
```bash
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com
```

### Issue: ECS deployment stuck
**Error:** Tasks not starting or health checks failing

**Solution:**
1. Check CloudWatch logs:
```bash
aws logs tail /ecs/hello-app-dev --follow --region us-east-1
```
2. Verify target group port is 8081:
```bash
aws elbv2 describe-target-groups --region us-east-1 --names hello-app-dev-tg --query 'TargetGroups[0].Port'
```
3. Check ECS service status:
```bash
aws ecs describe-services --cluster hello-app-dev-cluster --services hello-app-dev-service --region us-east-1
```

### Issue: Email notifications not sending
**Solution:**
1. Verify Postfix is running:
```bash
sudo systemctl status postfix
```
2. Check Jenkins email configuration (Step 3)
3. Test email manually:
```bash
echo "Test" | mail -s "Subject" your-email@example.com
```

### Issue: Build takes too long
**Expected times:**
- First build: 10-15 minutes (builds gradle cache)
- Subsequent builds: 6-10 minutes (uses cache)

**Optimization:**
- Build cache is stored in Jenkins workspace
- Docker layer caching speeds up builds
- Second+ builds should be faster

---

## Best Practices

1. **Monitor builds regularly**
   - Check **Console Output** for errors
   - Use **Blue Ocean** plugin for better visualization (optional)

2. **Keep Jenkinsfile updated**
   - Update Jenkinsfile with code changes
   - Test locally before pushing

3. **Secure credentials**
   - Never commit AWS keys to git
   - Jenkins encrypts all stored credentials
   - Use IAM roles for EC2-based Jenkins (if applicable)

4. **Archive build artifacts**
   - Keep JAR files for debugging
   - Archive Docker images in ECR

5. **Set up alerts**
   - Email on failure
   - Slack notifications (optional)
   - GitHub status checks

---

## Advanced Configuration (Optional)

### Blue Ocean Plugin (Better UI)
```bash
# Install Blue Ocean for visual pipeline
# Jenkins → Manage Plugins → Search "Blue Ocean"
# Install and restart Jenkins
```

### Slack Integration
1. Get Slack webhook URL from your workspace
2. Install Slack Notification plugin
3. Add to Jenkinsfile post section:
```groovy
slackSend(
    channel: '#deployments',
    message: "Build ${BUILD_NUMBER} ${currentBuild.result}"
)
```

### Build Artifacts
Add to Jenkinsfile:
```groovy
post {
    success {
        archiveArtifacts artifacts: 'build/libs/*.jar'
    }
}
```

---

## Summary

**Jenkins Pipeline Flow:**
```
GitHub Push
    ↓
GitHub Webhook triggers Jenkins
    ↓
Jenkins checks out code
    ↓
Build (Gradle compile & test)
    ↓
Docker Build (create image)
    ↓
Push to ECR (AWS Docker registry)
    ↓
Deploy to ECS (update service)
    ↓
Email notification (success/failure)
    ↓
Application updated on AWS
```

**Next Steps:**
1. Create Jenkins job (Step 5)
2. Run first build manually (Step 6)
3. Verify deployment works
4. Set up webhook (Step 7)
5. Make a code change and push to GitHub
6. Watch automatic deployment

---

## Useful Jenkins Commands

```bash
# View Jenkins logs
sudo tail -f /var/log/jenkins/jenkins.log

# Restart Jenkins
sudo systemctl restart jenkins

# Check Jenkins status
sudo systemctl status jenkins

# View running builds
curl -s http://localhost:8080/api/json | jq '.jobs[] | {name, color}'
```

---

## Getting Help

If builds fail:
1. Check **Console Output** for error messages
2. Look at **CloudWatch Logs** for application errors
3. Run health check script: `./scripts/health-check.sh`
4. Check AWS resources are still deployed: `./scripts/list-aws-services.sh`

Happy deploying! 🚀
