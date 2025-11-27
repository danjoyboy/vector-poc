# ArgoCD Local Kubernetes Setup

This repository contains configurations for running ArgoCD locally to manage applications in your Kubernetes cluster.

## 🚀 Quick Start

### Install and Start ArgoCD
```bash
./deploy.sh start
```

### Deploy Your Application
```bash
# Deploy a specific application
./deploy.sh deploy vector

# Deploy all applications
./deploy.sh deploy all
```

### Access Services
- **ArgoCD UI**: https://localhost:8100
  - Username: `admin`
  - Password: Run `./deploy.sh password`
- **Backend API**: http://localhost:30901/healthcheck

## 📁 Project Structure

```
argocd/
├── deploy.sh              # Universal deployment script
├── vector/                # Vector application with sidecar
│   ├── configmap.yaml     # Vector configuration
│   ├── deployment.yaml    # Backend + Vector sidecar
│   └── service.yaml       # Services including NodePort
├── app/                   # Simple backend application (optional)
│   ├── deployment.yaml
│   └── service.yaml
└── namespace.yaml         # Vector POC namespace definition
```

## 🛠️ Management Script

The `deploy.sh` script provides unified management for ArgoCD and applications:

### Command Structure
```bash
./deploy.sh <command> [options]
```

### ArgoCD Management
| Command | Description |
|---------|------------|
| `start` | Install and start ArgoCD with port-forward |
| `stop` | Stop and uninstall ArgoCD completely |
| `restart` | Restart ArgoCD deployments |
| `status` | Show ArgoCD status and connection info |
| `password` | Get the admin password |

### Application Management
| Command | Description | Example |
|---------|------------|---------|
| `deploy <dir\|all>` | Deploy application(s) | `./deploy.sh deploy vector` |
| `remove <dir\|all>` | Remove application(s) | `./deploy.sh remove vector` |
| `logs <dir> <container>` | Show container logs | `./deploy.sh logs vector backend` |

## 📦 Applications

### Vector POC (vector/)
A backend application with Vector logging sidecar:
- **Namespace**: `vector-poc` (auto-detected from manifests)
- **Backend Port**: 9000
- **NodePort**: 30901 (publicly accessible)
- **Vector API**: 8686
- **Containers**: `backend`, `vector`

### Simple Backend (app/)
A standalone backend without sidecar (optional):
- **Namespace**: `app-namespace` (auto-created)
- **Port**: 9000

## 🔧 Common Tasks

### Deploy Everything
```bash
# Start ArgoCD
./deploy.sh start

# Deploy all applications
./deploy.sh deploy all
```

### Deploy Specific Application
```bash
# Deploy only vector app
./deploy.sh deploy vector

# Check status
kubectl get all -n vector-poc

# Test the endpoint
curl http://localhost:30901/healthcheck
```

### View Logs
```bash
# Backend logs
./deploy.sh logs vector backend

# Vector sidecar logs
./deploy.sh logs vector vector
```

### Remove Applications
```bash
# Remove specific app
./deploy.sh remove vector

# Remove all apps
./deploy.sh remove all
```

### Check Status
```bash
# ArgoCD status
./deploy.sh status

# Application pods
kubectl get pods -n vector-poc
```

## 🌐 Accessing Services

### ArgoCD UI
```bash
# URL: https://localhost:8100
# Get password:
./deploy.sh password
```

### Backend API
```bash
# Direct access via NodePort (no port-forward needed)
curl http://localhost:30901/healthcheck
```

## 🧹 Cleanup

### Remove Everything
```bash
# Remove all applications
./deploy.sh remove all

# Stop and remove ArgoCD
./deploy.sh stop
```

### Remove Specific Application
```bash
./deploy.sh remove vector
```

## 🐛 Troubleshooting

### Port-forward Issues
```bash
# Kill existing port-forward
pkill -f "kubectl port-forward.*argocd-server"

# Restart ArgoCD
./deploy.sh restart
```

### Application Not Deploying
```bash
# Check namespace
kubectl get namespace

# Check pods
kubectl get pods -n vector-poc

# Check events
kubectl get events -n vector-poc
```

### Can't Access Backend
```bash
# Check service
kubectl get svc -n vector-poc

# Check NodePort
kubectl get svc -n vector-poc -o jsonpath='{.items[?(@.spec.type=="NodePort")].spec.ports[0].nodePort}'
```

## 📚 Additional Resources

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Vector Documentation](https://vector.dev/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## 💡 Tips

1. **Directory-based deployment**: Each directory with a `deployment.yaml` is treated as an application
2. **Namespace detection**: The script auto-detects namespaces from your manifests
3. **NodePort access**: Services with NodePort are automatically accessible without port-forwarding
4. **Deploy all**: Use `./deploy.sh deploy all` to deploy everything at once
5. **Clean state**: Always use `./deploy.sh remove <app>` before redeploying to ensure clean state