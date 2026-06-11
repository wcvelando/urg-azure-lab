# environments/prod/outputs.tf

output "app_url" {
  description = "URL de la aplicación"
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

output "sentinel_portal_url" {
  description = "URL directa al portal de Sentinel"
  value       = module.sentinel.sentinel_portal_url
}

output "workspace_name" {
  description = "Nombre del Log Analytics Workspace"
  value       = module.sentinel.workspace_name
}

output "important_warning" {
  description = "Aviso sobre purge_protection en prod"
  value       = "⚠️  PROD: purge_protection=true. Para destruir: cambiar a false + esperar retention period."
}
