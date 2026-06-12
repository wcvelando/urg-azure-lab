# environments/prod/locals.tf
# ============================================================
# Valores PROD — más restrictivos, más resilientes y más caros
# Diferencias clave vs lab:
#   - purge_protection = true (no se puede destruir accidentalmente)
#   - backup_retention = 35 días (PCI-DSS compliant)
#   - geo_redundant_backup = true
#   - mysql_sku = GP tier (General Purpose, más performance)
#   - log_retention = 90 días (PCI-DSS Req.10.7)
#   - prevent_destroy = true en recursos críticos
# ============================================================

locals {
  environment = "prod"
  app_name    = "studentrecords"
  project     = "seguridad-cloud-ugr"

  container_image = "ghcr.io/${var.github_owner}/student-records:latest"

  common_tags = {
    Environment = local.environment
    Project     = local.project
    Course      = "seguridad-cloud-ugr"
    ManagedBy   = "terraform"
    Owner       = var.github_owner
    CostCenter  = "educacion"
    Compliance  = "PCI-DSS"
  }

  vnet_address_space  = ["10.1.0.0/16"]
  subnet_public_cidr  = "10.1.1.0/24"
  subnet_private_cidr = "10.1.2.0/24"

  # Compute: más recursos para soportar carga real
  container_cpu    = 1.0
  container_memory = 2.0
  app_port         = 5000

  # Database: General Purpose para prod, con geo-redundancia
  mysql_sku            = "GP_Standard_D2ds_v4"
  mysql_version        = "8.0.21"
  backup_retention     = 35   # PCI-DSS: >= 30 días
  geo_redundant_backup = true # Protección ante fallo de región

  # Key Vault: máxima protección en prod
  soft_delete_retention = 90   # Máximo: 90 días
  purge_protection      = true # NUNCA se puede destruir accidentalmente en prod

  # Sentinel: PCI-DSS Req.10.7 — 90 días de retención
  log_retention = 90
  enable_ti     = true
}
