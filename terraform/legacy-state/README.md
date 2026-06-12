# Estado legacy

Esta carpeta conserva copias locales ignoradas por Git del estado que utilizaba
la configuración monolítica eliminada.

No ejecutar Terraform desde esta carpeta. Los recursos Azure registrados en
esos estados no se migran automáticamente a `environments/lab`.

Antes de gestionar esos recursos desde un ambiente, hay que elegir una de estas
opciones:

1. Destruirlos usando temporalmente la revisión anterior del código monolítico.
2. Importarlos al estado del ambiente y adaptar los nombres/configuración.

Los archivos `terraform.tfstate*` contienen datos sensibles y no deben
versionarse.
