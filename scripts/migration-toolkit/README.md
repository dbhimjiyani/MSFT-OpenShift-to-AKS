# Migration Toolkit Scripts

Automated scripts for migrating applications from Azure Red Hat OpenShift (ARO) to Azure Kubernetes Service (AKS).

## Scripts Overview

### 1. convert-resources.sh
Converts OpenShift-specific resources to standard Kubernetes manifests.

**What it converts:**
- DeploymentConfigs → Deployments
- Routes → Ingress
- Services (cleanup)
- ConfigMaps (cleanup)
- Secrets (cleanup)

**Usage:**
```bash
./convert-resources.sh --namespace scala-demo --output ./converted
```

**Options:**
- `--namespace` - Source namespace to export from (default: scala-demo)
- `--output` - Output directory for converted manifests (default: ./converted)
- `--context` - Kubernetes context to use (optional)

### 2. push-to-acr.sh
Migrates container images to Azure Container Registry.

**Usage:**
```bash
./push-to-acr.sh --source-image myregistry/scala-app:1.0.0 --acr-name myacr
```

**Options:**
- `--source-image` - Source image to migrate (required)
- `--acr-name` - Target ACR name (required)
- `--tag` - Target tag (default: latest)

**Example:**
```bash
# Migrate from Docker Hub to ACR
./push-to-acr.sh \
  --source-image docker.io/myorg/scala-app:1.0.0 \
  --acr-name acrmigrationdemo \
  --tag 1.0.0
```

### 3. deploy-to-aks.sh
Deploys converted manifests to AKS cluster.

**Usage:**
```bash
./deploy-to-aks.sh --manifests-dir ./converted --namespace scala-demo
```

**Options:**
- `--manifests-dir` - Directory containing converted manifests (default: ./converted)
- `--namespace` - Target namespace (default: scala-demo)
- `--dry-run` - Preview changes without applying

**Deployment Order:**
1. ConfigMaps
2. Secrets
3. Services
4. Deployments
5. Ingress

### 4. validate-migration.sh
Validates the migration by comparing ARO and AKS deployments.

**Usage:**
```bash
./validate-migration.sh \
  --aro-route scala-app-scala-demo.apps.arocluster.com \
  --aks-host scala-app.20.12.34.56.nip.io
```

**What it tests:**
- Health endpoint responsiveness
- API endpoint functionality
- Basic performance comparison
- Overall migration success

## Complete Migration Workflow

```bash
# 1. Convert OpenShift resources to Kubernetes
./convert-resources.sh \
  --namespace scala-demo \
  --output ~/aro-to-aks-migration/converted

# 2. Migrate container images to ACR
source ~/.aks-migration-config
./push-to-acr.sh \
  --source-image docker.io/myorg/scala-app:1.0.0 \
  --acr-name $ACR_NAME \
  --tag 1.0.0

# 3. Update image references in converted manifests
sed -i "s|image:.*|image: ${ACR_LOGIN_SERVER}/scala-app:1.0.0|" \
  ~/aro-to-aks-migration/converted/*-deployment.yaml

# 4. Deploy to AKS
./deploy-to-aks.sh \
  --manifests-dir ~/aro-to-aks-migration/converted \
  --namespace scala-demo

# 5. Validate migration
./validate-migration.sh \
  --aro-route $ARO_ROUTE \
  --aks-host scala-app.${INGRESS_IP}.nip.io
```

## Prerequisites

- `oc` CLI (OpenShift)
- `kubectl` CLI
- Azure CLI (`az`)
- Docker
- `jq` (for validation script)
- Access to both ARO and AKS clusters

## Troubleshooting

### Script Fails with Permission Denied
```bash
chmod +x *.sh
```

### Cannot Connect to ARO
```bash
oc login <aro-api-server>
oc project scala-demo
```

### Cannot Connect to AKS
```bash
az aks get-credentials --resource-group $RESOURCE_GROUP --name $AKS_CLUSTER_NAME
kubectl config use-context $AKS_CLUSTER_NAME
```

### Image Pull Fails
```bash
# Verify ACR login
az acr login --name $ACR_NAME

# Check image exists
az acr repository list --name $ACR_NAME
```

## Advanced Usage

### Batch Migration of Multiple Namespaces
```bash
for ns in app1 app2 app3; do
  ./convert-resources.sh --namespace $ns --output ./converted/$ns
  ./deploy-to-aks.sh --manifests-dir ./converted/$ns --namespace $ns
done
```

### Custom Image Mapping
```bash
# Create a mapping file
cat > image-map.txt <<EOF
oldregistry/app1:v1 -> myacr.azurecr.io/app1:v1
oldregistry/app2:v2 -> myacr.azurecr.io/app2:v2
EOF

# Migrate images
while IFS=' -> ' read -r source target; do
  docker pull $source
  docker tag $source $target
  docker push $target
done < image-map.txt
```

## See Also

- [Module 11 - Migrate App from ARO to AKS](../../Module-11-migrate-app-to-aks.md)
- [Konveyor Crane](https://github.com/konveyor/crane) - More advanced migration tool
- [Velero](https://velero.io/) - Backup and migration tool
