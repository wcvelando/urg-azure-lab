# modules/network/main.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

# ── Virtual Network ───────────────────────────────────────────
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.app_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# ── Subnet pública (ACI) ──────────────────────────────────────
resource "azurerm_subnet" "public" {
  name                 = "snet-public-${var.app_name}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_public_cidr]

  delegation {
    name = "aci-delegation"
    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# ── Subnet privada (MySQL) ────────────────────────────────────
resource "azurerm_subnet" "private" {
  name                 = "snet-private-${var.app_name}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_private_cidr]
  service_endpoints    = ["Microsoft.Sql"]

  delegation {
    name = "mysql-delegation"
    service_delegation {
      name    = "Microsoft.DBforMySQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# ── NSG app: solo permite el puerto de la app + deny-all ──────
resource "azurerm_network_security_group" "app" {
  name                = "nsg-app-${var.app_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "allow-app-port"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = tostring(var.allowed_http_port)
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Deny-all explícito — buena práctica: todo lo no permitido explícitamente se deniega
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ── NSG db: solo permite MySQL desde la subnet de la app ──────
resource "azurerm_network_security_group" "db" {
  name                = "nsg-db-${var.app_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Solo permite MySQL desde la subnet pública (donde vive el ACI)
  security_rule {
    name                       = "allow-mysql-from-app-subnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = var.subnet_public_cidr
    destination_address_prefix = "*"
  }

  # Bloqueo explícito desde Internet — correlaciona con OPA NSG-001
  security_rule {
    name                       = "deny-mysql-from-internet"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  # Deny-all explícito
  security_rule {
    name                       = "deny-all-inbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ── Asociar NSG a las subnets ─────────────────────────────────
resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.db.id
}
