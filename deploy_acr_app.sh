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

ORAG_NAME="demo"
SUF_FIX=$1
RESOURCE_GROUP="rg-${ORAG_NAME}-${SUF_FIX}"
LOCATION="eastus"
ENVIRONMENT="env-${ORAG_NAME}-containerapps"
API_NAME="advrag-${ORAG_NAME}-${SUF_FIX}"
FRONTEND_NAME="advrag-ui-${SUF_FIX}"
TARGET_PORT=8000
ACR_NAME="advrag${ORAG_NAME}${SUF_FIX}"


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
  for step in {1..6}; do
    execute_step $step
  done
fi