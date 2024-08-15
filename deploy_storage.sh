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
    echo "  2. Create Storage Account"
    echo "  3. Create Storage Share"
    echo "  4. Create Storage Directory for Files"
    echo "  5. Create Storage Directory for Indexes"
    echo "  6. Create User Assigned Identity"
    echo "  7. Assign User Assigned Identity to Container App"
    echo "  8. Assign User Assigned Identity to Storage Account"
    echo "  9. Set up Azure File Storage Link for Environment"
    echo "  10. List Azure File Storage Link for Environment"
    echo "  11. Show container app config yaml"
    echo "  12. Press Enter after yaml file modified"
    echo "  13. Update container app config"
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
INDEX_DIRECTORY_NAME="index_cache"
ENVIRONMENT="env-${ORAG_NAME}-containerapps"

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
        az role assignment create --role "Storage Blob Data Contributor" --assignee-object-id $(az identity show -g $RESOURCE_GROUP -n $USER_ASSIGNED_IDENTITY_NAME --query principalId -o tsv) --scope $(az storage account show -n $STORAGE_ACCOUNT_NAME -g $RESOURCE_GROUP --query id -o tsv )
        ;;  \
    9)
        echo "9. Setting up Azure File Storage Link for Environment $ENVIRONMENT"
        ## Get storage account key
        STORAGE_ACCOUNT_KEY=$(az storage account keys list -n $STORAGE_ACCOUNT_NAME --query "[0].value" -o tsv)
                
        ##Create the storage link in the environment.
        STORAGE_MOUNT_NAME="azurefile-$STORAGE_ACCOUNT_NAME-$SHARE_NAME"
        az containerapp env storage set --name $ENVIRONMENT --access-mode ReadWrite --azure-file-account-name $STORAGE_ACCOUNT_NAME --azure-file-account-key $STORAGE_ACCOUNT_KEY --azure-file-share-name $SHARE_NAME --storage-name $STORAGE_MOUNT_NAME --resource-group $RESOURCE_GROUP        
        ;;
    10)
        echo "10. List Azure File Storage Link for Environment in Resource Group $RESOURCE_GROUP"
        RESULT_STEP10=$(az containerapp env storage list --name $ENVIRONMENT --resource-group $RESOURCE_GROUP --query "[0].name" -o tsv)
        echo "azure file mounted: $RESULT_STEP10"
        ;;
    11)
        echo "11. Show container app config yaml"
        az containerapp show --name $API_NAME --resource-group $RESOURCE_GROUP -o yaml > $API_NAME.yaml
        echo "Container App Config saved to $API_NAME.yaml, follow the guide https://learn.microsoft.com/en-us/azure/container-apps/storage-mounts-azure-files?tabs=bash#create-the-storage-mount to modify yaml"
        ;;
    12) echo "12. Press Enter after yaml file modified"
        read -p "Press Enter to continue"
        ;;
    13)
        echo "13. Update container app config"
        az containerapp update --resource-group $RESOURCE_GROUP --name $API_NAME --yaml $API_NAME.yaml -o table
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
  for step in {1..13}; do
    execute_step $step
  done
fi