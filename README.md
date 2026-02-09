# Hello World Spring Boot - AWS ECS Deployment

A complete Spring Boot REST API application deployed to AWS ECS using EC2 launch type, with infrastructure as code (Terraform) and automated CI/CD pipeline (Jenkins).

## Architecture

```
Internet → ALB (Public) → Target Group → ECS Service → ECS Tasks (Docker) → EC2 Instances (ECS Cluster)
                                                                                    ↓
                                                                                  ECR (Docker Registry)
```

## Technology Stack

- **Language**: Java 17
- **Framework**: Spring Boot 3.2.1
- **Build Tool**: Gradle 8.5
- **Containerization**: Docker (multi-stage build)
- **Orchestration**: AWS ECS (EC2 launch type)
- **Infrastructure**: Terraform 1.0+
- **CI/CD**: Jenkins Pipeline
- **Container Registry**: AWS ECR
- **Load Balancing**: AWS Application Load Balancer (ALB)
- **Networking**: VPC with public subnets
- **Logging**: AWS CloudWatch
- **Monitoring**: CloudWatch Container Insights

## API Endpoints

All endpoints return JSON responses.

- **`GET /`** - Health check
  - Response: `{"status": "UP", "service": "Hello World API"}`

- **`GET /hello`** - Default greeting
  - Response: `{"message": "Hello, World!", "timestamp": "...", "version": "1.0.0"}`

- **`GET /hello?name=YourName`** - Personalized greeting
  - Response: `{"message": "Hello, YourName!", "timestamp": "...", "version": "1.0.0"}`

- **`GET /actuator/health`** - Spring Boot health check
  - Response: `{"status": "UP"}`

## Prerequisites

Before you begin, ensure you have the following installed:

- **Java 17** or higher
  ```bash
  java -version
  ```

- **Docker**
  ```bash
  docker --version
  ```

- **Terraform** (1.0 or higher)
  ```bash
  terraform --version
  ```

- **AWS CLI** v2
  ```bash
  aws --version
  ```

- **Git**
  ```bash
  git --version
  ```

- **Jenkins** (optional, for CI/CD)

### AWS Setup

1. Configure AWS CLI with appropriate credentials:
   ```bash
   aws configure --profile your-profile
   ```

2. Create an IAM user for Jenkins with the following policies:
   - AmazonECS_FullAccess
   - AmazonEC2ContainerRegistryFullAccess
   - AmazonEC2FullAccess
   - ElasticLoadBalancingFullAccess

## Local Development

### Build the Application

```bash
./gradlew clean build
```

Expected output: Successful build with all tests passing.

### Run the Application

```bash
./gradlew bootRun
```

The application will start on `http://localhost:8081`.

### Test the API

```bash
# Health check
curl http://localhost:8081/

# Hello endpoint
curl http://localhost:8081/hello

# With name parameter
curl http://localhost:8081/hello?name=Enrique

# Spring Boot actuator
curl http://localhost:8081/actuator/health
```

### Run Unit Tests

```bash
./gradlew test
```

## Docker Build and Run

### Build Docker Image

```bash
docker build -t hello-app:local .
```

### Run Container Locally

```bash
docker run -d -p 8081:8081 --name hello-app-local hello-app:local

# Test
curl http://localhost:8081/hello

# View logs
docker logs hello-app-local

# Stop and remove
docker stop hello-app-local
docker rm hello-app-local
```

## Infrastructure Deployment

### Prerequisites for Deployment

1. AWS account with appropriate permissions
2. AWS CLI configured with valid credentials
3. Terraform installed locally

### Deploy Infrastructure

```bash
cd terraform

# Initialize Terraform (first time only)
terraform init

# Review planned changes
terraform plan

# Apply the infrastructure
terraform apply

# Save outputs
terraform output > ../outputs.txt
```

This will create:
- VPC with public subnets across 2 availability zones
- Internet Gateway and Route Tables
- Security Groups for ALB and ECS tasks
- Application Load Balancer
- ECR Repository
- ECS Cluster
- EC2 Auto Scaling Group (2-4 instances)
- ECS Capacity Provider
- ECS Task Definition
- ECS Service
- CloudWatch Log Group
- IAM Roles and Policies

### Get Deployment Outputs

```bash
terraform output alb_url
terraform output ecr_repository_url
terraform output ecs_cluster_name
```

## Initial Docker Image Deployment

Before Jenkins can deploy, push an initial image to ECR:

```bash
# Build Docker image
docker build -t hello-app:latest .

# Get ECR repository URL
ECR_REPO=$(cd terraform && terraform output -raw ecr_repository_url)
AWS_REGION=us-east-1

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $(echo $ECR_REPO | cut -d'/' -f1)

# Tag and push
docker tag hello-app:latest ${ECR_REPO}:latest
docker push ${ECR_REPO}:latest

# Verify
aws ecr describe-images --repository-name hello-app-dev --region $AWS_REGION
```

## CI/CD Pipeline (Jenkins)

### Configure Jenkins

1. Install required plugins:
   - Pipeline
   - Git Plugin
   - Docker Pipeline
   - AWS Steps
   - Email Extension Plugin

2. Create AWS credentials in Jenkins:
   - **Kind**: AWS Credentials
   - **ID**: `aws-credentials`
   - **Access Key ID**: Your IAM user's access key
   - **Secret Access Key**: Your IAM user's secret key

3. Create Pipeline Job:
   - **Name**: spring-boot-ecs-hello
   - **Type**: Pipeline
   - **Pipeline Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: https://github.com/elpendex123/spring-boot-ecs-hello.git
   - **Branch**: */main
   - **Script Path**: Jenkinsfile

### Pipeline Stages

1. **Checkout** - Clone code from GitHub
2. **Build** - Compile and build with Gradle
3. **Test** - Run unit tests
4. **Docker Build** - Build Docker image
5. **Push to ECR** - Push image to AWS ECR
6. **Deploy to ECS** - Update ECS service with new image

## AWS Management Scripts

The `scripts/` directory contains helpful shell scripts for managing your AWS infrastructure.

### List AWS Services

View all deployed AWS resources and their status:

```bash
./scripts/list-aws-services.sh

# With custom parameters
./scripts/list-aws-services.sh hello-app dev us-east-1
```

Shows:
- ECS Cluster and Service status
- Running tasks
- ALB and target group health
- ECR repository and images
- VPC and security groups
- CloudWatch logs
- EC2 instances
- IAM roles

### Health Check

Quick health check of the deployed application:

```bash
./scripts/health-check.sh

# With custom parameters
./scripts/health-check.sh hello-app dev us-east-1
```

Checks:
- ECS Service status and task count
- ALB status
- Target Group health
- API endpoint availability
- CloudWatch logs

### Teardown Infrastructure

Destroy all AWS resources (use with caution):

```bash
./scripts/teardown-aws.sh

# With custom parameters
./scripts/teardown-aws.sh hello-app dev us-east-1
```

This will:
1. Scale ECS service to 0 tasks
2. Run `terraform destroy`
3. Clean up any orphaned resources
4. Provide summary of destroyed resources

**Warning**: This action cannot be easily undone. All data will be lost.

## Monitoring and Logs

### CloudWatch Logs

View application logs:

```bash
aws logs tail /ecs/hello-app-dev --follow --region us-east-1
```

### ECS Service Health

```bash
aws ecs describe-services \
  --cluster hello-app-dev-cluster \
  --services hello-app-dev-service \
  --region us-east-1
```

### View Tasks

```bash
aws ecs list-tasks --cluster hello-app-dev-cluster --region us-east-1

# Get details of a task
aws ecs describe-tasks \
  --cluster hello-app-dev-cluster \
  --tasks <task-arn> \
  --region us-east-1
```

## Troubleshooting

### Application won't start

1. Check CloudWatch logs:
   ```bash
   aws logs tail /ecs/hello-app-dev --follow
   ```

2. Verify ECS task health:
   ```bash
   ./scripts/health-check.sh
   ```

### ALB returning 503 Service Unavailable

1. Check target group health:
   ```bash
   aws elbv2 describe-target-health --target-group-arn <tg-arn>
   ```

2. Common causes:
   - Health check timeout (verify `/actuator/health` returns 200)
   - Security group not allowing traffic between ALB and ECS tasks
   - Tasks not running (check desired count vs running count)

### Terraform apply fails

1. Verify AWS credentials:
   ```bash
   aws sts get-caller-identity
   ```

2. Check for existing resources with same names (may conflict)

3. Ensure IAM user has sufficient permissions

### Docker image won't push to ECR

1. Verify ECR login:
   ```bash
   aws ecr get-login-password --region us-east-1 | \
     docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
   ```

2. Check image tag:
   ```bash
   docker images | grep hello-app
   ```

## Costs

### Estimated Monthly Costs

- **ECS EC2** (2x t3.small): ~$30
- **ALB**: ~$20
- **Data Transfer**: ~$5-10
- **CloudWatch Logs**: ~$5
- **ECR Storage**: ~$1

**Total**: ~$60-70/month

### Cost Optimization

- Use `t3.micro` for development
- Stop ECS service when not in use:
  ```bash
  aws ecs update-service \
    --cluster hello-app-dev-cluster \
    --service hello-app-dev-service \
    --desired-count 0
  ```
- Use Fargate Spot for non-production workloads
- Enable CloudWatch Container Insights only when needed

## Project Structure

```
spring-boot-ecs-hello/
├── src/
│   ├── main/
│   │   ├── java/com/example/hello/
│   │   │   ├── HelloApplication.java
│   │   │   └── controller/
│   │   │       └── HelloController.java
│   │   └── resources/
│   │       └── application.yml
│   └── test/
│       └── java/com/example/hello/
│           └── HelloControllerTest.java
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── vpc.tf
│   ├── alb.tf
│   ├── ecs.tf
│   ├── ecr.tf
│   └── iam.tf
├── scripts/
│   ├── list-aws-services.sh
│   ├── teardown-aws.sh
│   └── health-check.sh
├── Dockerfile
├── .dockerignore
├── Jenkinsfile
├── build.gradle
├── settings.gradle
├── gradlew
├── .gitignore
└── README.md
```

## Next Steps

### Short Term
- [ ] Deploy to AWS with Terraform
- [ ] Push initial Docker image to ECR
- [ ] Verify application is accessible via ALB
- [ ] Set up Jenkins pipeline

### Medium Term
- [ ] Add API documentation (Swagger/OpenAPI)
- [ ] Implement graceful shutdown
- [ ] Add environment-specific configurations
- [ ] Create additional endpoints

### Long Term
- [ ] Add distributed tracing (AWS X-Ray)
- [ ] Implement Prometheus metrics
- [ ] Set up Grafana dashboards
- [ ] Implement blue/green deployments
- [ ] Multi-region deployment

## Getting Help

For issues or questions:

1. Check CloudWatch logs:
   ```bash
   ./scripts/health-check.sh
   aws logs tail /ecs/hello-app-dev --follow
   ```

2. Review Terraform state:
   ```bash
   cd terraform && terraform state list
   ```

3. Check AWS console for more details on resources

## License

This project is provided as-is for educational and development purposes.

---

**Project Repository**: https://github.com/elpendex123/spring-boot-ecs-hello

**Last Updated**: February 2026
