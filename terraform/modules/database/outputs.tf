# modules/database/outputs.tf

output "server_id" {
  description = "Resource ID del MySQL Flexible Server"
  value       = azurerm_mysql_flexible_server.main.id
}

output "server_fqdn" {
  description = "FQDN del servidor MySQL para conexiones"
  value       = azurerm_mysql_flexible_server.main.fqdn
}

output "server_name" {
  description = "Nombre del servidor MySQL"
  value       = azurerm_mysql_flexible_server.main.name
}

output "database_name" {
  description = "Nombre de la base de datos"
  value       = azurerm_mysql_flexible_database.main.name
}
