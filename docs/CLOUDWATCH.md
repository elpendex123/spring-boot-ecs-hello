# CloudWatch Monitoring Guide

This guide explains how to monitor your Spring Boot application running on AWS ECS using CloudWatch.

## Table of Contents

1. [CloudWatch Logs](#cloudwatch-logs)
2. [ECS Service Metrics](#ecs-service-metrics)
3. [ALB Metrics](#alb-metrics)
4. [Container Insights](#container-insights)
5. [Quick Reference](#quick-reference)

---

## CloudWatch Logs

CloudWatch Logs stores all application output and container logs from your ECS tasks.

**Log Group Name:** `/ecs/hello-app-dev`

### Via AWS Console

1. Open AWS Console: https://console.aws.amazon.com/cloudwatch/
2. Click **Logs** in the left sidebar
3. Click **Log groups**
4. Find and click `/ecs/hello-app-dev`
5. You'll see multiple **log streams** (one per task)
6. Click on a log stream to view detailed logs
7. Logs show:
   - Application startup messages
   - Request logs
   - Errors and exceptions
   - Health check pings

### Via AWS CLI

#### View recent logs in real-time (recommended)
```bash
aws logs tail /ecs/hello-app-dev --follow --region us-east-1
```

**Flags:**
- `--follow`: Stream logs in real-time (like `tail -f`)
- `--region us-east-1`: AWS region

**Output example:**
```
2026-02-09T10:23:45.123Z [task-id] Starting application on port 8081
2026-02-09T10:23:50.456Z [task-id] Tomcat started on port(s): 8081
2026-02-09T10:24:10.789Z [task-id] GET /hello - 200 OK
```

#### View logs from last hour
```bash
aws logs tail /ecs/hello-app-dev --since 1h --region us-east-1
```

**Available time units:**
- `1m` - Last 1 minute
- `5m` - Last 5 minutes
- `1h` - Last 1 hour
- `1d` - Last 1 day

#### View logs with timestamps in human-readable format
```bash
aws logs tail /ecs/hello-app-dev --format short --region us-east-1
```

#### View specific log stream
```bash
# First, list available log streams
aws logs describe-log-streams --log-group-name /ecs/hello-app-dev --region us-east-1

# Then view a specific stream
aws logs tail /ecs/hello-app-dev --log-stream-name <stream-name> --follow --region us-east-1
```

#### Get logs in JSON format for parsing
```bash
aws logs filter-log-events --log-group-name /ecs/hello-app-dev --region us-east-1 --query 'events[*].[timestamp,message]' --output json
```

---

## ECS Service Metrics

Monitor CPU, memory, and task health metrics for your ECS service.

### Via AWS Console

1. Open AWS Console: https://console.aws.amazon.com/ecs/
2. Click **Clusters** in the left sidebar
3. Click **hello-app-dev-cluster**
4. Under **Services**, click **hello-app-dev-service**
5. Scroll down to **Metrics** section
6. Available metrics:
   - **CPU Utilization** - Percentage of CPU used
   - **Memory Utilization** - Percentage of memory used
   - **Running Count** - Number of running tasks
   - **Desired Count** - Target number of tasks

**What to look for:**
- CPU/Memory spikes indicate high load
- Running Count < Desired Count indicates deployment issues
- Charts show trends over the past hour/day

### Via AWS CLI

#### Get service status and metrics
```bash
aws ecs describe-services \
  --cluster hello-app-dev-cluster \
  --services hello-app-dev-service \
  --region us-east-1 \
  --query 'services[0].[status,runningCount,desiredCount]' \
  --output table
```

**Output:**
```
|  ACTIVE  |  2  |  2  |
```

#### Get detailed service information
```bash
aws ecs describe-services \
  --cluster hello-app-dev-cluster \
  --services hello-app-dev-service \
  --region us-east-1
```

This returns JSON with:
- Service status (ACTIVE, DRAINING, INACTIVE)
- Running tasks count
- Desired tasks count
- Load balancer configuration
- Recent service events

#### Get task details (CPU, memory, status)
```bash
# List tasks
aws ecs list-tasks --cluster hello-app-dev-cluster --region us-east-1

# Describe tasks (replace with actual task ARN)
aws ecs describe-tasks \
  --cluster hello-app-dev-cluster \
  --tasks arn:aws:ecs:us-east-1:ACCOUNT_ID:task/hello-app-dev-cluster/TASK_ID \
  --region us-east-1
```

---

## ALB Metrics

Monitor Application Load Balancer health and traffic.

### Via AWS Console

1. Open AWS Console: https://console.aws.amazon.com/ec2/
2. Click **Load Balancers** in the left sidebar
3. Click **hello-app-dev-alb**
4. Go to **Monitoring** tab
5. Available metrics:
   - **Request Count** - Total requests to your application
   - **Target Response Time** - How long targets take to respond
   - **HTTP 4xx Errors** - Client-side errors (bad requests)
   - **HTTP 5xx Errors** - Server-side errors
   - **Active Connection Count** - Current connections
   - **Healthy Host Count** - Number of healthy targets
   - **Unhealthy Host Count** - Number of unhealthy targets

**What to look for:**
- Increasing 5xx errors indicate application issues
- High response time indicates slow application
- Unhealthy host count should be 0

### Via AWS CLI

#### Get ALB health status
```bash
# Get target group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --region us-east-1 \
  --names hello-app-dev-tg \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region us-east-1 \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Description]' \
  --output table
```

**Output:**
```
|  10.0.0.54  |  healthy  |  None  |
|  10.0.1.22  |  healthy  |  None  |
```

#### Get ALB details
```bash
aws elbv2 describe-load-balancers \
  --region us-east-1 \
  --query "LoadBalancers[?LoadBalancerName=='hello-app-dev-alb'].[DNSName,State.Code,Scheme]" \
  --output table
```

---

## Container Insights

Advanced monitoring with cluster, node, and container-level insights. This is enabled by default in your Terraform configuration.

### Via AWS Console

1. Open AWS Console: https://console.aws.amazon.com/cloudwatch/
2. Click **Container Insights** in the left sidebar
3. Select **Clusters**
4. Click **hello-app-dev-cluster**
5. View metrics:
   - **Cluster Level**: Overall CPU/memory for entire cluster
   - **Node Level**: Per-EC2 instance metrics
   - **Container Level**: Per-container metrics

**Available Views:**
- **Performance Monitoring** - Real-time cluster metrics
- **Resources** - Detailed resource utilization
- **Logs** - Integration with CloudWatch logs
- **Maps** - Visual representation of cluster health

---

## Quick Reference

### Most Useful Commands

#### Monitor application logs in real-time
```bash
aws logs tail /ecs/hello-app-dev --follow --region us-east-1
```

#### Check service health
```bash
aws ecs describe-services \
  --cluster hello-app-dev-cluster \
  --services hello-app-dev-service \
  --region us-east-1 \
  --query 'services[0].[status,runningCount,desiredCount]'
```

#### Check target health
```bash
aws elbv2 describe-target-health \
  --target-group-arn $(aws elbv2 describe-target-groups --region us-east-1 --names hello-app-dev-tg --query 'TargetGroups[0].TargetGroupArn' --output text) \
  --region us-east-1 \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State]' \
  --output table
```

#### Use the management script (recommended)
```bash
./scripts/list-aws-services.sh
./scripts/health-check.sh
```

---

## Common Scenarios

### Application is slow (high response time)
1. Check logs: `aws logs tail /ecs/hello-app-dev --follow`
2. Check CPU/Memory in AWS Console → ECS → Services → Metrics
3. Check ALB response time: AWS Console → Load Balancers → Monitoring

### Seeing 5xx errors
1. Check logs immediately: `aws logs tail /ecs/hello-app-dev --follow`
2. Look for exceptions or error messages
3. Check if tasks are crashing: `aws ecs describe-services --cluster hello-app-dev-cluster --services hello-app-dev-service --region us-east-1`

### Targets are unhealthy
1. Check application logs: `aws logs tail /ecs/hello-app-dev --follow`
2. Verify health check endpoint: http://ALB_DNS/actuator/health
3. Check security groups allow port 8081

### High costs
1. Check running task count: `aws ecs describe-services --cluster hello-app-dev-cluster --services hello-app-dev-service --region us-east-1`
2. Check EC2 instance count: `aws ec2 describe-instances --region us-east-1 --filters "Name=tag:AmazonECSManaged,Values=true" --query 'Reservations[].Instances[].[InstanceId,State.Name]'`
3. Consider scaling down or destroying if not in use

---

## Log Retention

Your logs are configured to be retained for **7 days** before automatic deletion. This is set in `terraform/ecs.tf`:

```hcl
retention_in_days = 7
```

To change retention, update this value and run:
```bash
cd terraform
terraform apply
```

---

## Tips & Best Practices

1. **Use `--follow` flag** - Real-time log streaming is invaluable for debugging
2. **Check logs first** - Most issues will be visible in the logs
3. **Monitor response time** - High response time often indicates application issues before errors appear
4. **Set up CloudWatch alarms** - Can send alerts when metrics exceed thresholds (optional)
5. **Regular health checks** - Run `./scripts/health-check.sh` daily to catch issues early

---

## Next Steps

- Set up CloudWatch alarms for high error rates
- Configure SNS notifications for alerts
- Create CloudWatch dashboards for daily monitoring
- Implement structured logging in your application
