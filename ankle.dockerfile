# Build stage
FROM amazoncorretto:21 AS builder

WORKDIR /app

# Copy gradle wrapper and build files
COPY gradlew gradlew.bat ./
COPY gradle ./gradle
COPY build.gradle settings.gradle gradle.properties ./

# Download dependencies
RUN ./gradlew dependencies --no-daemon

# Copy source code
COPY ankle-springboot ./ankle-springboot

# Build application
RUN ./gradlew resolveAndLockAll --write-locks
RUN ./gradlew :ankle-springboot:bootJar --no-daemon

# List files to debug
RUN ls -la /app/ankle-springboot/build/libs/

# Runtime stage
FROM amazoncorretto:21-alpine

# Create runtime directory for jar and log directory
RUN mkdir -p /runtime /var/log/app

# Copy the built jar from builder stage to runtime directory
COPY --from=builder /app/ankle-springboot/build/libs/ankle-springboot-0.0.1-SNAPSHOT.jar /runtime/app.jar

# Set working directory to /app for mounted source code
WORKDIR /app

# Expose port
EXPOSE 9000

# Run the application from runtime directory
ENTRYPOINT ["java", "-jar", "/runtime/app.jar"]