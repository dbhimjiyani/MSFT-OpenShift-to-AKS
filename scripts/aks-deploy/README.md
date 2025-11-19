# AKS Deployment Scripts

Automated scripts for deploying and managing Azure Kubernetes Service (AKS) clusters.

## Scripts

### setup-aks-cluster.sh

Fully automated script to create an AKS cluster with all required components.

**Creates:**
- Azure Resource Group
- Azure Container Registry (ACR)
- AKS cluster with ACR integration
- NGINX Ingress Controller
- scala-demo namespace

**Usage:**

```bash
# Basic usage with defaults
./setup-aks-cluster.sh

# With custom configuration
export LOCATION="westus2"
export RESOURCE_GROUP="my-aks-rg"
export AKS_CLUSTER_NAME="my-aks-cluster"
export AKS_NODE_COUNT=4
./setup-aks-cluster.sh
```

**Configuration Options:**

| Variable | Default | Description |
|----------|---------|-------------|
| `LOCATION` | eastus | Azure region |
| `RESOURCE_GROUP` | rg-aks-migration-demo | Resource group name |
| `ACR_NAME` | acrmigrationdemo{timestamp} | ACR name (must be unique) |
| `AKS_CLUSTER_NAME` | aks-migration-demo | AKS cluster name |
| `AKS_NODE_COUNT` | 3 | Number of nodes |
| `AKS_NODE_SIZE` | Standard_DS2_v2 | Node VM size |
| `KUBERNETES_VERSION` | 1.28.3 | Kubernetes version |
| `TAGS` | environment=demo... | Resource tags |

**Output:**

The script saves configuration to `~/.aks-migration-config`:

```bash
# Load configuration
source ~/.aks-migration-config

# Use variables
echo $ACR_LOGIN_SERVER
echo $INGRESS_IP
```

## Prerequisites

- Azure CLI installed and configured
- kubectl installed (or script will install)
- Helm 3 (or script will install)
- Sufficient Azure subscription quota

## See Also

- [Module 10 - Setup AKS Cluster](../../Module-10-setup-aks-cluster.md)
