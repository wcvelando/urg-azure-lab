# environments/lab/outputs.tf

output "app_url" {
  description = "URL de la aplicación desplegada"
  value       = module.compute.app_url
}

output "key_vault_name" {
  description = "Nombre del Key Vault"
  value       = module.keyvault.key_vault_name
}

output "db_host" {
  description = "FQDN del servidor MySQL"
  value       = module.database.server_fqdn
}

output "resource_group" {
  description = "Nombre del Resource Group"
  value       = azurerm_resource_group.main.name
}

output "container_image" {
  description = "Imagen Docker desplegada"
  value       = local.container_image
}

output "sentinel_portal_url" {
  description = "URL directa al portal de Sentinel"
  value       = module.sentinel.sentinel_portal_url
}

output "workspace_name" {
  description = "Nombre del Log Analytics Workspace"
  value       = module.sentinel.workspace_name
}

# Instrucción de destrucción al final para recordarla
output "destroy_command" {
  description = "Comando para destruir el ambiente al finalizar el lab"
  value       = "terraform destroy -var='github_owner=${var.github_owner}' -var='alert_email=${var.alert_email}'"
}
