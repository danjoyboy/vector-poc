# Vector POC

## Architecture
```
Backend Service -> Vector Agent -> PostgreSQL
```

This project demonstrates log collection and processing using Vector with two deployment options:

## Deployment Options

### 1. Docker Compose Deployment

For local development and testing:

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

**Services:**
- `backend` - Spring Boot application on port 9000
- `vector-agent` - Vector log processor on port 8686
- `postgresql` - Database for log storage on port 5432

### 2. ArgoCD Kubernetes Deployment

For production deployment using GitOps with ArgoCD:

**Prerequisites:**
- Kubernetes cluster
- kubectl configured
- **Application image built and pushed to registry**

**Build and push application image:**
```bash
# Build the application image
docker build -f ankle.dockerfile -t your-registry/vector-poc-backend:latest .

# Push to your container registry
docker push your-registry/vector-poc-backend:latest

# Update image reference in argocd/vector/deployment.yaml
```

**Deployment using provided script:**
```bash
# Navigate to argocd directory
cd argocd/

# Start ArgoCD
./deploy.sh start

# Deploy vector-poc application
./deploy.sh deploy vector

# Check status
./deploy.sh status

# View logs
./deploy.sh logs vector backend
./deploy.sh logs vector vector-agent

# Remove application
./deploy.sh remove vector

# Stop ArgoCD
./deploy.sh stop
```

**Manual deployment:**
```bash
# Apply ArgoCD applications
kubectl apply -f argocd/

# Monitor deployment
kubectl get pods -n vector-poc
```

**Components:**
- Backend service with Vector sidecar
- PostgreSQL with persistent storage
- Configurable via Kustomize

## Configuration

### Environment Variables (Docker Compose)
- `POSTGRES_USER`: vector_user
- `POSTGRES_PASSWORD`: vector_user
- `POSTGRES_DATABASE`: logs

### Vector Configuration
Vector processes logs from `/var/log/app/*.log` and stores them in PostgreSQL with metadata including:
- Timestamp
- Service name
- Log level (INFO, ERROR, WARN, DEBUG)
- Kubernetes metadata (namespace, pod, node)

## API Endpoints

### Backend Service
```bash
curl --location 'localhost:9000/rpc/math' \
--header 'Content-Type: application/json' \
--data '{
    "methodName": "doPlus",
    "parameters": []
}'
```

### Vector API
```bash
# Health check
curl http://localhost:8686/health

# Metrics
curl http://localhost:8686/metrics
```