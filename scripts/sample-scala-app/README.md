# Scala Demo App

A sample Scala application built with Akka HTTP demonstrating containerized application deployment on Azure Red Hat OpenShift (ARO) and migration to Azure Kubernetes Service (AKS).

## Features

- **Akka HTTP** REST API server
- **Redis** integration for caching messages
- **Circe** for JSON serialization
- Health check endpoints
- ConfigMap-based configuration
- Multi-stage Docker build for optimized image size

## API Endpoints

- `GET /` - Welcome page (HTML)
- `GET /health` - Health check
- `GET /api/info` - Application information from ConfigMap
- `GET /api/messages?limit=10` - List cached messages
- `POST /api/messages` - Add a new message

### Example Requests

```bash
# Health check
curl http://localhost:8080/health

# Get app info
curl http://localhost:8080/api/info

# Add a message
curl -X POST http://localhost:8080/api/messages \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello World","author":"Admin"}'

# List messages
curl http://localhost:8080/api/messages
```

## Local Development

### Prerequisites

- JDK 11 or 17
- sbt 1.9+
- Redis (optional, for local testing)

### Build and Run

```bash
# Compile the project
sbt compile

# Run tests
sbt test

# Run locally
sbt run

# Build fat JAR
sbt assembly
```

### Run with Docker

```bash
# Build the image
docker build -t scala-app:latest .

# Run Redis
docker run -d --name redis -p 6379:6379 redis:7-alpine

# Run the app
docker run -d --name scala-app -p 8080:8080 \
  -e REDIS_HOST=host.docker.internal \
  -e REDIS_PORT=6379 \
  scala-app:latest

# Test
curl http://localhost:8080/health
```

## Deployment

### OpenShift (ARO)

Follow [Module 09](../../Module-09-deploy-scala-app-on-aro.md) for detailed deployment instructions.

```bash
# Create project
oc new-project scala-demo

# Deploy Redis
oc apply -f openshift/redis-deployment.yaml
oc apply -f openshift/redis-service.yaml

# Deploy app
oc apply -f openshift/configmap.yaml
oc apply -f openshift/deployment-config.yaml
oc apply -f openshift/service.yaml
oc apply -f openshift/route.yaml
```

### Kubernetes (AKS)

Follow [Module 11](../../Module-11-migrate-app-to-aks.md) for migration instructions.

```bash
# Create namespace
kubectl create namespace scala-demo

# Deploy converted manifests
kubectl apply -f kubernetes/ -n scala-demo
```

## Configuration

Environment variables:

- `HOST` - Bind host (default: `0.0.0.0`)
- `PORT` - Bind port (default: `8080`)
- `REDIS_HOST` - Redis hostname (default: `localhost`)
- `REDIS_PORT` - Redis port (default: `6379`)
- `APP_NAME` - Application name (from ConfigMap)
- `APP_VERSION` - Application version (from ConfigMap)
- `ENVIRONMENT` - Environment name (from ConfigMap)

## Project Structure

```
.
├── build.sbt                     # sbt build configuration
├── Dockerfile                    # Multi-stage Docker build
├── src/
│   ├── main/
│   │   ├── scala/com/example/
│   │   │   ├── Main.scala        # Application entry point
│   │   │   ├── Routes.scala      # HTTP routes
│   │   │   ├── models/           # Data models
│   │   │   └── services/         # Business logic
│   │   └── resources/
│   │       ├── application.conf  # Akka configuration
│   │       └── logback.xml       # Logging configuration
│   └── test/                     # Unit tests
├── openshift/                    # OpenShift manifests
└── kubernetes/                   # Kubernetes manifests (generated)
```

## Technology Stack

- **Scala** 2.13
- **Akka HTTP** 10.5 - HTTP server
- **Akka Actors** 2.8 - Concurrency
- **Circe** 0.14 - JSON serialization
- **Jedis** 5.1 - Redis client
- **ScalaTest** 3.2 - Testing
- **Logback** 1.4 - Logging

## License

See [LICENSE](../../LICENSE) for details.
