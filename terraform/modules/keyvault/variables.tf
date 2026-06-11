# modules/keyvault/variables.tf

variable "resource_group_name" {
  description = "Nombre del Resource Group"
  type        = string
}

variable "location" {
  description = "Región de Azure"
  type        = string
}

variable "app_name" {
  description = "Nombre base de la aplicación (prefijo de recursos)"
  type        = string
}

variable "tenant_id" {
  description = "Tenant ID de Azure AD (de data.azurerm_client_config.current.tenant_id)"
  type        = string
  sensitive   = true
}

variable "admin_object_id" {
  description = "Object ID del SP o usuario que administra el Key Vault"
  type        = string
  sensitive   = true
}

variable "aci_principal_id" {
  description = "Principal ID de la Managed Identity del ACI (para leer secretos)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "subnet_public_id" {
  description = "ID de la subnet pública para restringir acceso de red al Key Vault"
  type        = string
}

variable "soft_delete_retention_days" {
  description = "Días de retención en soft delete (mínimo 7, producción 90)"
  type        = number
  default     = 7

  validation {
    condition     = var.soft_delete_retention_days >= 7 && var.soft_delete_retention_days <= 90
    error_message = "soft_delete_retention_days debe estar entre 7 y 90."
  }
}

variable "purge_protection_enabled" {
  description = "Habilitar purge protection (obligatorio en producción)"
  type        = bool
  default     = false
}

variable "db_password" {
  description = "Contraseña generada para MySQL (se almacena en Key Vault)"
  type        = string
  sensitive   = true
}

variable "flask_secret_key" {
  description = "Secret key de Flask (se almacena en Key Vault)"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags aplicados a todos los recursos"
  type        = map(string)
  default     = {}
}
