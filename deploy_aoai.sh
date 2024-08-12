#!/bin/bash
set -e

if [ $# -eq 0 ]
then
echo "No SUF_FIX supplied, it should be an integer or a short string"
exit 1
fi

SUF_FIX=$1
RESOURCE_GROUP="rg-demo-${SUF_FIX}"
LOCATION="eastus"
AOAI_NAME="aoai-demo-${SUF_FIX}"
DOC_AI_NAME="docai-demo-${SUF_FIX}"
LLM_MODEL="gpt-4o-mini"
LLM_MODEL_VERSION="2024-07-18"
EMBEDDING_MODEL="text-embedding-3-small"

az group create --name $RESOURCE_GROUP --location "$LOCATION"

az cognitiveservices account create --name $AOAI_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --kind OpenAI --sku s0

az cognitiveservices account deployment create --name $AOAI_NAME  --resource-group  $RESOURCE_GROUP --deployment-name $LLM_MODEL --model-name $LLM_MODEL --model-version "1" --model-format OpenAI --sku-capacity "1" --sku-name "Standard"

az cognitiveservices account deployment create --name $AOAI_NAME  --resource-group  $RESOURCE_GROUP --deployment-name $EMBEDDING_MODEL --model-name $EMBEDDING_MODEL --model-version "1" --model-format OpenAI --sku-capacity "1" --sku-name "Standard"

az cognitiveservices account create --name $DOC_AI_NAME --resource-group $RESOURCE_GROUP --kind FormRecognizer --sku s0 --location $LOCATION --yes