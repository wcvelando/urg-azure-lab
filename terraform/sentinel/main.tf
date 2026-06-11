terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 3.100" }
  }
}

provider "azurerm" { features {} }

variable "resource_group_name" { type = string; default = "rg-devsecops-lab" }
variable "location"            { type = string; default = "eastus" }
variable "alert_email"         { description = "Email para alertas de Sentinel"; type = string }
variable "key_vault_id"        { type = string; default = "" }

variable "tags" {
  type = map(string)
  default = {
    Environment = "lab"; Course = "seguridad-cloud-ugr"
    Unit = "IV-operaciones"; ManagedBy = "terraform"
  }
}

data "azurerm_resource_group" "lab"     { name = var.resource_group_name }
data "azurerm_subscription"   "current" {}

# ── Log Analytics Workspace ───────────────────────────────────
resource "azurerm_log_analytics_workspace" "sentinel" {
  name                = "law-sentinel-lab"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ── Habilitar Sentinel ────────────────────────────────────────
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "main" {
  workspace_id = azurerm_log_analytics_workspace.sentinel.id
}

# ── Data Connectors ───────────────────────────────────────────
resource "azurerm_sentinel_data_connector_azure_active_directory" "aad" {
  name                       = "connector-azure-ad"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}

resource "azurerm_sentinel_data_connector_microsoft_cloud_app_security" "defender" {
  name                       = "connector-defender-cloud"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}

# ── Diagnostic Settings: Key Vault → Log Analytics ────────────
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  count                      = var.key_vault_id != "" ? 1 : 0
  name                       = "diag-keyvault-sentinel"
  target_resource_id         = var.key_vault_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id
  enabled_log { category = "AuditEvent" }
  metric { category = "AllMetrics"; enabled = false }
}

# ── Action Group ──────────────────────────────────────────────
resource "azurerm_monitor_action_group" "security_alerts" {
  name                = "ag-security-alerts"
  resource_group_name = var.resource_group_name
  short_name          = "sec-alerts"
  email_receiver {
    name                    = "docente-ugr"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
  tags = var.tags
}

# ── Analytics Rule 1: Key Vault acceso inusual ────────────────
resource "azurerm_sentinel_alert_rule_scheduled" "keyvault_unusual_access" {
  name                       = "rule-keyvault-unusual-access"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id
  display_name               = "OPA-VIOLATION: Key Vault accedido desde IP no autorizada"
  description                = "Detecta accesos al Key Vault desde IPs fuera de 10.0.1.0/24. Correlaciona con política OPA KV-001."
  severity                   = "High"
  enabled                    = true
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
  query = <<-KQL
    AzureDiagnostics
    | where ResourceType == "VAULTS"
    | where OperationName in ("SecretGet","KeyGet")
    | where ResultType == "Success"
    | extend CallerIP = tostring(callerIpAddress_s)
    | where CallerIP !startswith "10.0.1." and CallerIP !startswith "AzureServices"
    | project TimeGenerated, CallerIP, OperationName, ResourceGroup, Resource
    | order by TimeGenerated desc
  KQL
  query_frequency   = "PT5M"
  query_period      = "PT10M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0
  incident_configuration {
    create_incident = true
    grouping { enabled = true; lookback_duration = "PT1H"; reopen_closed_incidents = false; entity_matching_method = "AllEntities" }
  }
  entity_mapping {
    entity_type = "IP"
    field_mapping { identifier = "Address"; column_name = "CallerIP" }
  }
}

# ── Analytics Rule 2: SQL Injection ───────────────────────────
resource "azurerm_sentinel_alert_rule_scheduled" "sql_injection_attempt" {
  name                       = "rule-sql-injection-attempt"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id
  display_name               = "OPA-VIOLATION: Posible SQL Injection detectado (OWASP A03)"
  description                = "Detecta patrones SQLi en logs de la app. Correlaciona con Semgrep finding."
  severity                   = "High"
  enabled                    = true
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
  query = <<-KQL
    ContainerInstanceLog_CL
    | where LogEntry_s has_any ("' OR ","1=1","UNION SELECT","DROP TABLE","'; --")
    | extend SuspiciousPayload = extract(@"name=([^&\s]+)", 1, LogEntry_s)
    | project TimeGenerated, ContainerGroup_s, LogEntry_s, SuspiciousPayload
    | order by TimeGenerated desc
  KQL
  query_frequency   = "PT5M"
  query_period      = "PT15M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0
  incident_configuration {
    create_incident = true
    grouping { enabled = true; lookback_duration = "PT30M"; reopen_closed_incidents = true; entity_matching_method = "AllEntities" }
  }
}

# ── Analytics Rule 3: NSG modificado ─────────────────────────
resource "azurerm_sentinel_alert_rule_scheduled" "nsg_rule_change" {
  name                       = "rule-nsg-critical-port-opened"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id
  display_name               = "OPA-VIOLATION: NSG modificado - puerto crítico abierto a Internet"
  description                = "Detecta cambios en NSG que habilitan puertos 22, 3306 desde Internet. Correlaciona con OPA NSG-001/002."
  severity                   = "High"
  enabled                    = true
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
  query = <<-KQL
    AzureActivity
    | where OperationNameValue == "MICROSOFT.NETWORK/NETWORKSECURITYGROUPS/SECURITYRULES/WRITE"
    | where ActivityStatusValue == "Success"
    | extend DestPort     = tostring(parse_json(Properties_d).destinationPortRange)
    | extend SourcePrefix = tostring(parse_json(Properties_d).sourceAddressPrefix)
    | where DestPort in ("22","3306","5432","1433") and SourcePrefix in ("*","Internet","0.0.0.0/0")
    | project TimeGenerated, Caller, DestPort, SourcePrefix, ResourceGroup
    | order by TimeGenerated desc
  KQL
  query_frequency   = "PT5M"
  query_period      = "PT10M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0
  incident_configuration {
    create_incident = true
    grouping { enabled = true; lookback_duration = "PT1H"; reopen_closed_incidents = false; entity_matching_method = "AllEntities" }
  }
  entity_mapping {
    entity_type = "Account"
    field_mapping { identifier = "FullName"; column_name = "Caller" }
  }
}

# ── Analytics Rule 4: Brute Force Key Vault ───────────────────
resource "azurerm_sentinel_alert_rule_scheduled" "keyvault_brute_force" {
  name                       = "rule-keyvault-brute-force"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id
  display_name               = "Key Vault: múltiples accesos fallidos (posible brute force)"
  description                = "5+ accesos fallidos al Key Vault en 10 min desde la misma IP."
  severity                   = "Medium"
  enabled                    = true
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
  query = <<-KQL
    AzureDiagnostics
    | where ResourceType == "VAULTS"
    | where ResultType in ("Unauthorized","Forbidden")
    | summarize FailedAttempts = count() by callerIpAddress_s, bin(TimeGenerated, 10m)
    | where FailedAttempts >= 5
    | project TimeGenerated, CallerIP = callerIpAddress_s, FailedAttempts
    | order by FailedAttempts desc
  KQL
  query_frequency   = "PT10M"
  query_period      = "PT10M"
  trigger_operator  = "GreaterThan"
  trigger_threshold = 0
  incident_configuration {
    create_incident = true
    grouping { enabled = true; lookback_duration = "PT1H"; reopen_closed_incidents = false; entity_matching_method = "AllEntities" }
  }
  entity_mapping {
    entity_type = "IP"
    field_mapping { identifier = "Address"; column_name = "CallerIP" }
  }
}

# ── Outputs ───────────────────────────────────────────────────
output "workspace_id"         { value = azurerm_log_analytics_workspace.sentinel.id }
output "workspace_name"       { value = azurerm_log_analytics_workspace.sentinel.name }
output "sentinel_portal_url"  {
  value = "https://portal.azure.com/#blade/Microsoft_Azure_Security_Insights/MainMenuBlade/0/subscriptionId/${data.azurerm_subscription.current.subscription_id}/resourceGroup/${var.resource_group_name}/workspaceName/${azurerm_log_analytics_workspace.sentinel.name}"
}
