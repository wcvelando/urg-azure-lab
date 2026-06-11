# modules/keyvault/outputs.tf

output "key_vault_id" {
  description = "Resource ID del Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "Nombre del Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI del Key Vault para referencias desde la app"
  value       = azurerm_key_vault.main.vault_uri
}

output "db_password_secret_id" {
  description = "ID del secreto de la contraseña de base de datos en Key Vault"
  value       = azurerm_key_vault_secret.db_password.id
  sensitive   = true
}

output "flask_secret_key_secret_id" {
  description = "ID del secreto del Flask secret key en Key Vault"
  value       = azurerm_key_vault_secret.flask_secret_key.id
  sensitive   = true
}
