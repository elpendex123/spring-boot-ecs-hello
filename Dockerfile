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
EXPOSE 8081

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:8081/actuator/health || exit 1

# Run application
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
