# Issue: Port Mismatch Between Application, ALB, and Task Definition

## Problem
After deploying to ECS, tasks were constantly failing health checks and cycling:
- Tasks started but immediately became unhealthy
- ALB showed targets as "unhealthy"
- Application logs showed the app was running
- Health check kept failing

Error in ALB target group:
```
Unhealthy hosts: 1
Healthy hosts: 0
```

## Root Cause
**Port mismatch across the entire stack:**

| Component | Port | Status |
|-----------|------|--------|
| Spring Boot App | 8081 | ✅ Correct |
| Docker Container | 8080 (EXPOSE) | ❌ Wrong |
| ALB Target Group | 8080 | ❌ Wrong |
| ECS Task Definition | 8080 (health check) | ❌ Wrong |
| Terraform Variables | 8080 (default) | ❌ Wrong |

When ALB tried to health check on port 8080, the container was listening on 8081, causing timeouts and marking targets as unhealthy.

## Discovery Process
1. Application worked locally on port 8081 ✅
2. Docker image built successfully ✅
3. ECS service deployed but tasks unhealthy ❌
4. Checked ALB health check path: `/actuator/health` on port 8080
5. Tested container locally: confirmed listening on 8081
6. Found mismatch: ALB expecting 8080, app on 8081

## Solution
**Update port references across 6 files to use port 8081 consistently:**

### File 1: `application.yml`
```yaml
# BEFORE
server:
  port: 8080

# AFTER
server:
  port: 8081
```

### File 2: `Dockerfile`
```dockerfile
# BEFORE
EXPOSE 8080
HEALTHCHECK ... http://localhost:8080/actuator/health

# AFTER
EXPOSE 8081
HEALTHCHECK ... http://localhost:8081/actuator/health
```

### File 3: `terraform/variables.tf`
```hcl
# BEFORE
variable "container_port" {
  default = 8080
}

# AFTER
variable "container_port" {
  default = 8081
}
```

### File 4: `terraform/ecs.tf`
```hcl
# BEFORE
healthCheck = {
  command = ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost:8080/actuator/health || exit 1"]
}

# AFTER
healthCheck = {
  command = ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost:8081/actuator/health || exit 1"]
}
```

### File 5: `terraform/alb.tf`
```hcl
# BEFORE
resource "aws_lb_target_group" "app" {
  port = 8080
  health_check {
    path = "/actuator/health"
    matcher = "200"
  }
}

# AFTER
resource "aws_lb_target_group" "app" {
  port = 8081
  health_check {
    path = "/actuator/health"
    matcher = "200"
  }
}
```

### File 6: `README.md`
Updated all curl examples:
```bash
# BEFORE
curl http://localhost:8080/hello
docker run -p 8080:8080 hello-app

# AFTER
curl http://localhost:8081/hello
docker run -p 8081:8081 hello-app
```

## Impact
- **Application Layer**: Spring Boot configured to listen on 8081
- **Container Layer**: Docker exposes and health checks on 8081
- **Infrastructure Layer**: ALB, task definition, and Terraform all use 8081
- **Documentation**: All examples and URLs reference 8081

## Verification Steps
After applying fix:
1. ✅ Local gradle bootRun works on 8081
2. ✅ Docker container listens on 8081
3. ✅ Local curl tests pass with :8081
4. ✅ Terraform deploys with correct port
5. ✅ ECS health checks pass
6. ✅ ALB targets become healthy

## Key Learning
**Port consistency is critical in containerized deployments:**
- Application port (what the code listens on)
- Container port (what Docker exposes)
- Network port (what infrastructure expects)
- Health check port (what ALB probes)

All four must match, or health checks fail and traffic can't reach the service.

## Prevention
**Checklist for application port changes:**
- [ ] Update application.yml/application.properties
- [ ] Update Dockerfile EXPOSE statement
- [ ] Update Dockerfile HEALTHCHECK command
- [ ] Update Dockerfile local test commands
- [ ] Update terraform variables
- [ ] Update terraform target group port
- [ ] Update terraform task definition health check
- [ ] Update README examples
- [ ] Update any documentation
- [ ] Test locally with Docker
- [ ] Test with terraform plan before apply
- [ ] Verify health checks pass after deployment

## Related Files
- `application.yml` - Port 8081
- `Dockerfile` - Port 8081
- `terraform/variables.tf` - Port 8081 default
- `terraform/ecs.tf` - Health check on 8081
- `terraform/alb.tf` - Target group port 8081
- `README.md` - All examples use 8081

## Timeline
- **Day 1**: Port changed from 8080 to 8081 in application.yml for local development
- **Day 2**: Deployed to ECS, noticed health check failures
- **Day 2**: Discovered port mismatch when Terraform health check failed
- **Day 2**: Updated all 6 files with correct port
- **Day 2**: Terraform destroy/recreate with new port
- **Day 2**: Verified ECS deployment successful with correct port

