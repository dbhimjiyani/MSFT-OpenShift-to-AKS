#!/bin/bash
# Convert OpenShift resources to Kubernetes manifests
# Usage: ./convert-resources.sh --namespace <ns> --output <dir>

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Default values
NAMESPACE="scala-demo"
OUTPUT_DIR="./converted"
SOURCE_CONTEXT=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace) NAMESPACE="$2"; shift 2 ;;
        --output) OUTPUT_DIR="$2"; shift 2 ;;
        --context) SOURCE_CONTEXT="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

log_info "Converting OpenShift resources from namespace: $NAMESPACE"
log_info "Output directory: $OUTPUT_DIR"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Switch context if specified
if [ -n "$SOURCE_CONTEXT" ]; then
    kubectl config use-context "$SOURCE_CONTEXT"
fi

# Export and convert DeploymentConfig to Deployment
log_info "Converting DeploymentConfig to Deployment..."
if oc get dc -n "$NAMESPACE" &>/dev/null; then
    for dc in $(oc get dc -n "$NAMESPACE" -o name | cut -d/ -f2); do
        oc get dc "$dc" -n "$NAMESPACE" -o yaml | \
        sed 's/kind: DeploymentConfig/kind: Deployment/' | \
        sed '/^  triggers:/,/^  [a-z]/d' | \
        sed '/^  test:/d' | \
        sed '/resourceVersion:/d; /uid:/d; /selfLink:/d; /creationTimestamp:/d' | \
        sed '/status:/,$d' > "$OUTPUT_DIR/${dc}-deployment.yaml"
        log_info "Converted: ${dc}-deployment.yaml"
    done
fi

# Export and convert Routes to Ingress
log_info "Converting Routes to Ingress..."
if oc get routes -n "$NAMESPACE" &>/dev/null; then
    for route in $(oc get routes -n "$NAMESPACE" -o name | cut -d/ -f2); do
        HOST=$(oc get route "$route" -n "$NAMESPACE" -o jsonpath='{.spec.host}')
        SVC=$(oc get route "$route" -n "$NAMESPACE" -o jsonpath='{.spec.to.name}')
        PORT=$(oc get route "$route" -n "$NAMESPACE" -o jsonpath='{.spec.port.targetPort}')
        
        cat > "$OUTPUT_DIR/${route}-ingress.yaml" <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: $route
  namespace: $NAMESPACE
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  rules:
  - host: $HOST
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: $SVC
            port:
              number: ${PORT:-8080}
EOF
        log_info "Converted: ${route}-ingress.yaml"
    done
fi

# Export Services (minimal changes)
log_info "Exporting Services..."
for svc in $(oc get svc -n "$NAMESPACE" -o name | cut -d/ -f2); do
    oc get svc "$svc" -n "$NAMESPACE" -o yaml | \
    sed '/resourceVersion:/d; /uid:/d; /selfLink:/d; /creationTimestamp:/d' | \
    sed '/clusterIP:/d; /clusterIPs:/d' | \
    sed '/status:/,$d' > "$OUTPUT_DIR/${svc}-service.yaml"
    log_info "Exported: ${svc}-service.yaml"
done

# Export ConfigMaps
log_info "Exporting ConfigMaps..."
for cm in $(oc get configmap -n "$NAMESPACE" -o name | cut -d/ -f2); do
    oc get configmap "$cm" -n "$NAMESPACE" -o yaml | \
    sed '/resourceVersion:/d; /uid:/d; /selfLink:/d; /creationTimestamp:/d' > "$OUTPUT_DIR/${cm}-configmap.yaml"
    log_info "Exported: ${cm}-configmap.yaml"
done

# Export Secrets
log_info "Exporting Secrets..."
for secret in $(oc get secrets -n "$NAMESPACE" -o name | grep -v 'default-token' | cut -d/ -f2); do
    oc get secret "$secret" -n "$NAMESPACE" -o yaml | \
    sed '/resourceVersion:/d; /uid:/d; /selfLink:/d; /creationTimestamp:/d' > "$OUTPUT_DIR/${secret}-secret.yaml"
    log_info "Exported: ${secret}-secret.yaml"
done

log_info "Conversion complete! Manifests saved to: $OUTPUT_DIR"
log_info "Review the files and update image references before deploying to AKS."
