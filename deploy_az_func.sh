#!/bin/bash
set -e

# Reduce noisy Python warnings emitted by Azure CLI's embedded Python runtime.
export PYTHONWARNINGS="ignore::UserWarning"

print_help() {
  echo ""
  echo "Usage: $0 SUF_FIX [STEP] [ENV_FILE]"
  echo
  echo "Arguments:"
  echo "  SUF_FIX    A suffix to be used for naming resources. It should be an integer or a short string."
  echo "  STEP       (Optional) Specify which steps to execute:"
  echo "             - A single step number (e.g., 4) to execute only that step."
  echo "             - A range of steps (e.g., 2-5) to execute steps 2, 3, 4, and 5."
  echo "  ENV_FILE   (Optional) Env file path. Default: .env"
  echo
  echo "Examples:"
  echo "  $0 01"
  echo "  $0 demo01 3"
  echo "  $0 demo 2-6 .env.prod"
  echo "  APP_SERVICE_PLAN_FALLBACK_LOCATIONS=eastus,centralus $0 demo 2"
  echo
  echo "Notes:"
  echo "  - If App Service Plan creation fails due to regional quota, fallback locations are tried."
  echo "  - Fallback list can be set via APP_SERVICE_PLAN_FALLBACK_LOCATIONS (comma-separated)."
  echo "  - Storage account can be in another resource group; it is resolved by name across the subscription."
  echo "  - Optional override: STORAGE_ACCOUNT_RESOURCE_GROUP=<rg-name>"
  echo "  - Function creation uses a dedicated VNet/subnet by default for restricted storage accounts."
  echo "  - Optional overrides: FUNCTION_VNET_NAME, FUNCTION_VNET_RESOURCE_GROUP"
  echo "  - Optional VNet config: FUNCTION_VNET_ADDRESS_PREFIX (default: 10.10.0.0/16), FUNCTION_VNET_AUTO_CREATE (default: true)"
  echo "  - Optional subnet config: FUNCTION_SUBNET_NAME (default: snet-azfun), FUNCTION_SUBNET_PREFIX (default: 10.10.1.0/27), FUNCTION_SUBNET_AUTO_CREATE (default: true)"
  echo
  echo "Steps:"
  echo "  1. Create Resource Group"
  echo "  2. Create Windows App Service Plan (S1)"
  echo "  3. Create Windows Azure Function App"
  echo "  4. Enable System Assigned Identity"
  echo "  5. Assign Storage data-plane roles to the Function identity"
  echo "  6. Set Function App settings and minimum TLS version"
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
# Optional env override for extra fallback regions (comma-separated)
APP_SERVICE_PLAN_FALLBACK_LOCATIONS=${APP_SERVICE_PLAN_FALLBACK_LOCATIONS:-}
DEFAULT_APP_SERVICE_PLAN_FALLBACK_LOCATIONS="eastus,centralus,westus2"
APP_SERVICE_PLAN_NAME="plan-${ORAG_NAME}-${SUF_FIX}"
FUNCTION_APP_NAME="advrag-func-${ORAG_NAME}-${SUF_FIX}"
APP_SERVICE_PLAN_SKU="S1"
FUNCTIONS_EXTENSION_VERSION="~4"
FUNCTIONS_VERSION="4"
FUNCTIONS_WORKER_RUNTIME="dotnet-isolated"
DOTNET_RUNTIME_VERSION="8"
MIN_TLS_VERSION="1.2"
ENV_FILE=${3:-.env}
PLAN_LOCATION=""
STORAGE_ACCOUNT_RESOURCE_GROUP=${STORAGE_ACCOUNT_RESOURCE_GROUP:-}
FUNCTION_VNET_NAME=${FUNCTION_VNET_NAME:-vnet-azfunc-${ORAG_NAME}-${SUF_FIX}}
FUNCTION_VNET_RESOURCE_GROUP=${FUNCTION_VNET_RESOURCE_GROUP:-$RESOURCE_GROUP}
FUNCTION_VNET_ADDRESS_PREFIX=${FUNCTION_VNET_ADDRESS_PREFIX:-10.10.0.0/16}
FUNCTION_VNET_AUTO_CREATE=${FUNCTION_VNET_AUTO_CREATE:-true}
FUNCTION_SUBNET_NAME=${FUNCTION_SUBNET_NAME:-snet-azfun}
FUNCTION_SUBNET_PREFIX=${FUNCTION_SUBNET_PREFIX:-10.10.1.0/27}
FUNCTION_SUBNET_AUTO_CREATE=${FUNCTION_SUBNET_AUTO_CREATE:-true}

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

  line=${line#*=}
  line=$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//; s/"$//' -e "s/^'//; s/'$//")
  echo "$line"
}

normalize_storage_account_name() {
  local raw_value="$1"
  local account_name

  account_name=$(echo "$raw_value" | sed -E 's#^[a-zA-Z]+://##; s#/.*$##' | cut -d'.' -f1)
  echo "$account_name"
}

get_storage_account_id() {
  local storage_account_name="$1"
  local storage_account_id

  if [ -n "$STORAGE_ACCOUNT_RESOURCE_GROUP" ]; then
    storage_account_id=$(az storage account show \
      --name "$storage_account_name" \
      --resource-group "$STORAGE_ACCOUNT_RESOURCE_GROUP" \
      --query "id" -o tsv | tr -d '\r' || true)
  else
    storage_account_id=$(az storage account list \
      --query "[?name=='${storage_account_name}'].id | [0]" -o tsv | tr -d '\r' || true)
  fi

  echo "$storage_account_id"
}

get_function_vnet_id() {
  az network vnet show \
    --resource-group "$FUNCTION_VNET_RESOURCE_GROUP" \
    --name "$FUNCTION_VNET_NAME" \
    --query "id" -o tsv | tr -d '\r'
}

ensure_function_vnet() {
  local vnet_id
  local vnet_location="$1"

  vnet_id=$(az network vnet show \
    --resource-group "$FUNCTION_VNET_RESOURCE_GROUP" \
    --name "$FUNCTION_VNET_NAME" \
    --query "id" -o tsv | tr -d '\r' || true)

  if [ -n "$vnet_id" ]; then
    echo "$vnet_id"
    return
  fi

  if [[ "${FUNCTION_VNET_AUTO_CREATE,,}" != "true" ]]; then
    echo ""
    return
  fi

  echo "VNet $FUNCTION_VNET_NAME not found. Creating in $vnet_location with address space $FUNCTION_VNET_ADDRESS_PREFIX" >&2
  az network vnet create \
    --resource-group "$FUNCTION_VNET_RESOURCE_GROUP" \
    --name "$FUNCTION_VNET_NAME" \
    --location "$vnet_location" \
    --address-prefixes "$FUNCTION_VNET_ADDRESS_PREFIX" >/dev/null

  get_function_vnet_id
}

ensure_function_subnet_id() {
  local subnet_id

  subnet_id=$(az network vnet subnet show \
    --resource-group "$FUNCTION_VNET_RESOURCE_GROUP" \
    --vnet-name "$FUNCTION_VNET_NAME" \
    --name "$FUNCTION_SUBNET_NAME" \
    --query "id" -o tsv | tr -d '\r' || true)

  if [ -z "$subnet_id" ]; then
    if [[ "${FUNCTION_SUBNET_AUTO_CREATE,,}" != "true" ]]; then
      echo ""
      return
    fi

    echo "Subnet $FUNCTION_SUBNET_NAME not found. Creating with prefix $FUNCTION_SUBNET_PREFIX" >&2
    az network vnet subnet create \
      --resource-group "$FUNCTION_VNET_RESOURCE_GROUP" \
      --vnet-name "$FUNCTION_VNET_NAME" \
      --name "$FUNCTION_SUBNET_NAME" \
      --address-prefixes "$FUNCTION_SUBNET_PREFIX" \
      --delegations Microsoft.Web/serverFarms >/dev/null

    subnet_id=$(az network vnet subnet show \
      --resource-group "$FUNCTION_VNET_RESOURCE_GROUP" \
      --vnet-name "$FUNCTION_VNET_NAME" \
      --name "$FUNCTION_SUBNET_NAME" \
      --query "id" -o tsv | tr -d '\r')
  else
    # Ensure the subnet has required delegation for App Service/Function VNet integration.
    az network vnet subnet update \
      --resource-group "$FUNCTION_VNET_RESOURCE_GROUP" \
      --vnet-name "$FUNCTION_VNET_NAME" \
      --name "$FUNCTION_SUBNET_NAME" \
      --delegations Microsoft.Web/serverFarms >/dev/null
  fi

  echo "$subnet_id"
}

resource_id_by_type_and_name() {
  local resource_type="$1"
  local resource_name="$2"

  az resource list --resource-type "$resource_type" --name "$resource_name" --query "[0].id" -o tsv | tr -d '\r'
}

require_non_empty() {
  local label="$1"
  local value="$2"

  if [ -z "$value" ]; then
    echo "Missing required value: $label"
    exit 1
  fi
}

ensure_resource_group() {
  az group create --name "$RESOURCE_GROUP" --location "$LOCATION" >/dev/null
}

get_plan_location() {
  az appservice plan show --name "$APP_SERVICE_PLAN_NAME" --resource-group "$RESOURCE_GROUP" --query "location" -o tsv | tr -d '\r'
}

plan_location_candidates() {
  local all_locations

  all_locations="$LOCATION,$APP_SERVICE_PLAN_FALLBACK_LOCATIONS,$DEFAULT_APP_SERVICE_PLAN_FALLBACK_LOCATIONS"
  echo "$all_locations" | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | awk 'NF && !seen[$0]++'
}

plan_location_candidates_csv() {
  plan_location_candidates | paste -sd ',' -
}

create_plan_if_missing() {
  local -a candidates
  local candidate_location
  local candidates_csv
  local error_file

  if az appservice plan show --name "$APP_SERVICE_PLAN_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    PLAN_LOCATION=$(get_plan_location)
    echo "App Service Plan $APP_SERVICE_PLAN_NAME already exists."
    echo "Using existing App Service Plan location: $PLAN_LOCATION"
    return
  fi

  error_file=$(mktemp)
  mapfile -t candidates < <(plan_location_candidates)
  candidates_csv=$(plan_location_candidates_csv)
  echo "App Service Plan location candidates: $candidates_csv"

  for candidate_location in "${candidates[@]}"; do
    [ -z "$candidate_location" ] && continue

    echo "Trying App Service Plan location: $candidate_location"
    if az appservice plan create \
      --name "$APP_SERVICE_PLAN_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --location "$candidate_location" \
      --sku "$APP_SERVICE_PLAN_SKU" 2>"$error_file"; then
      PLAN_LOCATION="$candidate_location"
      echo "Created App Service Plan $APP_SERVICE_PLAN_NAME in $PLAN_LOCATION"
      rm -f "$error_file"
      return
    fi

    echo "Failed to create App Service Plan in $candidate_location. Trying next location if available."
  done

  echo "Unable to create App Service Plan $APP_SERVICE_PLAN_NAME in any configured location."
  cat "$error_file"
  rm -f "$error_file"
  exit 1
}

create_function_if_missing() {
  local storage_account_name="$1"
  local storage_account_id="$2"
  local vnet_id="$3"
  local subnet_id="$4"

  if az functionapp show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "Function App $FUNCTION_APP_NAME already exists."
    return
  fi

  echo "Using VNet integration: vnet=$vnet_id, subnet=$subnet_id, vnet-rg=$FUNCTION_VNET_RESOURCE_GROUP"

  az functionapp create \
    --name "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --plan "$APP_SERVICE_PLAN_NAME" \
    --storage-account "$storage_account_id" \
    --vnet "$vnet_id" \
    --subnet "$subnet_id" \
    --functions-version "$FUNCTIONS_VERSION" \
    --runtime "$FUNCTIONS_WORKER_RUNTIME" \
    --runtime-version "$DOTNET_RUNTIME_VERSION"
}

ensure_system_identity() {
  local current_type

  current_type=$(az functionapp identity show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "type" -o tsv | tr -d '\r' || true)

  if [[ "$current_type" == *"SystemAssigned"* ]]; then
    echo "Function App $FUNCTION_APP_NAME already has system identity enabled."
    return
  fi

  az functionapp identity assign --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP"
}

get_function_principal_id() {
  az functionapp identity show --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" --query "principalId" -o tsv | tr -d '\r'
}

assign_role_if_missing() {
  local role_name="$1"
  local scope_id="$2"
  local principal_id="$3"
  local existing

  existing=$(az role assignment list --assignee-object-id "$principal_id" --scope "$scope_id" --query "[?roleDefinitionName=='${role_name}'] | length(@)" -o tsv | tr -d '\r')

  if [ "$existing" != "0" ]; then
    echo "Role [$role_name] already exists on scope: $scope_id"
    return
  fi

  az role assignment create \
    --role "$role_name" \
    --assignee-object-id "$principal_id" \
    --assignee-principal-type ServicePrincipal \
    --scope "$scope_id"
}

set_function_settings() {
  local storage_account_name="$1"
  local aoai_base="$2"
  local aoai_deployment="$3"

  az functionapp config appsettings set \
    --name "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --settings \
      "AzureWebJobsStorage__accountName=$storage_account_name" \
      "AzureWebJobsStorage__credential=managedidentity" \
      "AzureWebJobsStorage__blobServiceUri=https://${storage_account_name}.blob.core.windows.net" \
      "AzureWebJobsStorage__queueServiceUri=https://${storage_account_name}.queue.core.windows.net" \
      "AzureWebJobsStorage__tableServiceUri=https://${storage_account_name}.table.core.windows.net" \
      "AzureOpenAI:Base=$aoai_base" \
      "AzureOpenAI:Deployment=$aoai_deployment" \
      "CredentialFree=True" \
      "AzureOpenAI:CredentialFree=True" \
      "FUNCTIONS_EXTENSION_VERSION=$FUNCTIONS_EXTENSION_VERSION" \
      "FUNCTIONS_WORKER_RUNTIME=$FUNCTIONS_WORKER_RUNTIME" \
      "WEBSITE_RUN_FROM_PACKAGE=1"

  # Remove legacy connection-string setting to force identity-based host storage.
  az functionapp config appsettings delete \
    --name "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --setting-names AzureWebJobsStorage >/dev/null || true

  az functionapp config set \
    --name "$FUNCTION_APP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --min-tls-version "$MIN_TLS_VERSION"

  az functionapp restart --name "$FUNCTION_APP_NAME" --resource-group "$RESOURCE_GROUP" >/dev/null
}

execute_step() {
  local raw_storage_value
  local storage_account_name
  local storage_account_id
  local function_vnet_id
  local function_subnet_id
  local storage_scope
  local principal_id
  local aoai_base
  local aoai_deployment

  raw_storage_value=$(read_env_value "AZURE_BLOB_ACCOUNT_NAME")
  storage_account_name=$(normalize_storage_account_name "$raw_storage_value")
  storage_account_id=$(get_storage_account_id "$storage_account_name")
  aoai_base=$(read_env_value "AZURE_OPENAI_ENDPOINT")
  aoai_deployment=$(read_env_value "AZURE_OPENAI_Deployment")

  case $1 in
    1)
      echo "1. Creating resource group $RESOURCE_GROUP in $LOCATION"
      az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
      ;;
    2)
      echo "2. Creating Windows App Service Plan $APP_SERVICE_PLAN_NAME with SKU $APP_SERVICE_PLAN_SKU"
      ensure_resource_group
      create_plan_if_missing
      ;;
    3)
      echo "3. Creating Windows Azure Function App $FUNCTION_APP_NAME with storage account $storage_account_name"
      require_non_empty "AZURE_BLOB_ACCOUNT_NAME" "$raw_storage_value"
      require_non_empty "storage account name parsed from AZURE_BLOB_ACCOUNT_NAME" "$storage_account_name"
      require_non_empty "storage account resource ID for $storage_account_name" "$storage_account_id"
      ensure_resource_group
      create_plan_if_missing
      require_non_empty "App Service Plan location" "$PLAN_LOCATION"
      function_vnet_id=$(ensure_function_vnet "$PLAN_LOCATION")
      require_non_empty "Function VNet $FUNCTION_VNET_NAME in resource group $FUNCTION_VNET_RESOURCE_GROUP" "$function_vnet_id"
      function_subnet_id=$(ensure_function_subnet_id)
      require_non_empty "Function subnet $FUNCTION_SUBNET_NAME in $FUNCTION_VNET_NAME" "$function_subnet_id"
      create_function_if_missing "$storage_account_name" "$storage_account_id" "$function_vnet_id" "$function_subnet_id"
      ;;
    4)
      echo "4. Enabling system identity for Function App $FUNCTION_APP_NAME"
      ensure_system_identity
      ;;
    5)
      echo "5. Assigning Storage data-plane roles on $storage_account_name to Function App $FUNCTION_APP_NAME"
      require_non_empty "AZURE_BLOB_ACCOUNT_NAME" "$raw_storage_value"
      require_non_empty "storage account name parsed from AZURE_BLOB_ACCOUNT_NAME" "$storage_account_name"
      ensure_system_identity
      principal_id=$(get_function_principal_id)
      require_non_empty "Function App principal ID" "$principal_id"
      storage_scope=$(resource_id_by_type_and_name "Microsoft.Storage/storageAccounts" "$storage_account_name")
      require_non_empty "storage account resource ID for $storage_account_name" "$storage_scope"
      assign_role_if_missing "Storage Blob Data Owner" "$storage_scope" "$principal_id"
      assign_role_if_missing "Storage Queue Data Contributor" "$storage_scope" "$principal_id"
      assign_role_if_missing "Storage Table Data Contributor" "$storage_scope" "$principal_id"
      ;;
    6)
      echo "6. Setting Function App app settings and minimum TLS version"
      require_non_empty "AZURE_BLOB_ACCOUNT_NAME" "$raw_storage_value"
      require_non_empty "storage account name parsed from AZURE_BLOB_ACCOUNT_NAME" "$storage_account_name"
      require_non_empty "AZURE_OPENAI_ENDPOINT" "$aoai_base"
      require_non_empty "AZURE_OPENAI_Deployment" "$aoai_deployment"
      set_function_settings "$storage_account_name" "$aoai_base" "$aoai_deployment"
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
  for step in {1..6}; do
    execute_step "$step"
  done
fi