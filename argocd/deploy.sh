#!/bin/bash

# ArgoCD Management Script
# Usage: ./deploy.sh [start|stop|restart|status|password|deploy|remove|logs] [app-directory|all]

set -e

NAMESPACE="argocd"
PORT="8100"
ARGOCD_VERSION="stable"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

function print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

function check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
}

function check_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    print_status "Kubernetes cluster is accessible"
}

function start_argocd() {
    print_status "Starting ArgoCD..."

    # Check if namespace exists
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_warning "ArgoCD namespace already exists"
    else
        print_status "Creating ArgoCD namespace..."
        kubectl create namespace $NAMESPACE
    fi

    # Check if ArgoCD is already installed
    if kubectl get deployment -n $NAMESPACE argocd-server &> /dev/null; then
        print_warning "ArgoCD is already installed"
    else
        print_status "Installing ArgoCD..."
        kubectl apply -n $NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml

        print_status "Waiting for ArgoCD deployments to be created..."
        sleep 5

        # Wait for the deployment to exist first
        kubectl wait --for=condition=available deployment/argocd-server -n $NAMESPACE --timeout=300s

        print_status "Waiting for ArgoCD pods to be ready..."
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n $NAMESPACE --timeout=300s
    fi

    # Kill existing port-forward if any
    pkill -f "kubectl port-forward.*argocd-server" 2>/dev/null || true

    # Start port-forward
    print_status "Starting port-forward on port $PORT..."
    print_status "Running: kubectl port-forward svc/argocd-server -n $NAMESPACE $PORT:443"
    kubectl port-forward svc/argocd-server -n $NAMESPACE $PORT:443 > /dev/null 2>&1 &

    sleep 2

    print_status "ArgoCD started successfully!"
    echo ""
    print_status "Access ArgoCD at: https://localhost:$PORT"
    print_status "Username: admin"
    print_status "Password: $(get_password)"
    echo ""
}

function stop_argocd() {
    print_status "Stopping ArgoCD..."

    # Kill port-forward
    print_status "Running: pkill -f 'kubectl port-forward.*argocd-server'"
    if pkill -f "kubectl port-forward.*argocd-server" 2>/dev/null; then
        print_status "Port-forward stopped"
    else
        print_warning "No port-forward process found"
    fi

    # Check if ArgoCD namespace exists
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_status "Cleaning up ArgoCD-tracked applications..."

        # Get all ArgoCD Applications and clean up their namespaces
        local APPS=$(kubectl get applications -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
        if [ ! -z "$APPS" ]; then
            for APP in $APPS; do
                local APP_NAMESPACE=$(kubectl get application $APP -n $NAMESPACE -o jsonpath='{.spec.destination.namespace}' 2>/dev/null)
                if [ ! -z "$APP_NAMESPACE" ] && [ "$APP_NAMESPACE" != "$NAMESPACE" ]; then
                    print_status "Cleaning up application $APP in namespace $APP_NAMESPACE..."

                    # For apps that might have different label patterns, try multiple approaches
                    print_status "Removing all resources for $APP..."

                    # Handle different app naming patterns
                    if [ "$APP" == "postgres" ]; then
                        kubectl delete all,configmap,secret,pvc -l app=postgres -n $APP_NAMESPACE 2>/dev/null || true
                    elif [ "$APP" == "vector" ]; then
                        kubectl delete all,configmap,secret,pvc -l app=vector-poc-backend -n $APP_NAMESPACE 2>/dev/null || true
                    else
                        # Try with app label
                        kubectl delete all,configmap,secret,pvc -l app=$APP -n $APP_NAMESPACE 2>/dev/null || true
                        # Try with app.kubernetes.io/name label
                        kubectl delete all,configmap,secret,pvc -l app.kubernetes.io/name=$APP -n $APP_NAMESPACE 2>/dev/null || true
                    fi

                    # If namespace only contains our app resources, delete the namespace
                    local REMAINING_RESOURCES=$(kubectl get all -n $APP_NAMESPACE 2>/dev/null | wc -l)
                    if [ "$REMAINING_RESOURCES" -le 1 ]; then
                        print_status "Deleting empty application namespace $APP_NAMESPACE..."
                        kubectl delete namespace $APP_NAMESPACE 2>/dev/null || true
                    fi
                fi
            done
        fi

        print_status "Removing ArgoCD installation..."
        kubectl delete -n $NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml 2>/dev/null || true

        print_status "Deleting ArgoCD namespace..."
        kubectl delete namespace $NAMESPACE --wait=true

        print_status "ArgoCD and all tracked applications stopped and removed successfully!"
    else
        print_warning "ArgoCD namespace not found"
    fi
}

function restart_argocd() {
    print_status "Restarting ArgoCD..."

    # Kill existing port-forward
    print_status "Running: pkill -f 'kubectl port-forward.*argocd-server'"
    pkill -f "kubectl port-forward.*argocd-server" 2>/dev/null || true

    # Restart deployments
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_status "Restarting ArgoCD deployments..."
        kubectl rollout restart deployment -n $NAMESPACE

        print_status "Waiting for rollout to complete..."
        kubectl rollout status deployment/argocd-server -n $NAMESPACE --timeout=300s

        print_status "Waiting for pods to be ready..."
        kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n $NAMESPACE --timeout=300s

        # Start new port-forward
        print_status "Starting port-forward on port $PORT..."
        print_status "Running: kubectl port-forward svc/argocd-server -n $NAMESPACE $PORT:443"
        kubectl port-forward svc/argocd-server -n $NAMESPACE $PORT:443 > /dev/null 2>&1 &

        sleep 2

        print_status "ArgoCD restarted successfully!"
        echo ""
        print_status "Access ArgoCD at: https://localhost:$PORT"
    else
        print_warning "ArgoCD is not installed. Starting fresh installation..."
        start_argocd
    fi
}

function get_password() {
    if kubectl get secret argocd-initial-admin-secret -n $NAMESPACE &> /dev/null; then
        kubectl -n $NAMESPACE get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
    else
        echo "Password not available (ArgoCD not installed or secret deleted)"
    fi
}

function show_status() {
    print_status "Checking ArgoCD status..."
    echo ""

    # Check namespace
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        echo -e "${GREEN}✓${NC} ArgoCD namespace exists"

        # Check pods
        echo ""
        print_status "ArgoCD Pods:"
        kubectl get pods -n $NAMESPACE

        # Check if port-forward is running
        echo ""
        if pgrep -f "kubectl port-forward.*argocd-server" > /dev/null; then
            echo -e "${GREEN}✓${NC} Port-forward is active on port $PORT"
            echo ""
            print_status "Access URL: https://localhost:$PORT"
            print_status "Username: admin"
            print_status "Password: $(get_password)"
        else
            echo -e "${YELLOW}✗${NC} Port-forward is not running"
            echo ""
            print_warning "Run './deploy.sh start' to start port-forward"
        fi

        # Check applications
        echo ""
        print_status "ArgoCD Applications:"
        kubectl get applications -n $NAMESPACE 2>/dev/null || echo "No applications found"

    else
        echo -e "${RED}✗${NC} ArgoCD is not installed"
        echo ""
        print_warning "Run './deploy.sh start' to install ArgoCD"
    fi
}

function deploy_app() {
    local APP_DIR=$1

    if [ -z "$APP_DIR" ]; then
        print_error "Usage: ./deploy.sh deploy <directory|all>"
        exit 1
    fi

    if [ "$APP_DIR" == "all" ]; then
        print_status "Deploying all applications..."
        for dir in */; do
            if [ -d "$dir" ] && [ "$dir" != ".git/" ] && [ "$dir" != ".claude/" ] && [ -f "$dir/deployment.yaml" ]; then
                deploy_single_app "${dir%/}"
            fi
        done
    else
        if [ ! -d "$APP_DIR" ]; then
            print_error "Directory $APP_DIR does not exist"
            exit 1
        fi
        deploy_single_app "$APP_DIR"
    fi
}

function deploy_single_app() {
    local DIR=$1
    local APP_NAME=$(basename "$DIR")

    # Check if namespace is specified in the manifests
    local APP_NAMESPACE=$(grep -h "namespace:" "$DIR"/*.yaml 2>/dev/null | head -1 | awk '{print $2}')

    # Default to app-namespace if not found
    if [ -z "$APP_NAMESPACE" ]; then
        APP_NAMESPACE="${APP_NAME}-namespace"
    fi

    print_status "Deploying $APP_NAME from $DIR/..."

    # Create namespace if it doesn't exist
    if ! kubectl get namespace $APP_NAMESPACE &> /dev/null; then
        print_status "Creating namespace $APP_NAMESPACE..."
        kubectl create namespace $APP_NAMESPACE
    fi

    # Apply manifests using kustomize if available, otherwise regular apply
    if [ -f "$DIR/kustomization.yaml" ]; then
        print_status "Applying manifests using kustomize from $DIR/ to namespace $APP_NAMESPACE..."
        kubectl apply -k "$DIR/" 2>&1 || true
    else
        print_status "Applying manifests from $DIR/ to namespace $APP_NAMESPACE..."
        kubectl apply -f "$DIR/" 2>&1 || true
    fi

    # Create ArgoCD Application to track this deployment
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_status "Creating ArgoCD Application for $APP_NAME..."
        cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $APP_NAME
  namespace: $NAMESPACE
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps
    targetRevision: HEAD
    path: guestbook
    directory:
      recurse: false
      include: 'nothing.yaml'
  destination:
    server: https://kubernetes.default.svc
    namespace: $APP_NAMESPACE
  syncPolicy:
    syncOptions:
    - CreateNamespace=false
EOF

        # Add tracking annotation to deployments that belong to this app
        for deployment in $(kubectl get deployment -n $APP_NAMESPACE -o name 2>/dev/null); do
            deployment_name=$(basename $deployment)
            # Only annotate if deployment name contains the app name
            if [[ $deployment_name == *"$APP_NAME"* ]]; then
                kubectl annotate $deployment -n $APP_NAMESPACE "argocd.argoproj.io/tracking-id=$APP_NAME:apps/Deployment:$APP_NAMESPACE/$deployment_name" --overwrite 2>/dev/null || true
            fi
        done
    fi

    print_status "$APP_NAME deployed successfully to namespace $APP_NAMESPACE!"

    # Show service endpoints if NodePort exists
    local NODEPORT=$(kubectl get svc -n $APP_NAMESPACE -o jsonpath='{.items[?(@.spec.type=="NodePort")].spec.ports[0].nodePort}' 2>/dev/null)
    if [ ! -z "$NODEPORT" ]; then
        print_status "Service available at: http://localhost:$NODEPORT"
    fi

    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_status "View in ArgoCD UI: https://localhost:$PORT/applications/$APP_NAME"
    fi
    echo ""
}

function remove_app() {
    local APP_DIR=$1

    if [ -z "$APP_DIR" ]; then
        print_error "Usage: ./deploy.sh remove <directory|all>"
        exit 1
    fi

    if [ "$APP_DIR" == "all" ]; then
        print_status "Removing all applications..."
        for dir in */; do
            if [ -d "$dir" ] && [ "$dir" != ".git/" ] && [ "$dir" != ".claude/" ] && [ -f "$dir/deployment.yaml" ]; then
                remove_single_app "${dir%/}"
            fi
        done
    else
        if [ ! -d "$APP_DIR" ]; then
            print_error "Directory $APP_DIR does not exist"
            exit 1
        fi
        remove_single_app "$APP_DIR"
    fi
}

function remove_single_app() {
    local DIR=$1
    local APP_NAME=$(basename "$DIR")

    # Check if namespace is specified in the manifests
    local APP_NAMESPACE=$(grep -h "namespace:" "$DIR"/*.yaml 2>/dev/null | head -1 | awk '{print $2}')

    # Default to app-namespace if not found
    if [ -z "$APP_NAMESPACE" ]; then
        APP_NAMESPACE="${APP_NAME}-namespace"
    fi

    print_status "Removing $APP_NAME from namespace $APP_NAMESPACE..."

    # Delete ArgoCD Application if exists
    if kubectl get application $APP_NAME -n $NAMESPACE &> /dev/null 2>&1; then
        kubectl delete application $APP_NAME -n $NAMESPACE
        print_status "ArgoCD Application removed"
    fi

    # Delete resources
    if kubectl get namespace $APP_NAMESPACE &> /dev/null; then
        # Check if kustomization.yaml exists
        if [ -f "$DIR/kustomization.yaml" ]; then
            print_status "Removing resources using kustomize..."
            kubectl delete -k "$DIR/" 2>/dev/null || true
        else
            kubectl delete -f "$DIR/" 2>/dev/null || true
        fi

        # Clean up ConfigMaps related to this app
        print_status "Cleaning up ConfigMaps for $APP_NAME..."
        kubectl delete configmap -l app=$APP_NAME -n $APP_NAMESPACE 2>/dev/null || true

        # Clean up Secrets related to this app
        print_status "Cleaning up Secrets for $APP_NAME..."
        kubectl delete secret -l app=$APP_NAME -n $APP_NAMESPACE 2>/dev/null || true

        # Delete PVCs related to this app
        print_status "Cleaning up persistent volumes for $APP_NAME..."
        kubectl delete pvc -l app=$APP_NAME -n $APP_NAMESPACE 2>/dev/null || true

        print_status "$APP_NAME removed successfully!"
    else
        print_warning "Namespace $APP_NAMESPACE not found"
    fi
}

function app_logs() {
    local APP_DIR=$1
    local CONTAINER=$2

    if [ -z "$APP_DIR" ] || [ -z "$CONTAINER" ]; then
        print_error "Usage: ./deploy.sh logs <directory> <container>"
        print_status "Example: ./deploy.sh logs vector backend"
        exit 1
    fi

    local APP_NAME=$(basename "$APP_DIR")

    # Check if namespace is specified in the manifests
    local APP_NAMESPACE=$(grep -h "namespace:" "$APP_DIR"/*.yaml 2>/dev/null | head -1 | awk '{print $2}')

    # Default to app-namespace if not found
    if [ -z "$APP_NAMESPACE" ]; then
        APP_NAMESPACE="${APP_NAME}-namespace"
    fi

    print_status "Showing logs for $CONTAINER in $APP_NAME (namespace: $APP_NAMESPACE)..."

    # Find pods with the app label
    local POD=$(kubectl get pods -n $APP_NAMESPACE -o name | head -1)

    if [ -z "$POD" ]; then
        print_error "No pods found in namespace $APP_NAMESPACE"
        exit 1
    fi

    kubectl logs -n $APP_NAMESPACE $POD -c $CONTAINER --tail=50 -f
}

function show_help() {
    echo "ArgoCD and Application Management Script"
    echo ""
    echo "Usage: ./deploy.sh <command> [options]"
    echo ""
    echo "ArgoCD Management:"
    echo "  start                    Install and start ArgoCD"
    echo "  stop                     Stop and uninstall ArgoCD"
    echo "  restart                  Restart ArgoCD"
    echo "  status                   Show ArgoCD status"
    echo "  password                 Get ArgoCD admin password"
    echo ""
    echo "Application Management:"
    echo "  deploy <dir|all>         Deploy application(s)"
    echo "  remove <dir|all>         Remove application(s)"
    echo "  logs <dir> <container>   Show container logs"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh start                # Start ArgoCD"
    echo "  ./deploy.sh deploy vector        # Deploy vector app"
    echo "  ./deploy.sh deploy all           # Deploy all apps"
    echo "  ./deploy.sh logs vector backend  # Show backend logs"
    echo "  ./deploy.sh remove vector        # Remove vector app"
    echo "  ./deploy.sh stop                 # Stop ArgoCD"
}

# Main script
check_kubectl
check_cluster

case "$1" in
    start)
        start_argocd
        ;;
    stop)
        stop_argocd
        ;;
    restart)
        restart_argocd
        ;;
    status)
        show_status
        ;;
    password)
        PASSWORD=$(get_password)
        print_status "Admin password: $PASSWORD"
        ;;
    deploy)
        deploy_app "$2"
        ;;
    remove)
        remove_app "$2"
        ;;
    logs)
        app_logs "$2" "$3"
        ;;
    help|--help|-h|"")
        show_help
        ;;
    *)
        print_error "Invalid command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac