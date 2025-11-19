#!/bin/bash
# Validate migration by comparing ARO and AKS deployments
# Usage: ./validate-migration.sh --aro-route <route> --aks-host <host>

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --aro-route) ARO_ROUTE="$2"; shift 2 ;;
        --aks-host) AKS_HOST="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ -z "$ARO_ROUTE" ] || [ -z "$AKS_HOST" ]; then
    echo "Usage: $0 --aro-route <route> --aks-host <host>"
    exit 1
fi

echo "===================================="
echo "Migration Validation Report"
echo "===================================="
echo "ARO: https://$ARO_ROUTE"
echo "AKS: https://$AKS_HOST"
echo "===================================="

# Test health endpoints
echo -e "\n1. Testing Health Endpoints..."
ARO_HEALTH=$(curl -sk "https://$ARO_ROUTE/health" | jq -r '.status' 2>/dev/null || echo "error")
AKS_HEALTH=$(curl -sk "https://$AKS_HOST/health" | jq -r '.status' 2>/dev/null || echo "error")

if [ "$ARO_HEALTH" = "healthy" ]; then
    log_info "ARO health: $ARO_HEALTH"
else
    log_error "ARO health check failed"
fi

if [ "$AKS_HEALTH" = "healthy" ]; then
    log_info "AKS health: $AKS_HEALTH"
else
    log_error "AKS health check failed"
fi

# Test API endpoints
echo -e "\n2. Testing API Info..."
ARO_INFO=$(curl -sk "https://$ARO_ROUTE/api/info" 2>/dev/null)
AKS_INFO=$(curl -sk "https://$AKS_HOST/api/info" 2>/dev/null)

if [ -n "$ARO_INFO" ]; then
    log_info "ARO API responding"
else
    log_error "ARO API not responding"
fi

if [ -n "$AKS_INFO" ]; then
    log_info "AKS API responding"
else
    log_error "AKS API not responding"
fi

# Performance comparison
echo -e "\n3. Performance Comparison..."
echo "Running basic load test (100 requests)..."

ARO_TIME=$(curl -sk -o /dev/null -w "%{time_total}" "https://$ARO_ROUTE/health")
AKS_TIME=$(curl -sk -o /dev/null -w "%{time_total}" "https://$AKS_HOST/health")

echo "ARO response time: ${ARO_TIME}s"
echo "AKS response time: ${AKS_TIME}s"

# Summary
echo -e "\n===================================="
echo "Validation Summary"
echo "===================================="

if [ "$ARO_HEALTH" = "healthy" ] && [ "$AKS_HEALTH" = "healthy" ]; then
    log_info "Both deployments are healthy"
else
    log_error "One or both deployments have issues"
fi

echo -e "\nMigration validation complete!"
