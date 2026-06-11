# environments/prod/main.tf
# ============================================================
# Ambiente PROD — configuración endurecida
# IMPORTANTE: purge_protection = true → NO se puede hacer destroy
# sin primero cambiar ese valor a false y esperar el período de retención
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
}

provider "azurerm" {
  features {
    key_vault {
      # En prod: NO purgar al destruir, recuperar si existe
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      # En prod: no permitir borrar RG si tiene recursos
      prevent_deletion_if_contains_resources = true
    }
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.app_name}-${local.environment}"
  location = var.location
  tags     = local.common_tags

  lifecycle {
    prevent_destroy = true  # En prod: no permitir terraform destroy sin quitar esto
  }
}

resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
  min_upper        = 3
  min_lower        = 3
  min_numeric      = 3
  min_special      = 3
}

resource "random_password" "flask_secret_key" {
  length  = 64
  special = false
}

module "network" {
  source              = "../../modules/network"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  app_name            = local.app_name
  vnet_address_space  = local.vnet_address_space
  subnet_public_cidr  = local.subnet_public_cidr
  subnet_private_cidr = local.subnet_private_cidr
  allowed_http_port   = local.app_port
  tags                = local.common_tags
  depends_on          = [azurerm_resource_group.main]
}

module "database" {
  source                 = "../../modules/database"
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
  tags                   = local.common_tags
  depends_on             = [module.network]
}

module "compute" {
  source              = "../../modules/compute"
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
  depends_on          = [module.database]
}

module "keyvault" {
  source                     = "../../modules/keyvault"
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
  depends_on                 = [module.compute]
}

module "sentinel" {
  source                     = "../../modules/sentinel"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  workspace_name             = "law-sentinel-${local.environment}"
  retention_in_days          = local.log_retention
  alert_email                = var.alert_email
  key_vault_id               = module.keyvault.key_vault_id
  otx_api_key                = var.otx_api_key
  enable_threat_intelligence = local.enable_ti
  tags                       = local.common_tags
  depends_on                 = [module.keyvault]
}
