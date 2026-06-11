# modules/database/main.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

resource "azurerm_mysql_flexible_server" "main" {
  name                   = "mysql-${var.app_name}"
  resource_group_name    = var.resource_group_name
  location               = var.location
  administrator_login    = var.administrator_login
  administrator_password = var.administrator_password
  sku_name               = var.sku_name
  version                = var.mysql_version
  delegated_subnet_id    = var.delegated_subnet_id

  backup_retention_days        = var.backup_retention_days
  geo_redundant_backup_enabled = var.geo_redundant_backup

  storage {
    auto_grow_enabled = true
    size_gb           = 20
  }

  tags = var.tags

  # Prevenir destrucción accidental en producción
  lifecycle {
    prevent_destroy = false  # Cambiar a true en producción
  }
}

resource "azurerm_mysql_flexible_database" "main" {
  name                = var.database_name
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.main.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

# Forzar SSL en todas las conexiones (OPA + Checkov CKV_AZURE_182)
resource "azurerm_mysql_flexible_server_configuration" "ssl" {
  name                = "require_secure_transport"
  resource_group_name = var.resource_group_name
  server_name         = azurerm_mysql_flexible_server.main.name
  value               = "ON"
}
