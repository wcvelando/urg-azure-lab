# modules/compute/outputs.tf

output "container_group_id" {
  description = "Resource ID del Container Group"
  value       = azurerm_container_group.main.id
}

output "public_ip" {
  description = "IP pública del Container Group"
  value       = azurerm_container_group.main.ip_address
}

output "app_url" {
  description = "URL completa de la aplicación"
  value       = "http://${azurerm_container_group.main.ip_address}:${var.app_port}"
}

output "principal_id" {
  description = "Principal ID de la Managed Identity del ACI (para Key Vault access policy)"
  value       = azurerm_container_group.main.identity[0].principal_id
}
