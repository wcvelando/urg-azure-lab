# modules/network/variables.tf

variable "resource_group_name" {
  description = "Nombre del Resource Group donde se crean los recursos de red"
  type        = string
}

variable "location" {
  description = "Región de Azure"
  type        = string
}

variable "app_name" {
  description = "Nombre base de la aplicación (usado como prefijo en todos los recursos)"
  type        = string

  validation {
    condition     = length(var.app_name) >= 3 && length(var.app_name) <= 20
    error_message = "app_name debe tener entre 3 y 20 caracteres."
  }
}

variable "vnet_address_space" {
  description = "Espacio de direcciones del Virtual Network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_public_cidr" {
  description = "CIDR de la subnet pública (para ACI)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_private_cidr" {
  description = "CIDR de la subnet privada (para MySQL)"
  type        = string
  default     = "10.0.2.0/24"
}

variable "allowed_http_port" {
  description = "Puerto expuesto por la aplicación"
  type        = number
  default     = 5000

  validation {
    condition     = var.allowed_http_port > 0 && var.allowed_http_port <= 65535
    error_message = "allowed_http_port debe ser un puerto válido (1-65535)."
  }
}

variable "tags" {
  description = "Tags aplicados a todos los recursos del módulo"
  type        = map(string)
  default     = {}
}
