# modules/compute/main.tf

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

resource "azurerm_container_group" "main" {
  name                = "aci-${var.app_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  ip_address_type     = "Public"
  os_type             = "Linux"

  # Managed Identity: el ACI puede autenticarse en Key Vault sin credenciales
  # Cubre OPA ACI-004 y permite leer secretos de forma segura
  identity {
    type = "SystemAssigned"
  }

  container {
    name   = "student-records"
    image  = var.container_image
    cpu    = tostring(var.cpu)
    memory = tostring(var.memory_gb)

    ports {
      port     = var.app_port
      protocol = "TCP"
    }

    # Variables de entorno NO sensibles
    environment_variables = {
      FLASK_ENV = var.flask_env
      APP_PORT  = tostring(var.app_port)
      DB_NAME   = var.db_name
      DB_HOST   = var.db_host
    }

    # Variables sensibles: nunca visibles en los logs del pipeline ni en el state en texto plano
    secure_environment_variables = {
      DB_USER          = var.db_user
      DB_PASSWORD      = var.db_password
      FLASK_SECRET_KEY = var.flask_secret_key
    }
  }

  tags = var.tags
}
