# modules/keyvault/main.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

# Sufijo aleatorio para nombre único global del Key Vault
resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_key_vault" "main" {
  name                       = "kv-${var.app_name}-${random_string.kv_suffix.result}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = var.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled   = var.purge_protection_enabled
  tags                       = var.tags

  # Restringir acceso de red (OPA KV-001: deny si no hay network_acls)
  network_acls {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    # Permite acceso desde la subnet del ACI
    virtual_network_subnet_ids = [var.subnet_public_id]
  }

  # Acceso para el SP de Terraform (administración)
  access_policy {
    tenant_id = var.tenant_id
    object_id = var.admin_object_id
    secret_permissions      = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
    key_permissions         = ["Get", "List", "Create", "Delete", "Purge"]
    certificate_permissions = ["Get", "List"]
  }

  # Lifecycle: prevenir destrucción accidental del Key Vault en producción
  lifecycle {
    prevent_destroy = false  # true en producción; false en lab para poder hacer destroy
  }
}

# Acceso de la Managed Identity del ACI solo si se provee el principal_id
resource "azurerm_key_vault_access_policy" "aci" {
  count = var.aci_principal_id != "" ? 1 : 0

  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = var.tenant_id
  object_id    = var.aci_principal_id

  # ACI solo necesita leer secretos, no administrarlos
  secret_permissions = ["Get", "List"]
}

# ── Secretos almacenados ──────────────────────────────────────
resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.db_password
  key_vault_id = azurerm_key_vault.main.id
  content_type = "password"
  tags         = var.tags

  lifecycle {
    ignore_changes = [value]  # No sobreescribir si el secreto ya existe y fue rotado manualmente
  }
}

resource "azurerm_key_vault_secret" "flask_secret_key" {
  name         = "flask-secret-key"
  value        = var.flask_secret_key
  key_vault_id = azurerm_key_vault.main.id
  content_type = "application-secret"
  tags         = var.tags

  lifecycle {
    ignore_changes = [value]
  }
}
