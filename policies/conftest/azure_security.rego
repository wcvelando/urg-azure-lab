package main
import future.keywords.if
import future.keywords.in

# ── NSG ──────────────────────────────────────────────────────
deny contains msg if {
    r := input.resource.azurerm_network_security_group[n]
    rule := r.security_rule[_]
    rule.direction == "Inbound"; rule.access == "Allow"
    rule.destination_port_range == "3306"
    rule.source_address_prefix in {"*","Internet","0.0.0.0/0"}
    msg := sprintf("[NSG-001] NSG '%s': puerto 3306 abierto a Internet. Correlaciona con Sentinel rule-nsg-critical-port-opened.", [n])
}
deny contains msg if {
    r := input.resource.azurerm_network_security_group[n]
    rule := r.security_rule[_]
    rule.direction == "Inbound"; rule.access == "Allow"
    rule.destination_port_range == "22"
    rule.source_address_prefix in {"*","Internet","0.0.0.0/0"}
    msg := sprintf("[NSG-002] NSG '%s': puerto 22 (SSH) abierto a Internet. CIS Azure 6.1.", [n])
}
deny contains msg if {
    r := input.resource.azurerm_network_security_group[n]
    rule := r.security_rule[_]
    rule.direction == "Inbound"; rule.access == "Allow"
    rule.destination_port_range == "3389"
    rule.source_address_prefix in {"*","Internet","0.0.0.0/0"}
    msg := sprintf("[NSG-003] NSG '%s': puerto 3389 (RDP) abierto a Internet. CIS Azure 6.2.", [n])
}
warn contains msg if {
    r := input.resource.azurerm_network_security_group[n]
    deny_all := [x | x := r.security_rule[_]; x.access == "Deny"; x.source_address_prefix == "*"; x.destination_port_range == "*"]
    count(deny_all) == 0
    msg := sprintf("[NSG-004] NSG '%s': sin regla deny-all explícita.", [n])
}

# ── Key Vault ─────────────────────────────────────────────────
deny contains msg if {
    r := input.resource.azurerm_key_vault[n]
    not r.network_acls
    msg := sprintf("[KV-001] Key Vault '%s': sin network_acls. Accesible desde cualquier IP. CKV_AZURE_131. Correlaciona con Sentinel: rule-keyvault-unusual-access.", [n])
}
deny contains msg if {
    r := input.resource.azurerm_key_vault[n]
    r.network_acls
    r.network_acls.default_action != "Deny"
    msg := sprintf("[KV-002] Key Vault '%s': network_acls.default_action debe ser 'Deny'.", [n])
}
warn contains msg if {
    r := input.resource.azurerm_key_vault[n]
    r.purge_protection_enabled == false
    r.tags.Environment != "lab"
    msg := sprintf("[KV-003] Key Vault '%s': purge_protection debe ser true en producción.", [n])
}
warn contains msg if {
    r := input.resource.azurerm_key_vault[n]
    r.soft_delete_retention_days < 7
    msg := sprintf("[KV-004] Key Vault '%s': soft_delete_retention_days=%d < 7.", [n, r.soft_delete_retention_days])
}

# ── Contenedores ──────────────────────────────────────────────
deny contains msg if {
    r := input.resource.azurerm_container_group[n]
    c := r.container[_]
    startswith(c.image, "docker.io/")
    r.tags.Environment != "lab"
    msg := sprintf("[ACI-001] Container '%s': imagen desde docker.io público. Usar GHCR/ACR. OWASP A06.", [n])
}
warn contains msg if {
    r := input.resource.azurerm_container_group[n]
    not r.identity
    msg := sprintf("[ACI-004] Container group '%s': sin Managed Identity.", [n])
}

# ── Base de datos ─────────────────────────────────────────────
warn contains msg if {
    r := input.resource.azurerm_mysql_flexible_server[n]
    r.backup_retention_days < 7
    msg := sprintf("[DB-001] MySQL '%s': backup_retention_days=%d < 7. ISO 27017 CLD.12.3.1.", [n, r.backup_retention_days])
}
deny contains msg if {
    r := input.resource.azurerm_mysql_flexible_server[n]
    not r.delegated_subnet_id
    msg := sprintf("[DB-002] MySQL '%s': sin integración VNet. Accesible públicamente. OWASP A05.", [n])
}
warn contains msg if {
    v := input.variable[n]
    contains(lower(n), "password")
    v.default != null
    msg := sprintf("[CRED-001] Variable '%s': password no debe tener valor default.", [n])
}

# ── Gobernanza ────────────────────────────────────────────────
required_tags := {"Environment","ManagedBy","Course"}
warn contains msg if {
    r := input.resource.azurerm_resource_group[n]
    missing := required_tags - {t | r.tags[t]}
    count(missing) > 0
    msg := sprintf("[GOV-001] Resource Group '%s': faltan tags: %v.", [n, missing])
}

# ── Observabilidad (Unidad IV) ────────────────────────────────
warn contains msg if {
    input.resource.azurerm_key_vault[kv]
    diag := [d | d := input.resource.azurerm_monitor_diagnostic_setting[_]; d.log_analytics_workspace_id != null]
    count(diag) == 0
    msg := sprintf("[OBS-001] Key Vault '%s' sin diagnostic settings hacia Log Analytics.", [kv])
}
warn contains msg if {
    not input.resource.azurerm_log_analytics_workspace
    msg := "[OBS-002] Sin Log Analytics Workspace. Prerequisito de Sentinel. Unidad IV."
}

# ── Sentinel (Unidad IV) ──────────────────────────────────────
warn contains msg if {
    r := input.resource.azurerm_log_analytics_workspace[n]
    r.retention_in_days < 30
    msg := sprintf("[SIEM-001] Log Analytics '%s': retención %d días < 30. PCI-DSS >= 90.", [n, r.retention_in_days])
}
warn contains msg if {
    r := input.resource.azurerm_log_analytics_workspace[n]
    r.retention_in_days >= 30
    r.retention_in_days < 90
    r.tags.Environment != "lab"
    msg := sprintf("[SIEM-002] Log Analytics '%s': retención %d días. PCI-DSS Req.10.7 >= 90 en producción.", [n, r.retention_in_days])
}
deny contains msg if {
    input.resource.azurerm_sentinel_log_analytics_workspace_onboarding[_]
    connectors := [c | c := input.resource[rt][_]; startswith(rt, "azurerm_sentinel_data_connector")]
    count(connectors) == 0
    msg := "[SIEM-003] Sentinel sin data connectors. Sin conectores no hay datos."
}
warn contains msg if {
    input.resource.azurerm_sentinel_log_analytics_workspace_onboarding[_]
    rules := [r | r := input.resource.azurerm_sentinel_alert_rule_scheduled[_]]
    count(rules) == 0
    msg := "[SIEM-004] Sentinel sin reglas analíticas scheduled. Unidad IV."
}
