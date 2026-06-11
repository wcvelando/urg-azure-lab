# environments/lab/locals.tf

locals {
  # ── Identificadores del ambiente ─────────────────────────
  environment  = "lab"
  app_name     = "studentrecords"
  project      = "seguridad-cloud-ugr"

  # Imagen resuelta: si se pasa container_image vacío, usa GHCR
  container_image = "ghcr.io/${var.github_owner}/student-records:latest"

  # ── Tags obligatorios (OPA GOV-001) ──────────────────────
  # Todos los recursos del lab heredan estos tags
  common_tags = {
    Environment = local.environment
    Project     = local.project
    Course      = "seguridad-cloud-ugr"
    ManagedBy   = "terraform"
    Owner       = var.github_owner
    CostCenter  = "educacion"
  }

  # ── Red ───────────────────────────────────────────────────
  vnet_address_space  = ["10.0.0.0/16"]
  subnet_public_cidr  = "10.0.1.0/24"
  subnet_private_cidr = "10.0.2.0/24"

  # ── Compute: tamaño reducido para minimizar costos en lab ─
  container_cpu    = 0.5
  container_memory = 1.0
  app_port         = 5000

  # ── Database: tier Burstable (más barato para lab) ────────
  mysql_sku            = "B_Standard_B1ms"
  mysql_version        = "8.0.21"
  backup_retention     = 7
  geo_redundant_backup = false

  # ── Key Vault: soft delete mínimo para lab ────────────────
  soft_delete_retention = 7
  purge_protection      = false  # false en lab para poder hacer destroy

  # ── Sentinel: retención mínima para lab ──────────────────
  log_retention = 30
  enable_ti     = true
}
