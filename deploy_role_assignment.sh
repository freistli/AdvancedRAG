#!/bin/bash
set -e

print_help() {
  echo ""
  echo "Usage: $0 SUF_FIX [STEP] [ENV_FILE]"
  echo
  echo "Arguments:"
  echo "  SUF_FIX    A suffix to be used for naming resources. It should be an integer or a short string."
  echo "  STEP       (Optional) Specify which steps to execute:"
  echo "             - A single step number (e.g., 2) to execute only that step."
  echo "             - A range of steps (e.g., 1-3) to execute steps 1, 2, and 3."
  echo "  ENV_FILE   (Optional) Env file path. Default: .env.uat"
  echo
  echo "Examples:"
  echo "  $0 01"
  echo "  $0 demo01 2"
  echo "  $0 demo 2-4 .env.uat"
  echo
  echo "Steps:"
  echo "  1. Enable system identity for Container App if not enabled"
  echo "  2. Assign system identity to Azure OpenAI resource"
  echo "  3. Assign system identity to Azure Storage account"
  echo "  4. Assign system identity to Azure AI Search service"
  echo "  5. Restart latest Container App revision"
}

if [ "$1" == "-h" ] || [ "$1" == "--help" ]; then
  print_help
  exit 0
fi

if [ $# -eq 0 ]; then
  echo "No SUF_FIX supplied, it should be an integer or a short string"
  print_help
  exit 1
fi

ORAG_NAME="mwai"
SUF_FIX=$1
RESOURCE_GROUP="rg-${ORAG_NAME}-${SUF_FIX}"
API_NAME="advrag-${ORAG_NAME}-${SUF_FIX}"
ENV_FILE=${3:-.env.uat}

if [ ! -f "$ENV_FILE" ]; then
  echo "Env file not found: $ENV_FILE"
  exit 1
fi

read_env_value() {
  local key="$1"
  local line

  line=$(grep -E "^[[:space:]]*${key}[[:space:]]*=" "$ENV_FILE" | tail -n 1 || true)
  if [ -z "$line" ]; then
    echo ""
    return
  fi

  # Keep everything after first '=' and remove surrounding spaces and quotes.
  line=${line#*=}
  line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//; s/"$//' -e "s/^'//; s/'$//")
  echo "$line"
}

endpoint_to_name() {
  local endpoint="$1"
  local host

  host=$(echo "$endpoint" | sed -E 's#^[a-zA-Z]+://##; s#/.*$##')
  echo "$host" | cut -d'.' -f1
}

resource_id_by_type_and_name() {
  local resource_type="$1"
  local resource_name="$2"

  az resource list --resource-type "$resource_type" --name "$resource_name" --query "[0].id" -o tsv | tr -d '\r'
}

resolve_aoai_scope_from_endpoint() {
  local aoai_endpoint="$1"
  local endpoint_no_trailing_slash
  local host_label
  local scope

  endpoint_no_trailing_slash=${aoai_endpoint%/}

  # Primary path: resolve directly by endpoint to avoid host/account-name mismatch.
  scope=$(az cognitiveservices account list --query "[?contains(properties.endpoint, '${endpoint_no_trailing_slash}')].id | [0]" -o tsv | tr -d '\r')
  if [ -n "$scope" ]; then
    echo "$scope"
    return
  fi

  # Fallback path: resolve from host label, then progressively trim trailing '-segment'.
  host_label=$(endpoint_to_name "$aoai_endpoint")
  scope=$(resource_id_by_type_and_name "Microsoft.CognitiveServices/accounts" "$host_label")
  if [ -n "$scope" ]; then
    echo "$scope"
    return
  fi

  while [[ "$host_label" == *"-"* ]]; do
    host_label=${host_label%-*}
    scope=$(resource_id_by_type_and_name "Microsoft.CognitiveServices/accounts" "$host_label")
    if [ -n "$scope" ]; then
      echo "$scope"
      return
    fi
  done

  echo ""
}

ensure_system_identity() {
  local current_type

  current_type=$(az containerapp identity show --name "$API_NAME" --resource-group "$RESOURCE_GROUP" --query "type" -o tsv | tr -d '\r')

  if [[ "$current_type" == *"SystemAssigned"* ]]; then
    echo "Container App $API_NAME already has system identity enabled."
  else
    echo "Enabling system identity for Container App $API_NAME"
    az containerapp identity assign --name "$API_NAME" --resource-group "$RESOURCE_GROUP" --system-assigned
  fi
}

get_principal_id() {
  az containerapp identity show --name "$API_NAME" --resource-group "$RESOURCE_GROUP" --query "principalId" -o tsv | tr -d '\r'
}

assign_role() {
  local role_name="$1"
  local scope_id="$2"
  local principal_id="$3"

  local existing
  existing=$(az role assignment list --assignee-object-id "$principal_id" --scope "$scope_id" --query "[?roleDefinitionName=='${role_name}'] | length(@)" -o tsv | tr -d '\r')

  if [ "$existing" != "0" ]; then
    echo "Role [$role_name] already exists on scope: $scope_id"
    return
  fi

  az role assignment create --role "$role_name" --assignee-object-id "$principal_id" --assignee-principal-type ServicePrincipal --scope "$scope_id"
}

execute_step() {
  local principal_id
  local latest_revision

  case $1 in
    1)
      echo "1. Enable system identity for Container App $API_NAME if missing"
      ensure_system_identity
      ;;
    2)
      echo "2. Assign system identity to Azure OpenAI from $ENV_FILE"
      ensure_system_identity
      principal_id=$(get_principal_id)

      local aoai_endpoint aoai_scope
      aoai_endpoint=$(read_env_value "AZURE_OPENAI_ENDPOINT")
      aoai_scope=$(resolve_aoai_scope_from_endpoint "$aoai_endpoint")

      if [ -z "$aoai_scope" ]; then
        echo "Azure OpenAI resource not found from endpoint: $aoai_endpoint"
        exit 1
      fi

      assign_role "Cognitive Services OpenAI User" "$aoai_scope" "$principal_id"
      ;;
    3)
      echo "3. Assign system identity to Azure Storage account from $ENV_FILE"
      ensure_system_identity
      principal_id=$(get_principal_id)

      local blob_endpoint storage_name storage_scope
      blob_endpoint=$(read_env_value "AZURE_BLOB_ACCOUNT_NAME")
      storage_name=$(endpoint_to_name "$blob_endpoint")
      storage_scope=$(resource_id_by_type_and_name "Microsoft.Storage/storageAccounts" "$storage_name")

      if [ -z "$storage_scope" ]; then
        echo "Storage account resource not found from endpoint: $blob_endpoint"
        exit 1
      fi

      assign_role "Storage Blob Data Contributor" "$storage_scope" "$principal_id"
      ;;
    4)
      echo "4. Assign system identity to Azure AI Search service from $ENV_FILE"
      ensure_system_identity
      principal_id=$(get_principal_id)

      local search_endpoint search_name search_scope
      search_endpoint=$(read_env_value "AZURE_SEARCH_ENDPOINT")
      search_name=$(endpoint_to_name "$search_endpoint")
      search_scope=$(resource_id_by_type_and_name "Microsoft.Search/searchServices" "$search_name")

      if [ -z "$search_scope" ]; then
        echo "Azure AI Search resource not found from endpoint: $search_endpoint"
        exit 1
      fi

      assign_role "Search Index Data Contributor" "$search_scope" "$principal_id"
      assign_role "Search Service Contributor" "$search_scope" "$principal_id"
      ;;
    5)
      echo "5. Restart latest revision for Container App $API_NAME"
      latest_revision=$(az containerapp revision list --name "$API_NAME" --resource-group "$RESOURCE_GROUP" --query "sort_by([].{name:name,createdTime:properties.createdTime}, &createdTime)[-1].name" -o tsv | tr -d '\r')

      if [ -z "$latest_revision" ]; then
        echo "No revision found for Container App $API_NAME"
        exit 1
      fi

      az containerapp revision restart --name "$API_NAME" --resource-group "$RESOURCE_GROUP" --revision "$latest_revision"
      ;;
    *)
      echo "Invalid step: $1"
      ;;
  esac
}

if [ $# -ge 2 ]; then
  if [[ "$2" =~ ^[0-9]+$ ]]; then
    execute_step "$2"
  elif [[ "$2" =~ ^([0-9]+)-([0-9]+)$ ]]; then
    for ((i=${BASH_REMATCH[1]}; i<=${BASH_REMATCH[2]}; i++)); do
      execute_step "$i"
    done
  else
    echo "Invalid step format: $2"
    exit 1
  fi
else
  for step in {1..5}; do
    execute_step "$step"
  done
fi
