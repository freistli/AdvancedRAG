#!/bin/bash
set -e

print_help() {
  echo ""
  echo "Usage: $0 SUF_FIX [STEP] [INDEX_NAME]"
  echo
  echo "Arguments:"
  echo "  SUF_FIX     A suffix to be used for naming resources. It should be an integer or a short string."
  echo "  STEP        (Optional) Specify which steps to execute:"
  echo "              - A single step number (e.g., 6) to execute only that step."
  echo "              - A range of steps (e.g., 3-7) to execute steps 3, 4, 5, 6, and 7."
  echo "  INDEX_NAME  (Optional) Index name used in the test API payload. Default: fieldcomm_0"
  echo
  echo "Examples:"
  echo "  $0 01"
  echo "  $0 demo01 6"
  echo "  $0 demo 2-8 my_index"
  echo
  echo "Steps:"
  echo "  1. Create Resource Group"
  echo "  2. Enable system managed identity for Container App"
  echo "  3. Create Key Vault resource"
  echo "  4. Generate random GUID and save it as Key Vault secret"
  echo "  5. Assign Container App system identity read permission on Key Vault secret"
  echo "  6. Update Container App environment variable Access_Code from Key Vault secret"
  echo "  7. Restart latest Container App revision"
  echo "  8. Send test HTTP request to validate new Access_Code"
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
LOCATION="eastus2"
API_NAME="advrag-${ORAG_NAME}-${SUF_FIX}"
INDEX_NAME=${3:-fieldcomm_0}
KEYVAULT_SECRET_NAME="access-code"
CONTAINERAPP_SECRET_NAME="access-code-kv"
ENV_VAR_NAME="Access_Code"
CONTENT_TYPE="application/json"

build_keyvault_name() {
  local raw="kv-${ORAG_NAME}-${SUF_FIX}"
  local cleaned

  cleaned=$(echo "$raw" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]//g')
  cleaned=$(echo "$cleaned" | sed -E 's/-+/-/g; s/^-+//; s/-+$//')

  if ! [[ "$cleaned" =~ ^[a-z] ]]; then
    cleaned="k${cleaned}"
  fi

  cleaned=${cleaned:0:24}
  cleaned=$(echo "$cleaned" | sed -E 's/-+$//')

  while [ ${#cleaned} -lt 3 ]; do
    cleaned="${cleaned}x"
  done

  echo "$cleaned"
}

KEYVAULT_NAME=$(build_keyvault_name)

ensure_resource_group() {
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" >/dev/null
}

ensure_system_identity() {
  local current_type

  current_type=$(az containerapp identity show --name "$API_NAME" --resource-group "$RESOURCE_GROUP" --query "type" -o tsv | tr -d '\r')

  if [[ "$current_type" == *"SystemAssigned"* ]]; then
    echo "Container App $API_NAME already has system identity enabled."
  else
    echo "Enabling system managed identity on Container App $API_NAME"
    az containerapp identity assign --name "$API_NAME" --resource-group "$RESOURCE_GROUP" --system-assigned >/dev/null
  fi
}

create_keyvault_if_missing() {
  if az keyvault show --name "$KEYVAULT_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "Key Vault $KEYVAULT_NAME already exists."
    return
  fi

  az keyvault create \
    --name "$KEYVAULT_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --enable-rbac-authorization true >/dev/null
}

get_current_user_type() {
  az account show --query user.type -o tsv | tr -d '\r'
}

get_current_user_name() {
  az account show --query user.name -o tsv | tr -d '\r'
}

get_current_object_id() {
  local user_type
  local user_name
  local object_id

  user_type=$(get_current_user_type)
  user_name=$(get_current_user_name)

  if [ "$user_type" == "user" ]; then
    object_id=$(az ad signed-in-user show --query id -o tsv 2>/dev/null | tr -d '\r')
  else
    object_id=$(az ad sp show --id "$user_name" --query id -o tsv 2>/dev/null | tr -d '\r')
  fi

  echo "$object_id"
}

assign_deployer_kv_secret_write_permission() {
  local kv_scope
  local current_object_id
  local existing
  local rbac_enabled
  local user_type
  local user_name

  kv_scope=$(az keyvault show --name "$KEYVAULT_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv | tr -d '\r')
  rbac_enabled=$(az keyvault show --name "$KEYVAULT_NAME" --resource-group "$RESOURCE_GROUP" --query properties.enableRbacAuthorization -o tsv | tr -d '\r')
  current_object_id=$(get_current_object_id)
  user_type=$(get_current_user_type)
  user_name=$(get_current_user_name)

  if [ -z "$current_object_id" ]; then
    echo "Unable to resolve current principal object id."
    echo "Sign in with 'az login' and make sure Microsoft Graph lookup is permitted."
    exit 1
  fi

  if [ "$rbac_enabled" == "true" ]; then
    existing=$(az role assignment list \
      --assignee-object-id "$current_object_id" \
      --scope "$kv_scope" \
      --query "[?roleDefinitionName=='Key Vault Secrets Officer'] | length(@)" -o tsv | tr -d '\r')

    if [ "$existing" == "0" ]; then
      echo "Granting current principal temporary secret write access on Key Vault (RBAC)."
      if ! az role assignment create \
        --role "Key Vault Secrets Officer" \
        --assignee-object-id "$current_object_id" \
        --scope "$kv_scope" >/dev/null 2>&1; then
        echo "Failed to assign Key Vault role [Key Vault Secrets Officer] to current principal."
        echo "You likely need Owner or User Access Administrator on scope: $kv_scope"
        exit 1
      fi
    fi

    return
  fi

  echo "Ensuring access-policy secret write permission for current principal."
  if [ "$user_type" == "user" ]; then
    az keyvault set-policy \
      --name "$KEYVAULT_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --object-id "$current_object_id" \
      --secret-permissions get list set >/dev/null
  else
    az keyvault set-policy \
      --name "$KEYVAULT_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --spn "$user_name" \
      --secret-permissions get list set >/dev/null
  fi
}

generate_guid() {
  local guid

  if command -v uuidgen >/dev/null 2>&1; then
    guid=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '\r')
  else
    guid=$(cat /proc/sys/kernel/random/uuid | tr '[:upper:]' '[:lower:]' | tr -d '\r')
  fi

  echo "$guid"
}

set_access_code_secret() {
  local access_code="$1"

  az keyvault secret set \
    --vault-name "$KEYVAULT_NAME" \
    --name "$KEYVAULT_SECRET_NAME" \
    --value "$access_code" >/dev/null
}

set_access_code_secret_with_retry() {
  local access_code="$1"
  local max_attempts=12
  local attempt

  assign_deployer_kv_secret_write_permission

  for ((attempt=1; attempt<=max_attempts; attempt++)); do
    if set_access_code_secret "$access_code"; then
      return
    fi

    if [ "$attempt" -eq "$max_attempts" ]; then
      echo "Failed to set Key Vault secret after $max_attempts attempts."
      echo "If role assignments were just created, wait a few more minutes and retry step 4."
      exit 1
    fi

    echo "Secret write not ready yet (attempt $attempt/$max_attempts). Waiting for RBAC propagation..."
    sleep 10
  done
}

get_access_code_secret_id() {
  az keyvault secret show \
    --vault-name "$KEYVAULT_NAME" \
    --name "$KEYVAULT_SECRET_NAME" \
    --query id -o tsv | tr -d '\r'
}

get_access_code_secret_value() {
  az keyvault secret show \
    --vault-name "$KEYVAULT_NAME" \
    --name "$KEYVAULT_SECRET_NAME" \
    --query value -o tsv | tr -d '\r'
}

get_access_code_secret_value_with_retry() {
  local max_attempts=12
  local attempt
  local value

  assign_deployer_kv_secret_write_permission

  for ((attempt=1; attempt<=max_attempts; attempt++)); do
    value=$(get_access_code_secret_value 2>/dev/null || true)
    if [ -n "$value" ]; then
      echo "$value"
      return
    fi

    if [ "$attempt" -eq "$max_attempts" ]; then
      echo "Failed to read Key Vault secret value after $max_attempts attempts."
      exit 1
    fi

    echo "Secret read not ready yet (attempt $attempt/$max_attempts). Waiting for RBAC propagation..." >&2
    sleep 10
  done
}

get_containerapp_principal_id() {
  az containerapp identity show --name "$API_NAME" --resource-group "$RESOURCE_GROUP" --query principalId -o tsv | tr -d '\r'
}

assign_kv_secret_read_role() {
  local principal_id="$1"
  local keyvault_scope
  local existing

  keyvault_scope=$(az keyvault show --name "$KEYVAULT_NAME" --resource-group "$RESOURCE_GROUP" --query id -o tsv | tr -d '\r')

  existing=$(az role assignment list \
    --assignee-object-id "$principal_id" \
    --scope "$keyvault_scope" \
    --query "[?roleDefinitionName=='Key Vault Secrets User'] | length(@)" -o tsv | tr -d '\r')

  if [ "$existing" != "0" ]; then
    echo "Role [Key Vault Secrets User] already exists on scope: $keyvault_scope"
    return
  fi

  az role assignment create \
    --role "Key Vault Secrets User" \
    --assignee-object-id "$principal_id" \
    --assignee-principal-type ServicePrincipal \
    --scope "$keyvault_scope" >/dev/null
}

update_containerapp_access_code_from_kv() {
  local secret_id="$1"

  az containerapp secret set \
    --name "$API_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --secrets "${CONTAINERAPP_SECRET_NAME}=keyvaultref:${secret_id},identityref:system" >/dev/null

  az containerapp update \
    --name "$API_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --set-env-vars "${ENV_VAR_NAME}=secretref:${CONTAINERAPP_SECRET_NAME}" >/dev/null
}

restart_latest_revision() {
  local latest_revision

  latest_revision=$(az containerapp revision list \
    --name "$API_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query "sort_by([].{name:name,createdTime:properties.createdTime}, &createdTime)[-1].name" -o tsv | tr -d '\r')

  if [ -z "$latest_revision" ]; then
    echo "No revision found for Container App $API_NAME"
    exit 1
  fi

  az containerapp revision restart --name "$API_NAME" --resource-group "$RESOURCE_GROUP" --revision "$latest_revision" >/dev/null
}

send_test_http_request() {
  local access_code="$1"
  local fqdn
  local url
  local request_body
  local response_file
  local http_status

  fqdn=$(az containerapp show --name "$API_NAME" --resource-group "$RESOURCE_GROUP" --query properties.configuration.ingress.fqdn -o tsv | tr -d '\r')

  if [ -z "$fqdn" ]; then
    echo "Container App ingress FQDN not found for $API_NAME"
    exit 1
  fi

  url="https://${fqdn}/api/fieldcommdataframe?code=${access_code}"

  request_body=$(cat <<EOF
{
  "action": "Chat",
  "indexName": "${INDEX_NAME}",
  "message": "Summarize the devices in this fieldcomm dataset.",
  "streaming": false
}
EOF
)

  response_file=$(mktemp)

  http_status=$(curl -sS -o "$response_file" -w "%{http_code}" \
    -X POST "$url" \
    -H "Content-Type: ${CONTENT_TYPE}" \
    --data "$request_body")

  echo "Test endpoint: $url"
  echo "HTTP status: $http_status"

  if [ "$http_status" == "401" ] || [ "$http_status" == "403" ]; then
    echo "Access code validation failed (unauthorized)."
    echo "Response body:"
    cat "$response_file"
    rm -f "$response_file"
    exit 1
  fi

  echo "Access code validation passed (not unauthorized)."
  echo "Response body preview:"
  head -c 600 "$response_file"
  echo ""

  rm -f "$response_file"
}

execute_step() {
  local principal_id
  local access_code
  local secret_id

  case $1 in
    1)
      echo "1. Creating resource group $RESOURCE_GROUP in $LOCATION"
      ensure_resource_group
      ;;
    2)
      echo "2. Enabling system managed identity on Container App $API_NAME"
      ensure_system_identity
      ;;
    3)
      echo "3. Creating Key Vault $KEYVAULT_NAME in $RESOURCE_GROUP"
      create_keyvault_if_missing
      ;;
    4)
      echo "4. Generating random GUID and saving into Key Vault secret $KEYVAULT_SECRET_NAME"
      access_code=$(generate_guid)
      set_access_code_secret_with_retry "$access_code"
      echo "Generated Access_Code GUID: $access_code"
      ;;
    5)
      echo "5. Assigning Key Vault secret read permission to Container App system identity"
      ensure_system_identity
      principal_id=$(get_containerapp_principal_id)
      assign_kv_secret_read_role "$principal_id"
      ;;
    6)
      echo "6. Updating Container App environment variable $ENV_VAR_NAME from Key Vault secret"
      secret_id=$(get_access_code_secret_id)
      update_containerapp_access_code_from_kv "$secret_id"
      ;;
    7)
      echo "7. Restarting latest revision for Container App $API_NAME"
      restart_latest_revision
      ;;
    8)
      echo "8. Sending test HTTP request to validate new Access_Code"
      access_code=$(get_access_code_secret_value_with_retry)
      send_test_http_request "$access_code"
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
  for step in {1..8}; do
    execute_step "$step"
  done
fi
