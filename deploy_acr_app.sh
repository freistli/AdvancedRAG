#!/bin/bash
set -e


print_help() {
  echo ""
  echo "Usage: $0 SUF_FIX [STEP] [IMAGE_TAG]"
  echo
  echo "Arguments:"
  echo "  SUF_FIX    A suffix to be used for naming resources. It should be an integer or a short string."
  echo "  STEP       (Optional) Specify which steps to execute:"
  echo "             - A single step number (e.g., 5) to execute only that step."
  echo "             - A range of steps (e.g., 2-5) to execute steps 2, 3, 4, and 5."
  echo "  IMAGE_TAG  (Optional) Container image tag to deploy. Default: latest"
  echo
  echo "Examples:"
  echo "  $0 01"
  echo "  $0 demo01 3"
  echo "  $0 demo 2-4"
  echo "  $0 demo 10 20260423-1"

  echo "Steps:"
    echo "  1. Create Resource Group"
    echo "  2. Create Azure Container Registry"
    echo "  3. Build and Push Docker Image to Azure Container Registry"
    echo "  4. Create Azure Container App Environment"
    echo "  5. Create Azure Container App"
    echo "  6. Set Session Affinity for App Frontend"
    echo "  7. Create User Assigned Identity"
    echo "  8. Assign User Assigned Identity to Container App"
    echo "  9. Redeploy Azure Container App (legacy)"
    echo "  10. Force new Container App revision for image tag"
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  print_help
  exit 0
fi

if [ $# -eq 0 ]
then
echo "No SUF_FIX supplied, it should be an integer or a short string"
print_help
exit 1
fi

ORAG_NAME="mwai"
SUF_FIX=$1
RESOURCE_GROUP="rg-${ORAG_NAME}-${SUF_FIX}"
LOCATION="eastus2"
ENVIRONMENT="env-${ORAG_NAME}-containerapps"
API_NAME="advrag-${ORAG_NAME}-${SUF_FIX}"
FRONTEND_NAME="advrag-ui-${SUF_FIX}"
TARGET_PORT=8000
ACR_NAME="advrag${ORAG_NAME}${SUF_FIX}"
USER_ASSIGNED_IDENTITY_NAME="user-${ORAG_NAME}-${SUF_FIX}"
VNET_NAME="vnet-${ORAG_NAME}-${SUF_FIX}"
VNET_ADDRESS_PREFIX="10.0.0.0/16"
INFRA_SUBNET_NAME="snet-containerapps-infra"
INFRA_SUBNET_PREFIX="10.0.0.0/27"
IMAGE_TAG=${3:-latest}
IMAGE_REF="$ACR_NAME.azurecr.io/$API_NAME:$IMAGE_TAG"

sanitize_revision_part() {
  local value="$1"

  value=$(echo "$value" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//; s/-{2,}/-/g')
  echo "$value"
}

generate_revision_suffix() {
  local timestamp
  local sanitized_tag
  local short_tag

  timestamp=$(date -u +%m%d%H%M%S)
  sanitized_tag=$(sanitize_revision_part "$IMAGE_TAG")
  short_tag=$(echo "$sanitized_tag" | cut -c1-18 | sed -E 's/-+$//')

  if [ -z "$short_tag" ]; then
    echo "img-${timestamp}"
  else
    echo "img-${short_tag}-${timestamp}"
  fi
}

update_container_app_image() {
  local revision_suffix

  revision_suffix=$(generate_revision_suffix)

  echo "   Deploying image $IMAGE_REF"
  echo "   Creating revision suffix $revision_suffix"

  az containerapp update \
    --name "$API_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --image "$IMAGE_REF" \
    --revision-suffix "$revision_suffix" \
    --query properties.latestRevisionName -o tsv
}

execute_step() {
  case $1 in
    1)
        echo "1. Creating resource group $RESOURCE_GROUP in $LOCATION" 
        az group create --name $RESOURCE_GROUP --location "$LOCATION"
        ;;
    2)
        echo "2. Creating Azure Container Registry $ACR_NAME in $LOCATION" 
        az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true
        ;;
    3)
      echo "3. Building and pushing Docker image $API_NAME:$IMAGE_TAG to Azure Container Registry $ACR_NAME" 
      az acr build --registry $ACR_NAME --image "$API_NAME:$IMAGE_TAG" .
        ;;
    4)
      echo "4. Creating Azure Container App Environment $ENVIRONMENT with VNet $VNET_NAME in $LOCATION"

      if ! az network vnet show --resource-group $RESOURCE_GROUP --name $VNET_NAME >/dev/null 2>&1; then
        echo "   Creating virtual network $VNET_NAME with address space $VNET_ADDRESS_PREFIX"
        az network vnet create \
          --resource-group $RESOURCE_GROUP \
          --name $VNET_NAME \
          --location "$LOCATION" \
          --address-prefixes $VNET_ADDRESS_PREFIX \
          --subnet-name $INFRA_SUBNET_NAME \
          --subnet-prefixes $INFRA_SUBNET_PREFIX >/dev/null
      fi

      if ! az network vnet subnet show --resource-group $RESOURCE_GROUP --vnet-name $VNET_NAME --name $INFRA_SUBNET_NAME >/dev/null 2>&1; then
        echo "   Creating subnet $INFRA_SUBNET_NAME with prefix $INFRA_SUBNET_PREFIX"
        az network vnet subnet create \
          --resource-group $RESOURCE_GROUP \
          --vnet-name $VNET_NAME \
          --name $INFRA_SUBNET_NAME \
          --address-prefixes $INFRA_SUBNET_PREFIX \
          --delegations Microsoft.App/environments >/dev/null
      else
        echo "   Ensuring subnet $INFRA_SUBNET_NAME is delegated to Microsoft.App/environments"
        az network vnet subnet update \
          --resource-group $RESOURCE_GROUP \
          --vnet-name $VNET_NAME \
          --name $INFRA_SUBNET_NAME \
          --delegations Microsoft.App/environments >/dev/null
      fi

      INFRA_SUBNET_ID=$(az network vnet subnet show \
        --resource-group $RESOURCE_GROUP \
        --vnet-name $VNET_NAME \
        --name $INFRA_SUBNET_NAME \
        --query id -o tsv | tr -d '\r')

      az containerapp env create \
        --name $ENVIRONMENT \
        --resource-group $RESOURCE_GROUP \
        --location "$LOCATION" \
        --infrastructure-subnet-resource-id "$INFRA_SUBNET_ID"
        ;;
    5)
      echo "5. Creating Azure Container App $API_NAME in $ENVIRONMENT with image $IMAGE_REF" 
      az containerapp create --name $API_NAME --resource-group $RESOURCE_GROUP --environment $ENVIRONMENT --image "$IMAGE_REF" --target-port $TARGET_PORT --ingress external --registry-server $ACR_NAME.azurecr.io --query properties.configuration.ingress.fqdn
        ;;  
    6)
        echo "6. Set Session Affinity for App Frontend $FRONTEND_NAME in $ENVIRONMENT" 
        az containerapp ingress sticky-sessions set -n $API_NAME -g $RESOURCE_GROUP --affinity sticky
        ;;
    7)
        echo "7. Create User Assigned Identity $USER_ASSIGNED_IDENTITY_NAME" 
        az identity create -g $RESOURCE_GROUP -n $USER_ASSIGNED_IDENTITY_NAME
        ;;
    8)     
        echo "8. Assigning User Assigned Identity $USER_ASSIGNED_IDENTITY_NAME to Container App $API_NAME" 
        IDENTITY_ID=$(az identity show -g $RESOURCE_GROUP -n $USER_ASSIGNED_IDENTITY_NAME --query id -o tsv | tr -d '\r')
        az containerapp identity assign --name $API_NAME --resource-group $RESOURCE_GROUP --user-assigned "$IDENTITY_ID"
        ;;
    9)
      echo "9. Redeploy Azure Container App $API_NAME in $ENVIRONMENT using az containerapp up with image $IMAGE_REF"
      az containerapp up --name $API_NAME --image "$IMAGE_REF" --ingress external --target-port $TARGET_PORT --resource-group $RESOURCE_GROUP
      ;;
    10)
      echo "10. Forcing a new revision for Azure Container App $API_NAME with image $IMAGE_REF"
      update_container_app_image
        ;;
    *)
        echo "Invalid step: $1"
        ;;
    esac
}


if [ $# -ge 2 ]; then
  if [[ "$2" =~ ^[0-9]+$ ]]; then
    execute_step $2
  elif [[ "$2" =~ ^([0-9]+)-([0-9]+)$ ]]; then
    for ((i=${BASH_REMATCH[1]}; i<=${BASH_REMATCH[2]}; i++)); do
      execute_step $i
    done
  else
    echo "Invalid step format: $2"
    exit 1
  fi
else
  for step in {1..9}; do
    execute_step $step
  done
fi