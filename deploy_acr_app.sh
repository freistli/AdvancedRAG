#!/bin/bash
set -e

if [ $# -eq 0 ]
then
echo "No SUF_FIX supplied, it should be an integer or a short string"
docker image list
exit 1
fi

SUF_FIX=$1
RESOURCE_GROUP="rg-demo-${SUF_FIX}"
LOCATION="eastus"
ENVIRONMENT="env-demo-containerapps"
API_NAME="advrag-demo-${SUF_FIX}"
FRONTEND_NAME="advrag-ui-${SUF_FIX}"
TARGET_PORT=8000
ACR_NAME="advragdemo${SUF_FIX}"

az group create --name $RESOURCE_GROUP --location "$LOCATION"

az acr create --resource-group $RESOURCE_GROUP --name $ACR_NAME --sku Basic --admin-enabled true

az acr build --registry $ACR_NAME --image $API_NAME .

az containerapp env create --name $ENVIRONMENT --resource-group $RESOURCE_GROUP --location "$LOCATION"

az containerapp create --name $API_NAME --resource-group $RESOURCE_GROUP --environment $ENVIRONMENT --image $ACR_NAME.azurecr.io/$API_NAME --target-port $TARGET_PORT --ingress external --registry-server $ACR_NAME.azurecr.io --query properties.configuration.ingress.fqdn

az containerapp ingress sticky-sessions set -n $API_NAME -g $RESOURCE_GROUP --affinity sticky
