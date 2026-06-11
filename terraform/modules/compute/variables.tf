# modules/compute/variables.tf

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

variable "container_image" {
  description = "Imagen Docker completa (ej: ghcr.io/usuario/student-records:latest)"
  type        = string

  validation {
    condition     = !startswith(var.container_image, "docker.io/") || can(regex("^docker\\.io/", var.container_image))
    error_message = "En producción usar imagen de registry privado (ghcr.io o ACR), no docker.io."
  }
}

variable "cpu" {
  description = "CPU asignada al contenedor (cores)"
  type        = number
  default     = 0.5

  validation {
    condition     = var.cpu >= 0.5 && var.cpu <= 4.0
    error_message = "cpu debe estar entre 0.5 y 4.0 cores."
  }
}

variable "memory_gb" {
  description = "Memoria asignada al contenedor (GB)"
  type        = number
  default     = 1.0

  validation {
    condition     = var.memory_gb >= 0.5 && var.memory_gb <= 16.0
    error_message = "memory_gb debe estar entre 0.5 y 16.0 GB."
  }
}

variable "app_port" {
  description = "Puerto expuesto por la aplicación"
  type        = number
  default     = 5000
}

variable "db_host" {
  description = "FQDN del servidor MySQL"
  type        = string
}

variable "db_user" {
  description = "Usuario de base de datos"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Contraseña de base de datos"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Nombre de la base de datos"
  type        = string
  default     = "studentsdb"
}

variable "flask_secret_key" {
  description = "Secret key para Flask"
  type        = string
  sensitive   = true
}

variable "flask_env" {
  description = "Entorno Flask (development/production)"
  type        = string
  default     = "production"

  validation {
    condition     = contains(["development", "production"], var.flask_env)
    error_message = "flask_env debe ser 'development' o 'production'."
  }
}

variable "tags" {
  description = "Tags aplicados a todos los recursos"
  type        = map(string)
  default     = {}
}
