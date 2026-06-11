# modules/sentinel/variables.tf

variable "resource_group_name" {
  description = "Nombre del Resource Group"
  type        = string
}

variable "location" {
  description = "Región de Azure"
  type        = string
}

variable "workspace_name" {
  description = "Nombre del Log Analytics Workspace"
  type        = string
  default     = "law-sentinel-lab"
}

variable "retention_in_days" {
  description = "Días de retención de logs (PCI-DSS Req.10.7 exige >= 90 en producción)"
  type        = number
  default     = 30

  validation {
    condition     = var.retention_in_days >= 30
    error_message = "retention_in_days debe ser >= 30. PCI-DSS exige >= 90 en producción."
  }
}

variable "alert_email" {
  description = "Email para notificaciones de alertas de Sentinel"
  type        = string

  validation {
    condition     = can(regex("^[^@]+@[^@]+\\.[^@]+$", var.alert_email))
    error_message = "alert_email debe ser una dirección de email válida."
  }
}

variable "key_vault_id" {
  description = "Resource ID del Key Vault para configurar diagnostic settings"
  type        = string
  default     = ""
}

variable "otx_api_key" {
  description = "API Key de AlienVault OTX para el feed TAXII (dejar vacío para omitir)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_threat_intelligence" {
  description = "Habilitar conectores de Threat Intelligence (Microsoft TI + OTX)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags aplicados a todos los recursos"
  type        = map(string)
  default     = {}
}
