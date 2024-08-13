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
AOAI_NAME="aoai-${ORAG_NAME}-${SUF_FIX}"
DOC_AI_NAME="docai-${ORAG_NAME}-${SUF_FIX}"
LLM_MODEL="gpt-4o-mini"
LLM_MODEL_VERSION="2024-07-18"
EMBEDDING_MODEL="text-embedding-3-small"

execute_step() {
  case $1 in
    1)
      echo "1. Creating resource group $RESOURCE_GROUP in $LOCATION" 
      az group create --name $RESOURCE_GROUP --location "$LOCATION"
      ;;
    2)
      echo "2. Creating Azure OpenAI Cognitive Services Account $AOAI_NAME in $LOCATION" 
      az cognitiveservices account create --name $AOAI_NAME --resource-group $RESOURCE_GROUP --location $LOCATION --kind OpenAI --sku s0
      ;;
    3)
      echo "3. Creating Azure Cognitive Services Account Deployment for LLM Model $LLM_MODEL in $AOAI_NAME" 
      az cognitiveservices account deployment create --name $AOAI_NAME  --resource-group  $RESOURCE_GROUP --deployment-name $LLM_MODEL --model-name $LLM_MODEL --model-version $LLM_MODEL_VERSION --model-format OpenAI --sku-capacity "1" --sku-name "Standard"
      ;;
    4)
      echo "4. Creating Azure Cognitive Services Account Deployment for Embedding Model $EMBEDDING_MODEL in $AOAI_NAME" 
      az cognitiveservices account deployment create --name $AOAI_NAME  --resource-group  $RESOURCE_GROUP --deployment-name $EMBEDDING_MODEL --model-name $EMBEDDING_MODEL --model-version "1" --model-format OpenAI --sku-capacity "1" --sku-name "Standard"
      ;;
    5)
      echo "5. Creating Azure Form Recognizer Cognitive Services Account $DOC_AI_NAME in $LOCATION" 
      az cognitiveservices account create --name $DOC_AI_NAME --resource-group $RESOURCE_GROUP --kind FormRecognizer --sku s0 --location $LOCATION --yes
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
  for step in {1..5}; do
    execute_step $step
  done
fi