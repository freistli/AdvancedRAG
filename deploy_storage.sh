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

#Non-Capitalized variables are used to avoid conflicts with environment variables
ORAG_NAME="demo"
SUF_FIX=$1
RESOURCE_GROUP="rg-${ORAG_NAME}-${SUF_FIX}"
LOCATION="eastus"
AOAI_NAME="aoai-${ORAG_NAME}-${SUF_FIX}"
DOC_AI_NAME="docai-${ORAG_NAME}-${SUF_FIX}"
LLM_MODEL="gpt-4o-mini"
LLM_MODEL_VERSION="2024-07-18"
EMBEDDING_MODEL="text-embedding-3-small"
USER_ASSIGNED_IDENTITY_NAME="user-${ORAG_NAME}-${SUF_FIX}"
STORAGE_ACCOUNT_NAME="st${ORAG_NAME}${SUF_FIX}"
SHARE_NAME="share${ORAG_NAME}${SUF_FIX}"
API_NAME="advrag-${ORAG_NAME}-${SUF_FIX}"
FILE_DIRECTORY_NAME="files"
INDEX_DIRECTORY_NAME="indexes"

execute_step() {
  case $1 in
    1)
      echo "1. Creating resource group $RESOURCE_GROUP in $LOCATION" 
      az group create --name $RESOURCE_GROUP --location "$LOCATION"
      ;;
    2)
        echo "2. Creating Azure Storage Account $STORAGE_ACCOUNT_NAME in $LOCATION" 
        az storage account create --resource-group $RESOURCE_GROUP --name $STORAGE_ACCOUNT_NAME --location $LOCATION --kind StorageV2 --sku Standard_LRS --enable-large-file-share 
        ;;
    3)      
        echo "3. Creating Azure Storage Share $SHARE_NAME in $STORAGE_ACCOUNT_NAME" 
        az storage share-rm create --resource-group $RESOURCE_GROUP --storage-account $STORAGE_ACCOUNT_NAME --name $SHARE_NAME --quota 1024 --enabled-protocols SMB 
        ;; 

    4)
        echo "4. Creating Azure Storage Directory $FILE_DIRECTORY_NAME in $SHARE_NAME" 
        az storage directory create --account-name $STORAGE_ACCOUNT_NAME --share-name $SHARE_NAME --name $FILE_DIRECTORY_NAME
        ;;
    5)
        echo "5. Creating Azure Storage Directory $INDEX_DIRECTORY_NAME in $SHARE_NAME" 
        az storage directory create --account-name $STORAGE_ACCOUNT_NAME --share-name $SHARE_NAME --name $INDEX_DIRECTORY_NAME
        ;;
    6)
        echo "6. Create User Assigned Identity $USER_ASSIGNED_IDENTITY_NAME" 
        az identity create -g $RESOURCE_GROUP -n $USER_ASSIGNED_IDENTITY_NAME
        ;; 
    7)
        echo "7. Assigning User Assigned Identity $USER_ASSIGNED_IDENTITY_NAME to Container App $API_NAME" 
        az containerapp identity assign --name $API_NAME --resource-group $RESOURCE_GROUP --user-assigned $(az identity show -g $RESOURCE_GROUP -n $USER_ASSIGNED_IDENTITY_NAME --query id -o tsv)
        ;;
    8)
        echo "8. Assigning User Assigned Identity $USER_ASSIGNED_IDENTITY_NAME to Storage Account $STORAGE_ACCOUNT_NAME as Role [Storage Blob Data Contributor]" 
        az role assignment create --role "Storage Blob Data Contributor" --assignee-object-id $(az identity show -g $RESOURCE_GROUP -n $USER_ASSIGNED_IDENTITY_NAME --query principalId -o tsv) --scope $(az storage account show -n $STORAGE_ACCOUNT_NAME -g $RESOURCE_GROUP --query id -o tsv)
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
  for step in {1..8}; do
    execute_step $step
  done
fi