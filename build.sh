#!/bin/bash
set -euo pipefail

print_help() {
  echo ""
  echo "Usage: $0 VERSION SUF_FIX [ENV_FILE]"
  echo ""
  echo "Arguments:"
  echo "  VERSION   Image version tag (for example: 20260423-1)"
  echo "  SUF_FIX   Resource suffix used by deployment scripts (for example: demo01)"
  echo "  ENV_FILE  Optional env file for role assignment. Default: .env.uat"
  echo ""
  echo "This script runs:"
  echo "  1) image_build.sh"
  echo "  2) deploy_acr_app.sh"
  echo "  3) deploy_role_assignment.sh"
  echo "  4) wait for ACR readiness"
  echo "  5) image_public_release.sh"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  print_help
  exit 0
fi

if [ $# -lt 2 ]; then
  print_help
  exit 1
fi

VERSION="$1"
SUF_FIX="$2"
ENV_FILE="${3:-.env.uat}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

ORAG_NAME="mwai"
ACR_NAME="advrag${ORAG_NAME}${SUF_FIX}"
RESOURCE_GROUP="rg-${ORAG_NAME}-${SUF_FIX}"
ENVIRONMENT="env-${ORAG_NAME}-containerapps"
API_NAME="advrag-${ORAG_NAME}-${SUF_FIX}"
USER_ASSIGNED_IDENTITY_NAME="user-${ORAG_NAME}-${SUF_FIX}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

resource_group_exists() {
  az group exists --name "$RESOURCE_GROUP" -o tsv | tr -d '\r'
}

acr_exists() {
  az acr show --name "$ACR_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1
}

containerapp_env_exists() {
  az containerapp env show --name "$ENVIRONMENT" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1
}

containerapp_exists() {
  az containerapp show --name "$API_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1
}

identity_exists() {
  az identity show --name "$USER_ASSIGNED_IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1
}

wait_for_acr_ready() {
  local attempts=30
  local delay_seconds=10
  local state=""

  echo "Waiting for ACR $ACR_NAME to be ready before public release..."

  for ((i=1; i<=attempts; i++)); do
    state=$(az acr show --name "$ACR_NAME" --query provisioningState -o tsv 2>/dev/null | tr -d '\r' || true)

    if [ "$state" = "Succeeded" ]; then
      echo "ACR provisioning state is Succeeded. Validating login..."
      if az acr login --name "$ACR_NAME" >/dev/null 2>&1; then
        echo "ACR $ACR_NAME is ready."
        return 0
      fi
    fi

    echo "[$i/$attempts] ACR not ready yet (state: ${state:-unknown}). Retrying in ${delay_seconds}s..."
    sleep "$delay_seconds"
  done

  echo "ACR $ACR_NAME did not become ready in time."
  exit 1
}

require_cmd az
require_cmd docker

if [ ! -f "$ENV_FILE" ]; then
  echo "Env file not found: $ENV_FILE"
  exit 1
fi

echo "[1/7] Building local image: version=$VERSION"
./image_build.sh "$VERSION"

echo "[2/7] Bootstrapping Azure resources (deploy_acr_app selective steps 1-2)"
if [ "$(resource_group_exists)" != "true" ]; then
  ./deploy_acr_app.sh "$SUF_FIX" 1
else
  echo "Resource group $RESOURCE_GROUP already exists. Skipping step 1."
fi

if ! acr_exists; then
  ./deploy_acr_app.sh "$SUF_FIX" 2
else
  echo "ACR $ACR_NAME already exists. Skipping step 2."
fi

echo "[3/7] Checking ACR readiness gate before publishing image"
wait_for_acr_ready

echo "[4/7] Publishing built image to ACR"
./push_to_acr.sh "$VERSION" "$SUF_FIX"

echo "[5/7] Deploying/updating Container App resources (deploy_acr_app selective steps 4-8/10)"
if ! containerapp_env_exists; then
  ./deploy_acr_app.sh "$SUF_FIX" 4
else
  echo "Container App environment $ENVIRONMENT already exists. Skipping step 4."
fi

if ! containerapp_exists; then
  ./deploy_acr_app.sh "$SUF_FIX" 5 "$VERSION"
  ./deploy_acr_app.sh "$SUF_FIX" 6
else
  echo "Container App $API_NAME already exists. Forcing new revision with image tag $VERSION."
  ./deploy_acr_app.sh "$SUF_FIX" 10 "$VERSION"
fi

if ! identity_exists; then
  ./deploy_acr_app.sh "$SUF_FIX" 7
else
  echo "User assigned identity $USER_ASSIGNED_IDENTITY_NAME already exists. Skipping step 7."
fi

./deploy_acr_app.sh "$SUF_FIX" 8

echo "[6/7] Applying role assignments using $ENV_FILE"
./deploy_role_assignment.sh "$SUF_FIX" 1-5 "$ENV_FILE"

echo "[7/7] Releasing image publicly and updating app image"
./image_public_release.sh "$VERSION" "$SUF_FIX"

echo "Build and release workflow completed successfully."
