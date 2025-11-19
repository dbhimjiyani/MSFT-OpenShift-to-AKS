#!/bin/bash
# AKS Cluster Setup Script
# Automated deployment of Azure Kubernetes Service with ACR integration

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    log_error "Azure CLI is not installed. Please install it first."
    exit 1
fi

# Configuration - Override with environment variables
LOCATION="${LOCATION:-eastus}"
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-aks-migration-demo}"
ACR_NAME="${ACR_NAME:-acrmigrationdemo$(date +%s)}"
AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-aks-migration-demo}"
AKS_NODE_COUNT="${AKS_NODE_COUNT:-3}"
AKS_NODE_SIZE="${AKS_NODE_SIZE:-Standard_DS2_v2}"
KUBERNETES_VERSION="${KUBERNETES_VERSION:-1.28.3}"
TAGS="${TAGS:-environment=demo project=aro-to-aks-migration}"

log_info "==================================================="
log_info "AKS Cluster Setup Script"
log_info "==================================================="
log_info "Configuration:"
log_info "  Location: $LOCATION"
log_info "  Resource Group: $RESOURCE_GROUP"
log_info "  ACR Name: $ACR_NAME"
log_info "  AKS Cluster: $AKS_CLUSTER_NAME"
log_info "  Node Count: $AKS_NODE_COUNT"
log_info "  Node Size: $AKS_NODE_SIZE"
log_info "  Kubernetes Version: $KUBERNETES_VERSION"
log_info "==================================================="

# Verify Azure login
log_info "Verifying Azure CLI login..."
if ! az account show &> /dev/null; then
    log_error "Not logged in to Azure. Please run 'az login' first."
    exit 1
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
log_info "Using subscription: $SUBSCRIPTION"

# Step 1: Create Resource Group
log_info "Creating resource group: $RESOURCE_GROUP..."
if az group show --name "$RESOURCE_GROUP" &> /dev/null; then
    log_warn "Resource group already exists. Skipping creation."
else
    az group create \
        --name "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --tags $TAGS
    log_info "Resource group created successfully."
fi

# Step 2: Create Azure Container Registry
log_info "Creating Azure Container Registry: $ACR_NAME..."
if az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    log_warn "ACR already exists. Skipping creation."
else
    az acr create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$ACR_NAME" \
        --sku Standard \
        --location "$LOCATION" \
        --admin-enabled false
    log_info "ACR created successfully."
fi

ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" --query loginServer --output tsv)
log_info "ACR Login Server: $ACR_LOGIN_SERVER"

# Step 3: Create AKS Cluster
log_info "Creating AKS cluster: $AKS_CLUSTER_NAME (this will take 5-10 minutes)..."
if az aks show --name "$AKS_CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" &> /dev/null; then
    log_warn "AKS cluster already exists. Skipping creation."
else
    az aks create \
        --resource-group "$RESOURCE_GROUP" \
        --name "$AKS_CLUSTER_NAME" \
        --location "$LOCATION" \
        --node-count "$AKS_NODE_COUNT" \
        --node-vm-size "$AKS_NODE_SIZE" \
        --kubernetes-version "$KUBERNETES_VERSION" \
        --enable-managed-identity \
        --attach-acr "$ACR_NAME" \
        --network-plugin azure \
        --network-policy azure \
        --load-balancer-sku standard \
        --enable-addons monitoring \
        --generate-ssh-keys \
        --tags $TAGS \
        --yes
    log_info "AKS cluster created successfully."
fi

# Step 4: Get AKS credentials
log_info "Getting AKS credentials..."
az aks get-credentials \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --overwrite-existing

# Step 5: Verify cluster access
log_info "Verifying cluster access..."
kubectl get nodes

# Step 6: Install Helm if not present
if ! command -v helm &> /dev/null; then
    log_info "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    log_info "Helm already installed: $(helm version --short)"
fi

# Step 7: Install NGINX Ingress Controller
log_info "Installing NGINX Ingress Controller..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

if kubectl get namespace ingress-nginx &> /dev/null; then
    log_warn "ingress-nginx namespace already exists. Checking if ingress is installed..."
    if helm list -n ingress-nginx | grep -q ingress-nginx; then
        log_warn "NGINX Ingress already installed. Skipping."
    else
        helm install ingress-nginx ingress-nginx/ingress-nginx \
            --namespace ingress-nginx \
            --create-namespace \
            --set controller.replicaCount=2 \
            --set controller.nodeSelector."kubernetes\.io/os"=linux \
            --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
            --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux
        log_info "NGINX Ingress Controller installed."
    fi
else
    kubectl create namespace ingress-nginx
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --set controller.replicaCount=2 \
        --set controller.nodeSelector."kubernetes\.io/os"=linux \
        --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
        --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux
    log_info "NGINX Ingress Controller installed."
fi

# Step 8: Wait for ingress controller external IP
log_info "Waiting for ingress controller external IP (this may take 2-3 minutes)..."
COUNTER=0
MAX_ATTEMPTS=30
while [ $COUNTER -lt $MAX_ATTEMPTS ]; do
    INGRESS_IP=$(kubectl --namespace ingress-nginx get services ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$INGRESS_IP" ]; then
        log_info "Ingress Controller External IP: $INGRESS_IP"
        break
    fi
    sleep 10
    COUNTER=$((COUNTER+1))
    echo -n "."
done
echo ""

if [ -z "$INGRESS_IP" ]; then
    log_warn "Could not retrieve ingress IP automatically. Check manually with:"
    log_warn "kubectl --namespace ingress-nginx get services ingress-nginx-controller"
fi

# Step 9: Create scala-demo namespace
log_info "Creating scala-demo namespace..."
kubectl create namespace scala-demo || log_warn "Namespace scala-demo already exists."

# Step 10: Verify ACR integration
log_info "Verifying ACR integration..."
az aks check-acr \
    --resource-group "$RESOURCE_GROUP" \
    --name "$AKS_CLUSTER_NAME" \
    --acr "$ACR_LOGIN_SERVER" || log_warn "ACR check returned warnings (may be expected)."

# Summary
log_info "==================================================="
log_info "AKS Cluster Setup Complete!"
log_info "==================================================="
log_info "Resource Group: $RESOURCE_GROUP"
log_info "ACR: $ACR_LOGIN_SERVER"
log_info "AKS Cluster: $AKS_CLUSTER_NAME"
log_info "Ingress IP: ${INGRESS_IP:-'Not yet assigned'}"
log_info ""
log_info "To access your cluster:"
log_info "  kubectl config use-context $AKS_CLUSTER_NAME"
log_info "  kubectl get nodes"
log_info ""
log_info "To push images to ACR:"
log_info "  az acr login --name $ACR_NAME"
log_info "  docker tag <image> $ACR_LOGIN_SERVER/<image>:<tag>"
log_info "  docker push $ACR_LOGIN_SERVER/<image>:<tag>"
log_info "==================================================="

# Save configuration to file
CONFIG_FILE="$HOME/.aks-migration-config"
cat > "$CONFIG_FILE" <<EOF
# AKS Migration Configuration
export LOCATION="$LOCATION"
export RESOURCE_GROUP="$RESOURCE_GROUP"
export ACR_NAME="$ACR_NAME"
export ACR_LOGIN_SERVER="$ACR_LOGIN_SERVER"
export AKS_CLUSTER_NAME="$AKS_CLUSTER_NAME"
export INGRESS_IP="$INGRESS_IP"
EOF

log_info "Configuration saved to: $CONFIG_FILE"
log_info "Source it with: source $CONFIG_FILE"
