# modules/network/outputs.tf

output "vnet_id" {
  description = "ID del Virtual Network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Nombre del Virtual Network"
  value       = azurerm_virtual_network.main.name
}

output "subnet_public_id" {
  description = "ID de la subnet pública (para ACI)"
  value       = azurerm_subnet.public.id
}

output "subnet_public_cidr" {
  description = "CIDR de la subnet pública"
  value       = var.subnet_public_cidr
}

output "subnet_private_id" {
  description = "ID de la subnet privada (para MySQL)"
  value       = azurerm_subnet.private.id
}

output "nsg_app_id" {
  description = "ID del NSG de la aplicación"
  value       = azurerm_network_security_group.app.id
}

output "nsg_db_id" {
  description = "ID del NSG de la base de datos"
  value       = azurerm_network_security_group.db.id
}
