# ============================================================
# terraform/sentinel/threat-intelligence/main.tf
#
# Threat Intelligence para Azure Sentinel
# Fuentes:
#   1. Microsoft Threat Intelligence (nativo, gratuito)
#   2. TAXII/STIX - AlienVault OTX (feed público gratuito)
#
# Recursos creados:
#   - Data Connector: Microsoft Threat Intelligence
#   - Data Connector: TAXII (AlienVault OTX)
#   - Analytics Rules de correlación TI ↔ logs del lab
#   - Watchlist con IOCs manuales para demos en clase
# ============================================================

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" { features {} }

# ─── Variables ───────────────────────────────────────────────
variable "resource_group_name" {
  type    = string
  default = "rg-devsecops-lab"
}

variable "workspace_name" {
  description = "Nombre del Log Analytics Workspace de Sentinel"
  type        = string
  default     = "law-sentinel-lab"
}

variable "location" {
  type    = string
  default = "eastus"
}

# API key de AlienVault OTX
# Obtener en: otx.alienvault.com → Settings → API Key
# Pasar como: -var="otx_api_key=TU_API_KEY"
variable "otx_api_key" {
  description = "API Key de AlienVault OTX para el feed TAXII"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tags" {
  type = map(string)
  default = {
    Environment = "lab"
    Course      = "seguridad-cloud-ugr"
    Unit        = "IV-threat-intelligence"
    ManagedBy   = "terraform"
  }
}

# ─── Data sources ────────────────────────────────────────────
data "azurerm_log_analytics_workspace" "sentinel" {
  name                = var.workspace_name
  resource_group_name = var.resource_group_name
}

# ─── Conector 1: Microsoft Threat Intelligence ───────────────
# Feed nativo de Microsoft: IPs, dominios y URLs maliciosas
# actualizados en tiempo real desde el ecosistema Microsoft.
# Gratuito, sin configuración adicional.
resource "azurerm_sentinel_data_connector_microsoft_threat_intelligence" "msft_ti" {
  name                                         = "connector-microsoft-ti"
  log_analytics_workspace_id                   = data.azurerm_log_analytics_workspace.sentinel.id
  microsoft_emerging_threat_feed_lookback_date = "1970-01-01T00:00:00Z"
}

# ─── Conector 2: TAXII - AlienVault OTX ──────────────────────
# AlienVault OTX expone feeds STIX/TAXII públicos.
# Cada "pulse" de OTX es una colección de IOCs sobre una amenaza.
#
# URL del servidor TAXII de OTX:
#   https://otx.alienvault.com/taxii/discovery
#
# Colecciones disponibles (ejemplos relevantes para el lab):
#   - user_AlienVault: IOCs generales de AlienVault
#   - 325ecde5-a00d-4d35-a3c3-7e60a07dd0c9: SQL Injection IPs
#
# Requiere cuenta gratuita en otx.alienvault.com
resource "azurerm_sentinel_data_connector_threat_intelligence_taxii" "otx_general" {
  name                       = "connector-otx-general"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id

  display_name = "AlienVault OTX - General Feed"
  api_root_url = "https://otx.alienvault.com/taxii2/feeds/"
  collection_id = "user_AlienVault"

  # Autenticación OTX: usar la API key como password
  # username puede ser cualquier string no vacío
  user_name = "otx-user"
  password  = var.otx_api_key != "" ? var.otx_api_key : "CONFIGURAR_OTX_API_KEY"

  polling_frequency = "OnceADay"

  lookback_date = timeadd(timestamp(), "-168h") # últimos 7 días
}

# Feed específico de OTX para ataques web / SQLi
resource "azurerm_sentinel_data_connector_threat_intelligence_taxii" "otx_web_attacks" {
  name                       = "connector-otx-web-attacks"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id

  display_name  = "AlienVault OTX - Web Attacks & SQLi"
  api_root_url  = "https://otx.alienvault.com/taxii2/feeds/"
  collection_id = "325ecde5-a00d-4d35-a3c3-7e60a07dd0c9"

  user_name = "otx-user"
  password  = var.otx_api_key != "" ? var.otx_api_key : "CONFIGURAR_OTX_API_KEY"

  polling_frequency = "OnceADay"

  lookback_date = timeadd(timestamp(), "-168h")
}

# ─── Watchlist: IOCs manuales para demo en clase ─────────────
# Una watchlist es una tabla de IOCs que cargás manualmente.
# Útil para demos: agregás IPs de "atacantes" antes de clase
# y las reglas KQL las detectan instantáneamente.
resource "azurerm_sentinel_watchlist" "lab_iocs" {
  name                       = "watchlist-lab-iocs"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id
  display_name               = "Lab IOCs - Demo en clase"
  item_search_key            = "IPAddress"

  description = "IOCs manuales para demostraciones en clase. Agregar IPs de atacantes conocidos o IPs de prueba para simular detecciones de Threat Intelligence."

  # El contenido de la watchlist se carga via portal o API después del deploy.
  # Ver sección 14.5 de la guía docente para el procedimiento.
}

# ─── Analytics Rule TI-1: IP maliciosa en logs del lab ───────
# Cruza los logs de acceso al Key Vault contra los IOCs de TI.
# Si la IP que accedió al Key Vault está en ThreatIntelligenceIndicator → alerta.
resource "azurerm_sentinel_alert_rule_scheduled" "ti_malicious_ip_keyvault" {
  name                       = "rule-ti-malicious-ip-keyvault"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id
  display_name               = "TI: IP maliciosa detectada en acceso a Key Vault"
  description                = "Correlaciona los accesos al Key Vault con la tabla ThreatIntelligenceIndicator. Detecta cuando una IP conocida como maliciosa (según Microsoft TI o AlienVault OTX) accede a los secretos del lab."
  severity                   = "High"
  enabled                    = true

  query = <<-KQL
    let TI_IPs = ThreatIntelligenceIndicator
      | where TimeGenerated > ago(7d)
      | where isnotempty(NetworkIP) or isnotempty(NetworkSourceIP)
      | where Active == true
      | extend MaliciousIP = coalesce(NetworkIP, NetworkSourceIP)
      | summarize
          TI_Description = any(Description),
          TI_ConfidenceScore = max(ConfidenceScore),
          TI_ThreatType = any(ThreatType),
          TI_Source = any(SourceSystem)
        by MaliciousIP
      | project MaliciousIP, TI_Description, TI_ConfidenceScore,
                TI_ThreatType, TI_Source;
    AzureDiagnostics
    | where ResourceType == "VAULTS"
    | where TimeGenerated > ago(1h)
    | where isnotempty(callerIpAddress_s)
    | extend CallerIP = tostring(callerIpAddress_s)
    | join kind=inner TI_IPs on $left.CallerIP == $right.MaliciousIP
    | project
        TimeGenerated,
        CallerIP,
        OperationName,
        Resource,
        TI_Description,
        TI_ConfidenceScore,
        TI_ThreatType,
        TI_Source
    | order by TI_ConfidenceScore desc
  KQL

  query_frequency = "PT1H"
  query_period    = "P1D"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

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

  tactics    = ["InitialAccess", "CredentialAccess"]
  techniques = ["T1078", "T1555"]
}

# ─── Analytics Rule TI-2: IP maliciosa en requests de la app ─
# Cruza los logs de la app Flask (ContainerInstanceLog)
# contra IOCs de TI. Detecta si una IP conocida ataca el endpoint.
resource "azurerm_sentinel_alert_rule_scheduled" "ti_malicious_ip_app" {
  name                       = "rule-ti-malicious-ip-app"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id
  display_name               = "TI: IP maliciosa realizando requests a la app (OWASP A03)"
  description                = "Correlaciona los logs de la app Flask con ThreatIntelligenceIndicator. Si una IP de un atacante conocido realiza requests al endpoint /students/search, genera alerta de alta severidad."
  severity                   = "High"
  enabled                    = true

  query = <<-KQL
    let TI_IPs = ThreatIntelligenceIndicator
      | where TimeGenerated > ago(7d)
      | where Active == true
      | where isnotempty(NetworkIP) or isnotempty(NetworkSourceIP)
      | extend MaliciousIP = coalesce(NetworkIP, NetworkSourceIP)
      | summarize
          TI_Description = any(Description),
          TI_ConfidenceScore = max(ConfidenceScore),
          TI_ThreatType = any(ThreatType),
          TI_Tags = make_set(Tags)
        by MaliciousIP;
    ContainerInstanceLog_CL
    | where TimeGenerated > ago(1h)
    | extend
        ClientIP = extract(@"(\d+\.\d+\.\d+\.\d+)", 1, LogEntry_s),
        Endpoint = extract(@"(GET|POST|PUT|DELETE)\s+(/\S+)", 2, LogEntry_s),
        IsSQLi   = LogEntry_s has_any ("' OR ", "1=1", "UNION SELECT", "'; --")
    | where isnotempty(ClientIP)
    | join kind=inner TI_IPs on $left.ClientIP == $right.MaliciousIP
    | project
        TimeGenerated,
        ClientIP,
        Endpoint,
        IsSQLi,
        LogEntry_s,
        TI_Description,
        TI_ConfidenceScore,
        TI_ThreatType,
        TI_Tags
    | order by TI_ConfidenceScore desc
  KQL

  query_frequency = "PT30M"
  query_period    = "PT1H"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  incident_configuration {
    create_incident = true
    grouping {
      enabled                 = true
      lookback_duration       = "PT30M"
      reopen_closed_incidents = true
      entity_matching_method  = "AllEntities"
    }
  }

  entity_mapping {
    entity_type = "IP"
    field_mapping {
      identifier  = "Address"
      column_name = "ClientIP"
    }
  }

  tactics    = ["InitialAccess", "Execution"]
  techniques = ["T1190", "T1059"]
}

# ─── Analytics Rule TI-3: IOC en Watchlist detectado ─────────
# Correlaciona cualquier actividad en el lab contra la watchlist
# de IOCs manuales cargados por el docente para la demo.
resource "azurerm_sentinel_alert_rule_scheduled" "ti_watchlist_match" {
  name                       = "rule-ti-watchlist-match"
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.sentinel.id
  display_name               = "TI: IOC de watchlist del lab detectado en actividad reciente"
  description                = "Correlaciona toda la actividad reciente del lab contra la watchlist watchlist-lab-iocs. Útil para demos en clase: cargar una IP antes de la demo y ver la detección en tiempo real."
  severity                   = "Medium"
  enabled                    = true

  query = <<-KQL
    let WatchlistIOCs = _GetWatchlist("watchlist-lab-iocs")
      | project IPAddress = tostring(IPAddress),
                Description = tostring(Description),
                ThreatType  = tostring(ThreatType);
    union
    (
      AzureDiagnostics
      | where ResourceType == "VAULTS"
      | where TimeGenerated > ago(1h)
      | extend SourceIP = tostring(callerIpAddress_s), Source = "KeyVault"
    ),
    (
      AzureActivity
      | where TimeGenerated > ago(1h)
      | extend SourceIP = tostring(CallerIpAddress), Source = "AzureActivity"
    )
    | where isnotempty(SourceIP)
    | join kind=inner WatchlistIOCs on $left.SourceIP == $right.IPAddress
    | project
        TimeGenerated,
        SourceIP,
        Source,
        Description,
        ThreatType,
        OperationName
    | order by TimeGenerated desc
  KQL

  query_frequency = "PT5M"
  query_period    = "PT1H"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

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

  tactics    = ["Reconnaissance", "InitialAccess"]
  techniques = ["T1595", "T1190"]
}

# ─── Outputs ─────────────────────────────────────────────────
output "ti_connector_msft" {
  value       = azurerm_sentinel_data_connector_microsoft_threat_intelligence.msft_ti.name
  description = "Nombre del conector Microsoft TI"
}

output "ti_connector_otx_general" {
  value       = azurerm_sentinel_data_connector_threat_intelligence_taxii.otx_general.name
  description = "Nombre del conector OTX general"
}

output "watchlist_name" {
  value       = azurerm_sentinel_watchlist.lab_iocs.name
  description = "Nombre de la watchlist de IOCs para demo"
}

output "ti_query_table" {
  value       = "ThreatIntelligenceIndicator"
  description = "Tabla KQL donde se almacenan todos los IOCs ingestados"
}
