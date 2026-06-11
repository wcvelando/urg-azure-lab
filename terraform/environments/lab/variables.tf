# environments/lab/variables.tf

variable "location" {
  description = "Región de Azure"
  type        = string
  default     = "eastus"
}

variable "github_owner" {
  description = "Usuario u organización de GitHub (para imagen GHCR)"
  type        = string
}

variable "alert_email" {
  description = "Email para alertas de Sentinel"
  type        = string
}

variable "otx_api_key" {
  description = "API Key de AlienVault OTX (dejar vacío para omitir TI)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_admin_username" {
  description = "Usuario administrador de MySQL"
  type        = string
  sensitive   = true
  default     = "sqladmin"
}
