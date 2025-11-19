#!/bin/bash
# Push container images from source registry to Azure Container Registry
# Usage: ./push-to-acr.sh --source-image <image> --acr-name <acr>

set -e

GREEN='\033[0;32m'
NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --source-image) SOURCE_IMAGE="$2"; shift 2 ;;
        --acr-name) ACR_NAME="$2"; shift 2 ;;
        --tag) TAG="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

if [ -z "$SOURCE_IMAGE" ] || [ -z "$ACR_NAME" ]; then
    echo "Usage: $0 --source-image <image> --acr-name <acr> [--tag <tag>]"
    exit 1
fi

TAG="${TAG:-latest}"

log_info "Migrating image: $SOURCE_IMAGE"
log_info "Target ACR: $ACR_NAME"

# Login to ACR
log_info "Logging in to ACR..."
az acr login --name "$ACR_NAME"

# Get ACR login server
ACR_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
log_info "ACR Server: $ACR_SERVER"

# Extract image name
IMAGE_NAME=$(echo "$SOURCE_IMAGE" | awk -F'/' '{print $NF}' | cut -d':' -f1)

# Pull source image
log_info "Pulling source image..."
docker pull "$SOURCE_IMAGE"

# Tag for ACR
TARGET_IMAGE="${ACR_SERVER}/${IMAGE_NAME}:${TAG}"
log_info "Tagging as: $TARGET_IMAGE"
docker tag "$SOURCE_IMAGE" "$TARGET_IMAGE"

# Push to ACR
log_info "Pushing to ACR..."
docker push "$TARGET_IMAGE"

log_info "Image migration complete!"
log_info "Use in manifests: $TARGET_IMAGE"
