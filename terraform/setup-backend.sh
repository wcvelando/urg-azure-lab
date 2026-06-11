#!/bin/bash
set -euo pipefail
RESOURCE_GROUP="rg-terraform-state"
LOCATION="eastus"
STORAGE_ACCOUNT="stterraformugr$(openssl rand -hex 3)"
CONTAINER_NAME="tfstate"

echo "Creando Storage Account: $STORAGE_ACCOUNT"
az account show --output table || { echo "Ejecutar az login primero"; exit 1; }
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
az storage account create --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" --sku Standard_LRS --kind StorageV2 \
  --min-tls-version TLS1_2 --allow-blob-public-access false --https-only true --output table
az storage container create --name "$CONTAINER_NAME" \
  --account-name "$STORAGE_ACCOUNT" --auth-mode login --output table
az storage account blob-service-properties update \
  --account-name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" \
  --enable-versioning true --output table

STORAGE_KEY=$(az storage account keys list \
  --account-name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" \
  --query "[0].value" --output tsv)

echo ""
echo "========================================="
echo " GitHub Secrets a configurar:"
echo "========================================="
echo "BACKEND_RESOURCE_GROUP  = $RESOURCE_GROUP"
echo "BACKEND_STORAGE_ACCOUNT = $STORAGE_ACCOUNT"
echo "BACKEND_CONTAINER       = $CONTAINER_NAME"
echo "BACKEND_KEY             = lab-devsecops-azure.tfstate"
echo "BACKEND_ACCESS_KEY      = $STORAGE_KEY"
echo "========================================="
