# Multi-stage build for Dependency-Track Backend (Java 21)
FROM maven:3.9-eclipse-temurin-21-alpine AS build

# Set working directory
WORKDIR /app

# Copy the entire source directory to preserve all configuration files
COPY . .

# Ensure Maven has proper permissions and clean any existing builds
RUN mvn clean

# Build the application with all validations disabled for Docker build
RUN mvn package -P quick -P enhance -P embedded-jetty \
    -Dlogback.configuration.file=src/main/docker/logback.xml \
    --batch-mode \
    --no-transfer-progress

# Runtime stage
FROM eclipse-temurin:21-jre-alpine

# Install dependencies and utilities
RUN apk add --no-cache \
    curl \
    tzdata \
    bash

# Create application user for security
RUN addgroup -g 1000 dtrack && \
    adduser -u 1000 -G dtrack -s /bin/sh -D dtrack

# Set working directory
WORKDIR /opt/owasp/dependency-track

# Copy the built JAR and logback config from build stage
COPY --from=build /app/target/dependency-track-apiserver.jar dependency-track-apiserver.jar
COPY --from=build /app/src/main/docker/logback.xml logback.xml

# Create data directory and set ownership
RUN mkdir -p /data && \
    chown -R dtrack:dtrack /data /opt/owasp/dependency-track

# Switch to non-root user
USER dtrack

# Expose the application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=3 \
  CMD curl -f http://localhost:8080/api/version || exit 1

# JVM options optimized for containers and Java 21
ENV JAVA_OPTS="-Xmx4G -Xms1G -XX:+UseG1GC -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

# Start the application (use exec form for proper signal handling)
CMD ["sh", "-c", "java $JAVA_OPTS -Dlogback.configurationFile=logback.xml -jar dependency-track-apiserver.jar"]
