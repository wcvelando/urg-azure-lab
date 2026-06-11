# environments/lab/main.tf
# ============================================================
# Ambiente LAB — Student Records App
# Orquesta los módulos: network, keyvault, database, compute, sentinel
#
# Uso:
#   cd environments/lab/
#   cp backend.tf.example backend.tf  # completar con tus valores
#   terraform init
#   terraform apply -var="github_owner=TU_USUARIO" \
#                   -var="alert_email=tu@email.com" \
#                   -var="otx_api_key=TU_KEY"
# ============================================================

terraform {
  required_version = ">= 1.6.0"

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

  # Backend configurado en backend.tf (en .gitignore)
  # Ver backend.tf.example para la plantilla
}

provider "azurerm" {
  features {
    key_vault {
      # En lab: no bloquear destroy del Key Vault
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# ── Data sources ──────────────────────────────────────────────
data "azurerm_client_config" "current" {}

# ── Resource Group ────────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.app_name}-${local.environment}"
  location = var.location
  tags     = local.common_tags
}

# ── Contraseñas generadas (nunca hardcodeadas) ────────────────
resource "random_password" "db_password" {
  length           = 20
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
}

resource "random_password" "flask_secret_key" {
  length  = 64
  special = false  # evitar caracteres que puedan escaparse en env vars
}

# ── Módulo: Network ───────────────────────────────────────────
module "network" {
  source = "../../modules/network"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  app_name            = local.app_name
  vnet_address_space  = local.vnet_address_space
  subnet_public_cidr  = local.subnet_public_cidr
  subnet_private_cidr = local.subnet_private_cidr
  allowed_http_port   = local.app_port
  tags                = local.common_tags

  depends_on = [azurerm_resource_group.main]
}

# ── Módulo: Database ──────────────────────────────────────────
module "database" {
  source = "../../modules/database"

  resource_group_name    = azurerm_resource_group.main.name
  location               = var.location
  app_name               = local.app_name
  administrator_login    = var.db_admin_username
  administrator_password = random_password.db_password.result
  delegated_subnet_id    = module.network.subnet_private_id
  sku_name               = local.mysql_sku
  mysql_version          = local.mysql_version
  backup_retention_days  = local.backup_retention
  geo_redundant_backup   = local.geo_redundant_backup
  database_name          = "studentsdb"
  tags                   = local.common_tags

  depends_on = [module.network]
}

# ── Módulo: Compute (ACI) — se crea primero para obtener principal_id ──
module "compute" {
  source = "../../modules/compute"

  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  app_name            = local.app_name
  container_image     = local.container_image
  cpu                 = local.container_cpu
  memory_gb           = local.container_memory
  app_port            = local.app_port
  db_host             = module.database.server_fqdn
  db_user             = var.db_admin_username
  db_password         = random_password.db_password.result
  db_name             = module.database.database_name
  flask_secret_key    = random_password.flask_secret_key.result
  flask_env           = "production"
  tags                = local.common_tags

  depends_on = [module.database]
}

# ── Módulo: Key Vault ─────────────────────────────────────────
module "keyvault" {
  source = "../../modules/keyvault"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  app_name                   = local.app_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  admin_object_id            = data.azurerm_client_config.current.object_id
  aci_principal_id           = module.compute.principal_id
  subnet_public_id           = module.network.subnet_public_id
  soft_delete_retention_days = local.soft_delete_retention
  purge_protection_enabled   = local.purge_protection
  db_password                = random_password.db_password.result
  flask_secret_key           = random_password.flask_secret_key.result
  tags                       = local.common_tags

  depends_on = [module.compute]
}

# ── Módulo: Sentinel ──────────────────────────────────────────
module "sentinel" {
  source = "../../modules/sentinel"

  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  workspace_name             = "law-sentinel-${local.environment}"
  retention_in_days          = local.log_retention
  alert_email                = var.alert_email
  key_vault_id               = module.keyvault.key_vault_id
  otx_api_key                = var.otx_api_key
  enable_threat_intelligence = local.enable_ti
  tags                       = local.common_tags

  depends_on = [module.keyvault]
}
