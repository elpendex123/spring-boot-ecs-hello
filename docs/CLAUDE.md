# Spring Boot Hello World - ECS EC2 Deployment Project

## Project Overview

A complete CI/CD pipeline for deploying a Spring Boot REST API to AWS ECS using EC2 launch type, with infrastructure as code using Terraform and automated deployment via Jenkins.

### Technology Stack
- **Application**: Java 17, Spring Boot 3.x, Gradle
- **Containerization**: Docker
- **CI/CD**: Jenkins (Local Bodhi Linux VM)
- **Infrastructure**: Terraform
- **AWS Services**: ECS (EC2 launch type), ECR, ALB, VPC, EC2
- **Version Control**: Git, GitHub
- **Notifications**: Email via Postfix

### Architecture
```
Internet → ALB (Public) → Target Group → ECS Service → ECS Tasks (Docker Containers) → EC2 Instances (ECS Cluster)
                                                                                              ↓
                                                                                            ECR (Docker Registry)
```

---

## Project Structure

```
spring-boot-ecs-hello/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/
│   │   │       └── example/
│   │   │           └── hello/
│   │   │               ├── HelloApplication.java
│   │   │               └── controller/
│   │   │                   └── HelloController.java
│   │   └── resources/
│   │       └── application.yml
│   └── test/
│       └── java/
│           └── com/
│               └── example/
│                   └── hello/
│                       └── HelloControllerTest.java
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── vpc.tf
│   ├── alb.tf
│   ├── ecs.tf
│   ├── ecr.tf
│   └── iam.tf
├── Dockerfile
├── Jenkinsfile
├── build.gradle
├── settings.gradle
├── gradlew
├── gradlew.bat
├── gradle/
│   └── wrapper/
│       ├── gradle-wrapper.jar
│       └── gradle-wrapper.properties
├── .gitignore
└── README.md
```

---

## Phase 1: Local Development Setup

### 1.1 Prerequisites Check

Ensure you have the following installed on your Bodhi Linux VM:

```bash
# Check Java
java -version  # Should be Java 17

# Check Docker
docker --version
docker ps  # Verify Docker daemon is running

# Check Git
git --version

# Check AWS CLI
aws --version

# Check Terraform
terraform --version

# Check Jenkins
# Access: http://localhost:8080
```

### 1.2 AWS Account Setup

**Create IAM User for Jenkins:**

```bash
# Create IAM user
aws iam create-user --user-name jenkins-ecs-deploy

# Create access key
aws iam create-access-key --user-name jenkins-ecs-deploy
# Save the AccessKeyId and SecretAccessKey - you'll need these!

# Attach necessary policies
aws iam attach-user-policy \
  --user-name jenkins-ecs-deploy \
  --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess

aws iam attach-user-policy \
  --user-name jenkins-ecs-deploy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess

aws iam attach-user-policy \
  --user-name jenkins-ecs-deploy \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess

aws iam attach-user-policy \
  --user-name jenkins-ecs-deploy \
  --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess
```

**Configure AWS CLI Profile:**

```bash
aws configure --profile jenkins-ecs
# Enter:
# AWS Access Key ID: <from above>
# AWS Secret Access Key: <from above>
# Default region: us-east-1 (or your preferred region)
# Default output format: json

# Test
aws sts get-caller-identity --profile jenkins-ecs
```

---

## Phase 2: Create Spring Boot Application

### 2.1 Initialize Git Repository

```bash
# Create project directory
mkdir -p ~/projects/spring-boot-ecs-hello
cd ~/projects/spring-boot-ecs-hello

# Initialize Git
git init
git branch -M main
```

### 2.2 Create Gradle Configuration

**File: `settings.gradle`**
```gradle
rootProject.name = 'hello-app'
```

**File: `build.gradle`**
```gradle
plugins {
    id 'java'
    id 'org.springframework.boot' version '3.2.1'
    id 'io.spring.dependency-management' version '1.1.4'
}

group = 'com.example'
version = '1.0.0'
sourceCompatibility = '17'

repositories {
    mavenCentral()
}

dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
    testImplementation 'org.springframework.boot:spring-boot-starter-test'
}

tasks.named('test') {
    useJUnitPlatform()
}

// Create executable jar
jar {
    enabled = false
}
```

### 2.3 Create Spring Boot Application

**File: `src/main/java/com/example/hello/HelloApplication.java`**
```java
package com.example.hello;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class HelloApplication {
    public static void main(String[] args) {
        SpringApplication.run(HelloApplication.class, args);
    }
}
```

**File: `src/main/java/com/example/hello/controller/HelloController.java`**
```java
package com.example.hello.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@RestController
public class HelloController {

    @GetMapping("/hello")
    public Map<String, Object> hello(@RequestParam(defaultValue = "World") String name) {
        Map<String, Object> response = new HashMap<>();
        response.put("message", "Hello, " + name + "!");
        response.put("timestamp", LocalDateTime.now().toString());
        response.put("version", "1.0.0");
        return response;
    }

    @GetMapping("/")
    public Map<String, String> root() {
        Map<String, String> response = new HashMap<>();
        response.put("status", "UP");
        response.put("service", "Hello World API");
        return response;
    }
}
```

**File: `src/main/resources/application.yml`**
```yaml
server:
  port: 8080

spring:
  application:
    name: hello-app

management:
  endpoints:
    web:
      exposure:
        include: health,info
  endpoint:
    health:
      show-details: always
```

### 2.4 Create Unit Test

**File: `src/test/java/com/example/hello/HelloControllerTest.java`**
```java
package com.example.hello;

import com.example.hello.controller.HelloController;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.http.ResponseEntity;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
public class HelloControllerTest {

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    public void testHelloEndpoint() {
        ResponseEntity<Map> response = restTemplate.getForEntity("/hello", Map.class);
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
        assertThat(response.getBody()).containsKey("message");
        assertThat(response.getBody().get("message")).asString().contains("Hello");
    }

    @Test
    public void testHelloWithName() {
        ResponseEntity<Map> response = restTemplate.getForEntity("/hello?name=Enrique", Map.class);
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
        assertThat(response.getBody().get("message")).isEqualTo("Hello, Enrique!");
    }

    @Test
    public void testRootEndpoint() {
        ResponseEntity<Map> response = restTemplate.getForEntity("/", Map.class);
        assertThat(response.getStatusCode().is2xxSuccessful()).isTrue();
        assertThat(response.getBody().get("status")).isEqualTo("UP");
    }
}
```

### 2.5 Test Locally

```bash
# Build the application
./gradlew clean build

# Run the application
./gradlew bootRun

# Test in another terminal
curl http://localhost:8080/
curl http://localhost:8080/hello
curl http://localhost:8080/hello?name=Enrique
curl http://localhost:8080/actuator/health

# Stop the application (Ctrl+C)
```

---

## Phase 3: Dockerization

### 3.1 Create Dockerfile

**File: `Dockerfile`**
```dockerfile
# Multi-stage build for smaller image size

# Stage 1: Build
FROM gradle:8.5-jdk17 AS build
WORKDIR /app
COPY build.gradle settings.gradle gradlew ./
COPY gradle ./gradle
COPY src ./src
RUN ./gradlew clean build -x test

# Stage 2: Runtime
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Create non-root user
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# Copy jar from build stage
COPY --from=build /app/build/libs/*.jar app.jar

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Run application
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

### 3.2 Create .dockerignore

**File: `.dockerignore`**
```
.git
.gitignore
*.md
build/
.gradle/
bin/
target/
*.log
.idea/
*.iml
.vscode/
```

### 3.3 Test Docker Build Locally

```bash
# Build Docker image
docker build -t hello-app:local .

# Run container
docker run -d -p 8080:8080 --name hello-test hello-app:local

# Test
curl http://localhost:8080/hello

# View logs
docker logs hello-test

# Stop and remove
docker stop hello-test
docker rm hello-test
```

---

## Phase 4: Terraform Infrastructure

### 4.1 Setup Terraform Directory

```bash
mkdir -p terraform
cd terraform
```

### 4.2 Create Terraform Configuration Files

**File: `terraform/variables.tf`**
```hcl
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "hello-app"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 8080
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "instance_type" {
  description = "EC2 instance type for ECS cluster"
  type        = string
  default     = "t3.small"
}

variable "min_size" {
  description = "Minimum number of EC2 instances"
  type        = number
  default     = 2
}

variable "max_size" {
  description = "Maximum number of EC2 instances"
  type        = number
  default     = 4
}
```

**File: `terraform/main.tf`**
```hcl
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}

data "aws_ami" "ecs_optimized" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}
```

**File: `terraform/vpc.tf`**
```hcl
# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-subnet-${count.index + 1}"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-${var.environment}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = var.container_port
    to_port         = var.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Allow traffic from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-tasks-sg"
  }
}
```

**File: `terraform/ecr.tf`**
```hcl
# ECR Repository
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ecr"
  }
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}
```

**File: `terraform/alb.tf`**
```hcl
# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# Target Group
resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-${var.environment}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/actuator/health"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name = "${var.project_name}-${var.environment}-tg"
  }
}

# Listener
resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
```

**File: `terraform/iam.tf`**
```hcl
# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-${var.environment}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Role (for application)
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-${var.environment}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-task-role"
  }
}

# EC2 Instance Role for ECS
resource "aws_iam_role" "ecs_instance" {
  name = "${var.project_name}-${var.environment}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-ecs-instance-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs_instance" {
  name = "${var.project_name}-${var.environment}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name
}
```

**File: `terraform/ecs.tf`**
```hcl
# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-cluster"
  }
}

# ECS Capacity Provider - Launch Template
resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project_name}-${var.environment}-ecs-"
  image_id      = data.aws_ami.ecs_optimized.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance.name
  }

  vpc_security_group_ids = [aws_security_group.ecs_tasks.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
              EOF
  )

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-${var.environment}-ecs-instance"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project_name}-${var.environment}-ecs-asg"
  vpc_zone_identifier = aws_subnet.public[*].id
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.min_size

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }
}

# ECS Capacity Provider
resource "aws_ecs_capacity_provider" "main" {
  name = "${var.project_name}-${var.environment}-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 80
    }
  }
}

# Associate Capacity Provider with Cluster
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 1
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-logs"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "${var.project_name}-container"
    image     = "${aws_ecr_repository.app.repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost:8080/actuator/health || exit 1"]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 30
    }
  }])

  tags = {
    Name = "${var.project_name}-${var.environment}-task"
  }
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-${var.environment}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "EC2"

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "${var.project_name}-container"
    container_port   = var.container_port
  }

  depends_on = [
    aws_lb_listener.app,
    aws_iam_role_policy_attachment.ecs_task_execution
  ]

  tags = {
    Name = "${var.project_name}-${var.environment}-service"
  }
}
```

**File: `terraform/outputs.tf`**
```hcl
output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_url" {
  description = "URL of the application"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "ECR repository URL"
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.app.name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.app.name
}
```

### 4.3 Initialize and Plan Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Format files
terraform fmt

# Validate configuration
terraform validate

# Plan (review what will be created)
terraform plan

# Note: Don't apply yet - we'll do this after Jenkins setup
```

---

## Phase 5: Jenkins Configuration

### 5.1 Install Jenkins Plugins

Access Jenkins at `http://localhost:8080` and install these plugins:

1. Go to **Manage Jenkins** → **Manage Plugins** → **Available**
2. Search and install:
   - **Pipeline** (should already be installed)
   - **Git Plugin**
   - **Docker Pipeline**
   - **AWS Steps**
   - **Email Extension Plugin** (for email notifications)

### 5.2 Configure AWS Credentials in Jenkins

1. Go to **Manage Jenkins** → **Manage Credentials**
2. Click on **(global)** domain
3. Click **Add Credentials**
4. Configure:
   - **Kind**: AWS Credentials
   - **ID**: `aws-credentials`
   - **Description**: AWS credentials for ECS deployment
   - **Access Key ID**: (from IAM user jenkins-ecs-deploy)
   - **Secret Access Key**: (from IAM user jenkins-ecs-deploy)
5. Click **OK**

### 5.3 Configure Email Notifications

1. Go to **Manage Jenkins** → **Configure System**
2. Scroll to **Extended E-mail Notification**
3. Configure:
   - **SMTP server**: `localhost`
   - **SMTP port**: `25` (default for postfix)
   - **Default user e-mail suffix**: `@gmail.com`
   - **Default Content Type**: `HTML (text/html)`
4. Scroll to **E-mail Notification**
5. Configure:
   - **SMTP server**: `localhost`
   - **Default user e-mail suffix**: `@gmail.com`
   - **Test configuration by sending test e-mail**
   - **Test e-mail recipient**: `kike.ruben.coello@gmail.com`
6. Click **Test configuration** to verify
7. Click **Save**

### 5.4 Configure Docker in Jenkins

Ensure Jenkins user has Docker permissions:

```bash
# Add jenkins user to docker group
sudo usermod -aG docker jenkins

# Restart Jenkins
sudo systemctl restart jenkins

# Verify (might need to restart Jenkins service)
sudo -u jenkins docker ps
```

---

## Phase 6: Create Jenkinsfile

**File: `Jenkinsfile`**
```groovy
pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-east-1'
        AWS_ACCOUNT_ID = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
        ECR_REPO_NAME = 'hello-app-dev'
        ECS_CLUSTER = 'hello-app-dev-cluster'
        ECS_SERVICE = 'hello-app-dev-service'
        IMAGE_TAG = "${BUILD_NUMBER}"
        ECR_REPOSITORY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm
            }
        }
        
        stage('Build') {
            steps {
                echo 'Building Spring Boot application...'
                sh './gradlew clean build'
            }
        }
        
        stage('Test') {
            steps {
                echo 'Running tests...'
                sh './gradlew test'
            }
            post {
                always {
                    junit '**/build/test-results/test/*.xml'
                }
            }
        }
        
        stage('Docker Build') {
            steps {
                echo 'Building Docker image...'
                script {
                    docker.build("${ECR_REPO_NAME}:${IMAGE_TAG}")
                    docker.tag("${ECR_REPO_NAME}:${IMAGE_TAG}", "${ECR_REPO_NAME}:latest")
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                echo 'Pushing Docker image to ECR...'
                script {
                    withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                        // Login to ECR
                        sh """
                            aws ecr get-login-password --region ${AWS_REGION} | \
                            docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
                        """
                        
                        // Tag and push
                        sh """
                            docker tag ${ECR_REPO_NAME}:${IMAGE_TAG} ${ECR_REPOSITORY}:${IMAGE_TAG}
                            docker tag ${ECR_REPO_NAME}:${IMAGE_TAG} ${ECR_REPOSITORY}:latest
                            docker push ${ECR_REPOSITORY}:${IMAGE_TAG}
                            docker push ${ECR_REPOSITORY}:latest
                        """
                    }
                }
            }
        }
        
        stage('Deploy to ECS') {
            steps {
                echo 'Deploying to ECS...'
                script {
                    withAWS(credentials: 'aws-credentials', region: "${AWS_REGION}") {
                        sh """
                            aws ecs update-service \
                                --cluster ${ECS_CLUSTER} \
                                --service ${ECS_SERVICE} \
                                --force-new-deployment \
                                --region ${AWS_REGION}
                        """
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully!'
            emailext (
                subject: "SUCCESS: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'",
                body: """
                    <p>SUCCESS: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'</p>
                    <p>Build URL: ${env.BUILD_URL}</p>
                    <p>Image: ${ECR_REPOSITORY}:${IMAGE_TAG}</p>
                    <p>ECS Service updated successfully.</p>
                """,
                to: 'kike.ruben.coello@gmail.com',
                from: 'kike.ruben.coello@gmail.com',
                mimeType: 'text/html'
            )
        }
        failure {
            echo 'Pipeline failed!'
            emailext (
                subject: "FAILURE: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'",
                body: """
                    <p>FAILURE: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'</p>
                    <p>Build URL: ${env.BUILD_URL}</p>
                    <p>Console Output: ${env.BUILD_URL}console</p>
                    <p>Please check the logs for details.</p>
                """,
                to: 'kike.ruben.coello@gmail.com',
                from: 'kike.ruben.coello@gmail.com',
                mimeType: 'text/html'
            )
        }
        always {
            echo 'Cleaning up...'
            sh 'docker system prune -f'
        }
    }
}
```

---

## Phase 7: Create Supporting Files

### 7.1 Create .gitignore

**File: `.gitignore`**
```
# Gradle
.gradle/
build/
!gradle/wrapper/gradle-wrapper.jar
!**/src/main/**/build/
!**/src/test/**/build/

# IDE
.idea/
*.iml
*.iws
*.ipr
out/
.vscode/

# OS
.DS_Store
Thumbs.db

# Terraform
terraform/.terraform/
terraform/.terraform.lock.hcl
terraform/terraform.tfstate
terraform/terraform.tfstate.backup
terraform/*.tfvars
!terraform/terraform.tfvars.example

# Logs
*.log

# Application
application-local.yml
```

### 7.2 Create README

**File: `README.md`**
```markdown
# Hello World Spring Boot - ECS Deployment

A Spring Boot REST API deployed to AWS ECS using Jenkins CI/CD pipeline and Terraform infrastructure.

## Architecture

- **Application**: Spring Boot 3.x with Java 17
- **Containerization**: Docker
- **Registry**: AWS ECR
- **Orchestration**: AWS ECS (EC2 launch type)
- **Load Balancer**: Application Load Balancer (ALB)
- **CI/CD**: Jenkins
- **IaC**: Terraform

## API Endpoints

- `GET /` - Health check
- `GET /hello` - Hello World message
- `GET /hello?name=YourName` - Personalized greeting
- `GET /actuator/health` - Spring Boot health check

## Prerequisites

- Java 17
- Docker
- Terraform
- Jenkins
- AWS CLI configured
- AWS Account

## Local Development

```bash
# Build
./gradlew clean build

# Run
./gradlew bootRun

# Test
curl http://localhost:8080/hello
```

## Docker Build

```bash
# Build image
docker build -t hello-app .

# Run container
docker run -p 8080:8080 hello-app

# Test
curl http://localhost:8080/hello
```

## Infrastructure Deployment

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

## CI/CD Pipeline

The Jenkins pipeline automatically:
1. Checks out code from GitHub
2. Builds the application with Gradle
3. Runs unit tests
4. Builds Docker image
5. Pushes to ECR
6. Deploys to ECS

## Access Application

After deployment, access the application at the ALB DNS name:
```bash
terraform output alb_url
```

## Monitoring

- **CloudWatch Logs**: `/ecs/hello-app-dev`
- **ECS Console**: View service health and task status

## Project Structure

```
├── src/                    # Spring Boot application source
├── terraform/              # Infrastructure as Code
├── Dockerfile             # Container definition
├── Jenkinsfile           # CI/CD pipeline
├── build.gradle          # Gradle build configuration
└── README.md             # This file
```

## Author

Enrique Coello
```

---

## Phase 8: Deployment Steps

### 8.1 Create GitHub Repository

```bash
# In your project root directory
cd ~/projects/spring-boot-ecs-hello

# Add all files
git add .

# Commit
git commit -m "Initial commit: Spring Boot app with ECS deployment"

# Create repository on GitHub (via web interface)
# Repository name: spring-boot-ecs-hello

# Add remote
git remote add origin https://github.com/YOUR_USERNAME/spring-boot-ecs-hello.git

# Push
git push -u origin main
```

### 8.2 Deploy Infrastructure with Terraform

```bash
cd terraform

# Initialize (if not done already)
terraform init

# Plan and review
terraform plan

# Apply (this will create all AWS resources)
terraform apply

# Save outputs
terraform output > ../outputs.txt

# Note the ECR repository URL and ALB DNS name
```

**Expected Resources Created:**
- VPC with public subnets
- Internet Gateway and Route Tables
- Security Groups
- Application Load Balancer
- Target Group
- ECR Repository
- ECS Cluster
- EC2 Auto Scaling Group
- Launch Template
- ECS Capacity Provider
- ECS Task Definition
- ECS Service
- CloudWatch Log Group
- IAM Roles and Policies

### 8.3 Initial Docker Image Push

Before Jenkins can deploy, we need to push an initial image:

```bash
# Get ECR repository URL from Terraform output
ECR_REPO=$(terraform output -raw ecr_repository_url)
AWS_REGION=us-east-1

# Build image
cd ..
docker build -t hello-app:latest .

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $(echo $ECR_REPO | cut -d'/' -f1)

# Tag image
docker tag hello-app:latest ${ECR_REPO}:latest

# Push to ECR
docker push ${ECR_REPO}:latest

# Verify
aws ecr describe-images --repository-name hello-app-dev --region $AWS_REGION
```

### 8.4 Create Jenkins Pipeline Job

1. Open Jenkins: `http://localhost:8080`
2. Click **New Item**
3. Enter name: `spring-boot-ecs-hello`
4. Select **Pipeline**
5. Click **OK**
6. In **Pipeline** section:
   - **Definition**: Pipeline script from SCM
   - **SCM**: Git
   - **Repository URL**: `https://github.com/YOUR_USERNAME/spring-boot-ecs-hello.git`
   - **Credentials**: (add GitHub credentials if private repo)
   - **Branch Specifier**: `*/main`
   - **Script Path**: `Jenkinsfile`
7. Click **Save**

### 8.5 Run First Pipeline Build

1. Click **Build Now**
2. Monitor the build in **Console Output**
3. Verify each stage completes successfully
4. Check email for build notification

### 8.6 Verify Deployment

```bash
# Get ALB DNS name
cd terraform
ALB_URL=$(terraform output -raw alb_url)

# Wait for service to stabilize (2-3 minutes)
aws ecs wait services-stable \
  --cluster hello-app-dev-cluster \
  --services hello-app-dev-service \
  --region us-east-1

# Test endpoints
curl $ALB_URL/
curl $ALB_URL/hello
curl $ALB_URL/hello?name=Enrique
curl $ALB_URL/actuator/health

# Expected responses:
# / -> {"status":"UP","service":"Hello World API"}
# /hello -> {"message":"Hello, World!","timestamp":"...","version":"1.0.0"}
# /actuator/health -> {"status":"UP"}
```

---

## Phase 9: Testing and Validation

### 9.1 Verify ECS Service

```bash
# Check ECS cluster
aws ecs describe-clusters --clusters hello-app-dev-cluster --region us-east-1

# Check service
aws ecs describe-services \
  --cluster hello-app-dev-cluster \
  --services hello-app-dev-service \
  --region us-east-1

# Check tasks
aws ecs list-tasks --cluster hello-app-dev-cluster --region us-east-1

# Check task details
TASK_ARN=$(aws ecs list-tasks --cluster hello-app-dev-cluster --region us-east-1 --query 'taskArns[0]' --output text)
aws ecs describe-tasks --cluster hello-app-dev-cluster --tasks $TASK_ARN --region us-east-1
```

### 9.2 Check CloudWatch Logs

```bash
# View log streams
aws logs describe-log-streams \
  --log-group-name /ecs/hello-app-dev \
  --region us-east-1

# Tail logs (replace with actual stream name)
aws logs tail /ecs/hello-app-dev --follow --region us-east-1
```

### 9.3 Load Test (Optional)

```bash
# Simple load test with curl
for i in {1..100}; do
  curl -s $ALB_URL/hello > /dev/null
  echo "Request $i completed"
done

# Monitor ECS tasks
watch aws ecs list-tasks --cluster hello-app-dev-cluster --region us-east-1
```

### 9.4 Test Code Changes

```bash
# Make a change to HelloController.java
# For example, change the version number

# Commit and push
git add .
git commit -m "Update version to 1.0.1"
git push origin main

# Trigger Jenkins build
# Can be done via webhook or manually

# Verify new deployment
curl $ALB_URL/hello | jq .version
```

---

## Phase 10: Monitoring and Maintenance

### 10.1 CloudWatch Dashboards

Create a custom dashboard in AWS Console:
- ECS Service CPU/Memory utilization
- ALB Target Health
- Request count and latency
- 4xx/5xx errors

### 10.2 Set Up Alarms

```bash
# Example: CPU Utilization Alarm
aws cloudwatch put-metric-alarm \
  --alarm-name hello-app-high-cpu \
  --alarm-description "Alert when CPU exceeds 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --dimensions Name=ServiceName,Value=hello-app-dev-service Name=ClusterName,Value=hello-app-dev-cluster \
  --region us-east-1
```

### 10.3 Scaling Policies

ECS will auto-scale EC2 instances based on capacity provider settings (already configured in Terraform).

To manually scale tasks:

```bash
# Scale to 4 tasks
aws ecs update-service \
  --cluster hello-app-dev-cluster \
  --service hello-app-dev-service \
  --desired-count 4 \
  --region us-east-1
```

### 10.4 Log Retention

CloudWatch logs are set to 7 days retention. Adjust in `terraform/ecs.tf` if needed.

---

## Phase 11: Cleanup (When Done)

### 11.1 Destroy Infrastructure

```bash
# Stop all running tasks first
aws ecs update-service \
  --cluster hello-app-dev-cluster \
  --service hello-app-dev-service \
  --desired-count 0 \
  --region us-east-1

# Wait for tasks to stop
aws ecs wait services-stable \
  --cluster hello-app-dev-cluster \
  --services hello-app-dev-service \
  --region us-east-1

# Destroy with Terraform
cd terraform
terraform destroy

# Confirm with 'yes'
```

### 11.2 Clean Up Local Docker

```bash
# Remove local images
docker rmi hello-app:latest
docker system prune -a
```

### 11.3 Remove IAM User (Optional)

```bash
# Detach policies
aws iam detach-user-policy --user-name jenkins-ecs-deploy --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
aws iam detach-user-policy --user-name jenkins-ecs-deploy --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess
aws iam detach-user-policy --user-name jenkins-ecs-deploy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam detach-user-policy --user-name jenkins-ecs-deploy --policy-arn arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess

# Delete access keys
aws iam list-access-keys --user-name jenkins-ecs-deploy
aws iam delete-access-key --user-name jenkins-ecs-deploy --access-key-id <ACCESS_KEY_ID>

# Delete user
aws iam delete-user --user-name jenkins-ecs-deploy
```

---

## Troubleshooting

### Common Issues

**1. Jenkins can't push to ECR**
```bash
# Verify AWS credentials in Jenkins
# Test in Jenkins console:
withAWS(credentials: 'aws-credentials', region: 'us-east-1') {
    sh 'aws sts get-caller-identity'
}
```

**2. ECS tasks failing health checks**
```bash
# Check task logs
aws logs tail /ecs/hello-app-dev --follow --region us-east-1

# Check task definition health check settings
# Ensure /actuator/health endpoint is accessible
```

**3. ALB returns 503**
```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --region us-east-1

# Common causes:
# - Security group not allowing traffic
# - Health check path incorrect
# - Container not listening on correct port
```

**4. Terraform apply fails**
```bash
# Check for existing resources with same name
# Ensure you have proper IAM permissions
# Review terraform plan output carefully
```

**5. Email notifications not working**
```bash
# Test postfix
echo "Test email" | mail -s "Test Subject" kike.ruben.coello@gmail.com

# Check Jenkins email configuration
# Verify SMTP settings in Jenkins
```

---

## Next Steps / Enhancements

### Short Term
1. Add health check endpoint with more details
2. Implement graceful shutdown
3. Add application properties for different environments
4. Create Terraform workspaces for dev/staging/prod

### Medium Term
1. Add SonarQube for code quality
2. Implement blue/green deployment
3. Add integration tests
4. Set up proper secrets management (AWS Secrets Manager)
5. Add API documentation (Swagger/OpenAPI)

### Long Term
1. Implement distributed tracing (AWS X-Ray)
2. Add Prometheus metrics
3. Create Grafana dashboards
4. Implement canary deployments
5. Add chaos engineering tests
6. Multi-region deployment

---

## Costs Estimate

**Monthly AWS Costs (approximate):**
- ECS EC2 (2x t3.small): ~$30
- Application Load Balancer: ~$20
- Data transfer: ~$5-10
- CloudWatch Logs: ~$5
- ECR storage: ~$1

**Total**: ~$60-70/month

**Cost Optimization Tips:**
- Use t3.micro for development
- Stop ECS service when not in use
- Use Fargate Spot for non-production
- Enable ECS Container Insights only when needed

---

## Resources

### Documentation
- [Spring Boot Reference](https://docs.spring.io/spring-boot/docs/current/reference/htmlsingle/)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)

### Useful Commands

```bash
# AWS ECS
aws ecs list-clusters
aws ecs describe-clusters --clusters <cluster-name>
aws ecs list-services --cluster <cluster-name>
aws ecs describe-services --cluster <cluster-name> --services <service-name>
aws ecs list-tasks --cluster <cluster-name>
aws ecs describe-tasks --cluster <cluster-name> --tasks <task-arn>

# AWS ECR
aws ecr describe-repositories
aws ecr describe-images --repository-name <repo-name>
aws ecr list-images --repository-name <repo-name>

# Terraform
terraform init
terraform plan
terraform apply
terraform destroy
terraform output
terraform state list
terraform state show <resource>

# Docker
docker images
docker ps
docker logs <container-id>
docker exec -it <container-id> /bin/sh
docker system prune -a

# Jenkins CLI (optional)
java -jar jenkins-cli.jar -s http://localhost:8080/ build <job-name>
```

---

## Project Completion Checklist

- [ ] Java 17 installed
- [ ] Docker installed and running
- [ ] AWS CLI configured
- [ ] Terraform installed
- [ ] Jenkins installed and running
- [ ] GitHub repository created
- [ ] AWS IAM user created
- [ ] Spring Boot application code created
- [ ] Dockerfile created
- [ ] Terraform configuration created
- [ ] Jenkinsfile created
- [ ] Jenkins credentials configured
- [ ] Jenkins email configured
- [ ] Terraform infrastructure deployed
- [ ] Initial Docker image pushed to ECR
- [ ] Jenkins pipeline created and tested
- [ ] Application accessible via ALB
- [ ] Email notifications working
- [ ] CloudWatch logs accessible
- [ ] Documentation complete

---

## Contact

For questions or issues with this project:
- Email: kike.ruben.coello@gmail.com
- GitHub: [Your GitHub Profile]

---

**Last Updated**: February 2026
**Version**: 1.0.0
**Status**: Ready for Implementation
