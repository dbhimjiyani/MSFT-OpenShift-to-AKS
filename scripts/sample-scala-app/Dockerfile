# Multi-stage build for Scala application

# Stage 1: Build stage
FROM eclipse-temurin:17-jdk as builder

WORKDIR /app

# Install sbt
RUN apt-get update && \
    apt-get install -y curl && \
    echo "deb https://repo.scala-sbt.org/scalasbt/debian all main" | tee /etc/apt/sources.list.d/sbt.list && \
    echo "deb https://repo.scala-sbt.org/scalasbt/debian /" | tee /etc/apt/sources.list.d/sbt_old.list && \
    curl -sL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823" | apt-key add && \
    apt-get update && \
    apt-get install -y sbt

# Copy build files
COPY build.sbt .
COPY project ./project

# Download dependencies (cached layer)
RUN sbt update

# Copy source code
COPY src ./src

# Build the application
RUN sbt clean assembly

# Stage 2: Runtime stage
FROM eclipse-temurin:17-jre-jammy

WORKDIR /app

# Copy the JAR from builder stage
COPY --from=builder /app/target/scala-2.13/scala-app.jar ./scala-app.jar

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser && \
    chown -R appuser:appuser /app

USER appuser

# Expose port
EXPOSE 8080

# Environment variables with defaults
ENV HOST=0.0.0.0 \
    PORT=8080 \
    REDIS_HOST=localhost \
    REDIS_PORT=6379

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Run the application
ENTRYPOINT ["java", "-jar", "scala-app.jar"]
