# step to install argocd locally

kubectl cluster-info

# ArgoCD Setup Steps

## Quick Setup
```bash
# Use the deploy script for all operations
./deploy.sh start     # Install and start ArgoCD
./deploy.sh status    # Check status
./deploy.sh password  # Get admin password
./deploy.sh stop      # Stop and remove ArgoCD
```

## Manual Setup (if needed)
```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Port forward (use port 8100 instead of 8080)
kubectl port-forward svc/argocd-server -n argocd 8100:443 > /dev/null 2>&1 &

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

## Deploy Applications
```bash
# Deploy vector-poc application
kubectl apply -f vector/

# Create namespace first
kubectl apply -f namespace.yaml
```
