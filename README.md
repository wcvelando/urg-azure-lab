# 🔐 Lab DevSecOps Azure — Seguridad en Cloud Services · UGR

## Estructura del repositorio

```
lab-devsecops-azure/
├── app/                          # Flask app con vulnerabilidades intencionales
│   ├── app.py
│   ├── requirements.txt
│   └── Dockerfile
├── terraform/                    # Infraestructura Azure (VNet, ACI, MySQL, Key Vault)
│   ├── main.tf
│   ├── backend.tf.example
│   ├── setup-backend.sh          # Crea el Storage Account para tfstate
│   └── sentinel/
│       ├── main.tf               # Log Analytics + Sentinel + Analytics Rules
│       └── threat-intelligence/
│           └── main.tf           # Conectores TI: Microsoft TI + AlienVault OTX
├── policies/conftest/
│   └── azure_security.rego       # Políticas OPA (7 secciones)
├── sentinel/
│   ├── playbooks/
│   │   ├── playbook-sql-injection-response.json
│   │   └── playbook-ti-enrichment.json
│   ├── workbooks/
│   │   └── security-posture-queries.kql
│   └── threat-intelligence/
│       └── ti-queries.kql
├── .github/workflows/
│   ├── devsecops-pipeline.yml    # Pipeline seguridad: Gitleaks, Semgrep, ZAP, etc.
│   └── terraform-infra.yml      # Pipeline infra: validate → plan → apply (manual)
└── .zap/rules.tsv
```

## Pipelines

| Pipeline | Disparado por | Jobs |
|----------|---------------|------|
| `devsecops-pipeline.yml` | Push a main/develop | Gitleaks, Semgrep, OWASP DC, Checkov, OPA, Trivy, GHCR, ZAP |
| `terraform-infra.yml` | Push en terraform/** | Validate, Checkov, OPA, Plan, **Apply (manual)**, Destroy |

## GitHub Secrets necesarios

```
ARM_CLIENT_ID, ARM_CLIENT_SECRET, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
BACKEND_RESOURCE_GROUP, BACKEND_STORAGE_ACCOUNT, BACKEND_CONTAINER
BACKEND_KEY, BACKEND_ACCESS_KEY
OTX_API_KEY  (para Threat Intelligence)
```

## Inicio rápido

```bash
# 1. Fork y clonar
git clone https://github.com/TU_USUARIO/lab-devsecops-azure.git

# 2. Crear Storage Account para tfstate (una sola vez)
chmod +x terraform/setup-backend.sh && ./terraform/setup-backend.sh

# 3. Desplegar infraestructura
cd terraform/ && terraform init && terraform apply -var="github_owner=TU_USUARIO"

# 4. Desplegar Sentinel
cd sentinel/ && terraform init && terraform apply -var="alert_email=tu@email.com"

# 5. Desplegar Threat Intelligence
cd sentinel/threat-intelligence/ && terraform apply -var="otx_api_key=TU_KEY"
```
