# modules/database/variables.tf

variable "resource_group_name" {
  description = "Nombre del Resource Group"
  type        = string
}

variable "location" {
  description = "Región de Azure"
  type        = string
}

variable "app_name" {
  description = "Nombre base de la aplicación"
  type        = string
}

variable "administrator_login" {
  description = "Usuario administrador del MySQL"
  type        = string
  sensitive   = true

  validation {
    condition     = !contains(["admin", "root", "sa", "administrator"], lower(var.administrator_login))
    error_message = "administrator_login no puede ser admin, root, sa o administrator (credenciales débiles)."
  }
}

variable "administrator_password" {
  description = "Contraseña del administrador MySQL (generada con random_password)"
  type        = string
  sensitive   = true
}

variable "delegated_subnet_id" {
  description = "ID de la subnet privada delegada para MySQL Flexible Server"
  type        = string
}

variable "mysql_version" {
  description = "Versión del motor MySQL"
  type        = string
  default     = "8.0.21"

  validation {
    condition     = contains(["5.7", "8.0.21"], var.mysql_version)
    error_message = "mysql_version debe ser 5.7 u 8.0.21."
  }
}

variable "sku_name" {
  description = "SKU del MySQL Flexible Server (B_Standard_B1ms para lab, GP_Standard_D2ds_v4 para prod)"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "backup_retention_days" {
  description = "Días de retención de backups (ISO 27017 CLD.12.3.1 >= 7)"
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 7
    error_message = "backup_retention_days debe ser >= 7 (ISO 27017 CLD.12.3.1)."
  }
}

variable "geo_redundant_backup" {
  description = "Habilitar backup geo-redundante (recomendado en producción)"
  type        = bool
  default     = false
}

variable "database_name" {
  description = "Nombre de la base de datos dentro del servidor"
  type        = string
  default     = "studentsdb"
}

variable "tags" {
  description = "Tags aplicados a todos los recursos"
  type        = map(string)
  default     = {}
}
