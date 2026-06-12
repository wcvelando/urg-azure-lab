# Terraform

La infraestructura se despliega exclusivamente desde una raíz de ambiente:

- `environments/lab`
- `environments/prod`

Los módulos de `modules/` no se ejecutan directamente.

## Uso local

```bash
cd terraform/environments/lab
cp backend.tf.example backend.tf
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Para producción, sustituir `lab` por `prod`. Cada ambiente utiliza un backend
y una clave de estado independientes.

No ejecutar `terraform init`, `plan`, `apply` ni `destroy` desde el directorio
`terraform/`.
