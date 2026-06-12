# modules/sentinel/main.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

data "azurerm_subscription" "current" {}

# ── Log Analytics Workspace ───────────────────────────────────
resource "azurerm_log_analytics_workspace" "main" {
  name                = var.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  tags                = var.tags
}

# ── Habilitar Sentinel ────────────────────────────────────────
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "main" {
  workspace_id = azurerm_log_analytics_workspace.main.id
}

# ── Data Connectors ───────────────────────────────────────────
resource "azurerm_sentinel_data_connector_azure_active_directory" "aad" {
  name                       = "connector-azure-ad"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}

resource "azurerm_sentinel_data_connector_microsoft_cloud_app_security" "defender" {
  name                       = "connector-defender-cloud"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}

# ── Threat Intelligence: Microsoft TI (condicional) ───────────
resource "azurerm_sentinel_data_connector_microsoft_threat_intelligence" "msft_ti" {
  count                                        = var.enable_threat_intelligence ? 1 : 0
  name                                         = "connector-microsoft-ti"
  log_analytics_workspace_id                   = azurerm_log_analytics_workspace.main.id
  microsoft_emerging_threat_feed_lookback_date = "1970-01-01T00:00:00Z"
  depends_on                                   = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}

# ── Threat Intelligence: AlienVault OTX TAXII (condicional) ──
resource "azurerm_sentinel_data_connector_threat_intelligence_taxii" "otx" {
  count                      = var.enable_threat_intelligence && var.otx_api_key != "" ? 1 : 0
  name                       = "connector-otx"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  display_name               = "AlienVault OTX - Web Attacks"
  api_root_url               = "https://otx.alienvault.com/taxii2/feeds/"
  collection_id              = "user_AlienVault"
  user_name                  = "otx-user"
  password                   = var.otx_api_key
  polling_frequency          = "OnceADay"
  lookback_date              = timeadd(timestamp(), "-168h")
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}

# ── Watchlist para IOCs manuales (demo en clase) ──────────────
resource "azurerm_sentinel_watchlist" "lab_iocs" {
  name                       = "watchlist-lab-iocs"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  display_name               = "Lab IOCs - Demo en clase"
  item_search_key            = "IPAddress"
  description                = "IOCs manuales para demos. Agregar IPs antes de clase."
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
}

# ── Diagnostic Settings Key Vault → Log Analytics ─────────────
resource "azurerm_monitor_diagnostic_setting" "key_vault" {
  count                      = var.key_vault_id != "" ? 1 : 0
  name                       = "diag-keyvault-sentinel"
  target_resource_id         = var.key_vault_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  enabled_log { category = "AuditEvent" }
  metric {
    category = "AllMetrics"
    enabled  = false
  }
}

# ── Action Group ──────────────────────────────────────────────
resource "azurerm_monitor_action_group" "security_alerts" {
  name                = "ag-security-alerts"
  resource_group_name = var.resource_group_name
  short_name          = "sec-alerts"
  email_receiver {
    name                    = "security-team"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }
  tags = var.tags
}

# ── Analytics Rule 1: Key Vault acceso inusual ────────────────
resource "azurerm_sentinel_alert_rule_scheduled" "keyvault_unusual_access" {
  name                       = "rule-keyvault-unusual-access"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  display_name               = "OPA-VIOLATION: Key Vault accedido desde IP no autorizada"
  description                = "Correlaciona con política OPA KV-001. OWASP A02."
  severity                   = "High"
  enabled                    = true
  tactics                    = ["CredentialAccess", "InitialAccess"]
  techniques                 = ["T1555", "T1078"]
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
  query                      = <<-KQL
    AzureDiagnostics
    | where ResourceType == "VAULTS"
    | where OperationName in ("SecretGet","KeyGet")
    | where ResultType == "Success"
    | extend CallerIP = tostring(callerIpAddress_s)
    | where CallerIP !startswith "10.0.1." and CallerIP !startswith "AzureServices"
    | project TimeGenerated, CallerIP, OperationName, ResourceGroup, Resource
    | order by TimeGenerated desc
  KQL
  query_frequency            = "PT5M"
  query_period               = "PT10M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  incident_configuration {
    create_incident = true
    grouping {
      enabled                 = true
      lookback_duration       = "PT1H"
      reopen_closed_incidents = false
      entity_matching_method  = "AllEntities"
    }
  }
  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "CallerIP"
    }
  }
}

# ── Analytics Rule 2: SQL Injection ───────────────────────────
resource "azurerm_sentinel_alert_rule_scheduled" "sql_injection" {
  name                       = "rule-sql-injection-attempt"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  display_name               = "OPA-VIOLATION: SQL Injection detectado (OWASP A03)"
  description                = "Correlaciona con Semgrep SAST finding en app.py."
  severity                   = "High"
  enabled                    = true
  tactics                    = ["Execution", "InitialAccess"]
  techniques                 = ["T1190", "T1059"]
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
  query                      = <<-KQL
    ContainerInstanceLog_CL
    | where LogEntry_s has_any ("' OR ","1=1","UNION SELECT","DROP TABLE","'; --")
    | extend Payload = extract(@"name=([^&\s]+)", 1, LogEntry_s)
    | project TimeGenerated, ContainerGroup_s, Payload, LogEntry_s
    | order by TimeGenerated desc
  KQL
  query_frequency            = "PT5M"
  query_period               = "PT15M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  incident_configuration {
    create_incident = true
    grouping {
      enabled                 = true
      lookback_duration       = "PT30M"
      reopen_closed_incidents = true
      entity_matching_method  = "AllEntities"
    }
  }
}

# ── Analytics Rule 3: NSG modificado ─────────────────────────
resource "azurerm_sentinel_alert_rule_scheduled" "nsg_change" {
  name                       = "rule-nsg-critical-port-opened"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  display_name               = "OPA-VIOLATION: NSG modificado - puerto crítico abierto"
  description                = "Correlaciona con políticas OPA NSG-001/002/003."
  severity                   = "High"
  enabled                    = true
  tactics                    = ["DefenseEvasion", "LateralMovement"]
  techniques                 = ["T1562", "T1021"]
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
  query                      = <<-KQL
    AzureActivity
    | where OperationNameValue == "MICROSOFT.NETWORK/NETWORKSECURITYGROUPS/SECURITYRULES/WRITE"
    | where ActivityStatusValue == "Success"
    | extend DestPort     = tostring(parse_json(Properties_d).destinationPortRange)
    | extend SourcePrefix = tostring(parse_json(Properties_d).sourceAddressPrefix)
    | where DestPort in ("22","3306","5432","1433")
          and SourcePrefix in ("*","Internet","0.0.0.0/0")
    | project TimeGenerated, Caller, DestPort, SourcePrefix, ResourceGroup
    | order by TimeGenerated desc
  KQL
  query_frequency            = "PT5M"
  query_period               = "PT10M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  incident_configuration {
    create_incident = true
    grouping {
      enabled                 = true
      lookback_duration       = "PT1H"
      reopen_closed_incidents = false
      entity_matching_method  = "AllEntities"
    }
  }
  entity_mapping {
    entity_type = "Account"
    field_mapping {
      identifier  = "FullName"
      column_name = "Caller"
    }
  }
}

# ── Analytics Rule 4: Brute force Key Vault ───────────────────
resource "azurerm_sentinel_alert_rule_scheduled" "keyvault_brute_force" {
  name                       = "rule-keyvault-brute-force"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  display_name               = "Key Vault: múltiples accesos fallidos (brute force)"
  description                = "5+ accesos fallidos en 10 min. OWASP A02."
  severity                   = "Medium"
  enabled                    = true
  tactics                    = ["CredentialAccess"]
  techniques                 = ["T1110"]
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
  query                      = <<-KQL
    AzureDiagnostics
    | where ResourceType == "VAULTS"
    | where ResultType in ("Unauthorized","Forbidden")
    | summarize FailedAttempts = count() by callerIpAddress_s, bin(TimeGenerated, 10m)
    | where FailedAttempts >= 5
    | project TimeGenerated, CallerIP = callerIpAddress_s, FailedAttempts
    | order by FailedAttempts desc
  KQL
  query_frequency            = "PT10M"
  query_period               = "PT10M"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  incident_configuration {
    create_incident = true
    grouping {
      enabled                 = true
      lookback_duration       = "PT1H"
      reopen_closed_incidents = false
      entity_matching_method  = "AllEntities"
    }
  }
  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "CallerIP"
    }
  }
}

# ── Analytics Rule 5: TI - IP maliciosa en Key Vault ─────────
resource "azurerm_sentinel_alert_rule_scheduled" "ti_malicious_ip" {
  count                      = var.enable_threat_intelligence ? 1 : 0
  name                       = "rule-ti-malicious-ip"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  display_name               = "TI: IP maliciosa detectada en actividad del lab"
  description                = "Correlaciona actividad del lab con ThreatIntelligenceIndicator."
  severity                   = "High"
  enabled                    = true
  tactics                    = ["InitialAccess", "CredentialAccess"]
  techniques                 = ["T1078", "T1190"]
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.main]
  query                      = <<-KQL
    let TI_IPs = ThreatIntelligenceIndicator
      | where TimeGenerated > ago(7d) and Active == true
      | where isnotempty(NetworkIP) or isnotempty(NetworkSourceIP)
      | extend MaliciousIP = coalesce(NetworkIP, NetworkSourceIP)
      | summarize TI_Score=max(ConfidenceScore), TI_Type=any(ThreatType),
                  TI_Source=any(SourceSystem) by MaliciousIP;
    AzureDiagnostics
    | where ResourceType == "VAULTS"
    | where TimeGenerated > ago(1h)
    | extend CallerIP = tostring(callerIpAddress_s)
    | join kind=inner TI_IPs on $left.CallerIP == $right.MaliciousIP
    | project TimeGenerated, CallerIP, OperationName, TI_Type, TI_Score, TI_Source
    | order by TI_Score desc
  KQL
  query_frequency            = "PT1H"
  query_period               = "P1D"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  incident_configuration {
    create_incident = true
    grouping {
      enabled                 = true
      lookback_duration       = "PT1H"
      reopen_closed_incidents = false
      entity_matching_method  = "AllEntities"
    }
  }
  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "CallerIP"
    }
  }
}

# ── Analytics Rule 6: TI - Watchlist IOCs ────────────────────
resource "azurerm_sentinel_alert_rule_scheduled" "ti_watchlist" {
  count                      = var.enable_threat_intelligence ? 1 : 0
  name                       = "rule-ti-watchlist-match"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  display_name               = "TI: IOC de watchlist detectado en actividad reciente"
  description                = "Correlaciona actividad con la watchlist manual. Ideal para demos."
  severity                   = "Medium"
  enabled                    = true
  depends_on                 = [azurerm_sentinel_log_analytics_workspace_onboarding.main, azurerm_sentinel_watchlist.lab_iocs]
  query                      = <<-KQL
    let WL = _GetWatchlist("watchlist-lab-iocs")
        | project IPAddress=tostring(IPAddress), ThreatType=tostring(ThreatType);
    AzureDiagnostics
    | where TimeGenerated > ago(1h)
    | extend SourceIP = tostring(callerIpAddress_s)
    | where isnotempty(SourceIP)
    | join kind=inner WL on $left.SourceIP == $right.IPAddress
    | project TimeGenerated, SourceIP, OperationName, ThreatType
    | order by TimeGenerated desc
  KQL
  query_frequency            = "PT5M"
  query_period               = "PT1H"
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0
  incident_configuration {
    create_incident = true
    grouping {
      enabled                 = true
      lookback_duration       = "PT30M"
      reopen_closed_incidents = false
      entity_matching_method  = "AllEntities"
    }
  }
  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "SourceIP"
    }
  }
}
