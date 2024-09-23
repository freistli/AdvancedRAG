#!/bin/bash
set -e


print_help() {
  echo ""
  echo "Usage: $0 SUF_FIX [STEP]"
  echo
  echo "Arguments:"
  echo "  SUF_FIX    A suffix to be used for naming resources. It should be an integer or a short string."
  echo "  STEP       (Optional) Specify which steps to execute:"
  echo "             - A single step number (e.g., 5) to execute only that step."
  echo "             - A range of steps (e.g., 2-5) to execute steps 2, 3, 4, and 5."
  echo
  echo "Examples:"
  echo "  $0 01"
  echo "  $0 demo01 3"
  echo "  $0 demo 2-4"

  echo "Steps:"
    echo "  1. Create Resource Group"
    echo "  2. Create Azure Container Registry"
    echo "  3. Build and Push Docker Image to Azure Container Registry"
    echo "  4. Create Azure Container App Environment"
    echo "  5. Create Azure Container App"
    echo "  6. Set Session Affinity for App Frontend"
    echo "  7. Create User Assigned Identity"
    echo "  8. Assign User Assigned Identity to Container App"
    echo "  9. Redeploy Azure Container App"
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
LOCATION="eastus"
ENVIRONMENT="env-${ORAG_NAME}-containerapps"
API_NAME="advrag-${ORAG_NAME}-${SUF_FIX}"
FRONTEND_NAME="advrag-ui-${SUF_FIX}"
TARGET_PORT=8000
ACR_NAME="advrag${ORAG_NAME}${SUF_FIX}"
USER_ASSIGNED_IDENTITY_NAME="user-${ORAG_NAME}-${SUF_FIX}"

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
        echo "3. Building and pushing Docker image $API_NAME to Azure Container Registry $ACR_NAME" 
        az acr build --registry $ACR_NAME --image $API_NAME .
        ;;
    4)
        echo "4. Creating Azure Container App Environment $ENVIRONMENT in $LOCATION" 
        az containerapp env create --name $ENVIRONMENT --resource-group $RESOURCE_GROUP --location "$LOCATION"
        ;;
    5)
        echo "5. Creating Azure Container App $API_NAME in $ENVIRONMENT" 
        az containerapp create --name $API_NAME --resource-group $RESOURCE_GROUP --environment $ENVIRONMENT --image $ACR_NAME.azurecr.io/$API_NAME --target-port $TARGET_PORT --ingress external --registry-server $ACR_NAME.azurecr.io --query properties.configuration.ingress.fqdn
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
        az containerapp identity assign --name $API_NAME --resource-group $RESOURCE_GROUP --user-assigned $(az identity show -g $RESOURCE_GROUP -n $USER_ASSIGNED_IDENTITY_NAME --query id -o tsv)
        ;;
    9)
        echo "9. Redeploy Azure Container App $API_NAME in $ENVIRONMENT"
        az containerapp up --name $API_NAME --image $ACR_NAME.azurecr.io/$API_NAME  --ingress external --target-port $TARGET_PORT --resource-group $RESOURCE_GROUP
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