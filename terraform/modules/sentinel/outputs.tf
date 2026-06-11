# modules/sentinel/outputs.tf

output "workspace_id" {
  description = "Resource ID del Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "workspace_name" {
  description = "Nombre del workspace para queries KQL"
  value       = azurerm_log_analytics_workspace.main.name
}

output "sentinel_portal_url" {
  description = "URL directa al portal de Microsoft Sentinel"
  value       = "https://portal.azure.com/#blade/Microsoft_Azure_Security_Insights/MainMenuBlade/0/subscriptionId/${data.azurerm_subscription.current.subscription_id}/resourceGroup/${var.resource_group_name}/workspaceName/${azurerm_log_analytics_workspace.main.name}"
}

output "action_group_id" {
  description = "ID del Action Group para alertas"
  value       = azurerm_monitor_action_group.security_alerts.id
}
