#!/bin/bash
# Deploy converted manifests to AKS
# Usage: ./deploy-to-aks.sh --manifests-dir <dir> --namespace <ns>

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Defaults
MANIFESTS_DIR="./converted"
NAMESPACE="scala-demo"
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --manifests-dir) MANIFESTS_DIR="$2"; shift 2 ;;
        --namespace) NAMESPACE="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

log_info "Deploying manifests from: $MANIFESTS_DIR"
log_info "Target namespace: $NAMESPACE"

# Ensure namespace exists
if ! kubectl get namespace "$NAMESPACE" &>/dev/null; then
    log_info "Creating namespace: $NAMESPACE"
    kubectl create namespace "$NAMESPACE"
fi

# Set namespace context
kubectl config set-context --current --namespace="$NAMESPACE"

# Deploy order: ConfigMaps, Secrets, Services, Deployments, Ingress
DEPLOY_ORDER=("configmap" "secret" "service" "deployment" "ingress")

for type in "${DEPLOY_ORDER[@]}"; do
    log_info "Deploying ${type}s..."
    for file in "$MANIFESTS_DIR"/*-${type}.yaml; do
        if [ -f "$file" ]; then
            log_info "  Applying: $(basename "$file")"
            if [ "$DRY_RUN" = true ]; then
                kubectl apply -f "$file" --dry-run=client
            else
                kubectl apply -f "$file"
            fi
        fi
    done
done

if [ "$DRY_RUN" = false ]; then
    log_info "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod --all --timeout=120s || log_warn "Some pods not ready yet"
    
    log_info "Deployment complete! Current status:"
    kubectl get all
fi
