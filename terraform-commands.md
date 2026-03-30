# Comandos utiles de Terraform

---

## Comandos principales (flujo normal)

| Comando | Para que sirve |
|---------|---------------|
| `terraform init` | Inicializa el proyecto: descarga proveedores y configura el backend. Siempre es el primer comando. |
| `terraform plan` | Muestra que va a crear, modificar o borrar. No hace nada, solo muestra el plan. |
| `terraform apply` | Ejecuta los cambios del plan. Pide confirmacion antes de aplicar. |
| `terraform apply -auto-approve` | Igual que apply pero sin pedir confirmacion. Util en CI/CD. |
| `terraform destroy` | Borra TODOS los recursos gestionados por este estado. Pide confirmacion. |
| `terraform destroy -auto-approve` | Igual que destroy pero sin pedir confirmacion. |

---

## Ver informacion del estado

| Comando | Para que sirve |
|---------|---------------|
| `terraform show` | Muestra el contenido completo del state file actual. |
| `terraform state list` | Lista todos los recursos que Terraform conoce (esta en el state). |
| `terraform state show <recurso>` | Muestra los detalles de un recurso concreto del state. |
| `terraform output` | Muestra los valores de los outputs definidos en outputs.tf. |
| `terraform output <nombre>` | Muestra solo el valor de un output concreto. |

```bash
# Ejemplo: ver detalles de una instancia EC2 especifica
terraform state show aws_instance.example

# Ejemplo: ver el output de la IP publica
terraform output public_ip
```

---

## Formatear y validar codigo

| Comando | Para que sirve |
|---------|---------------|
| `terraform fmt` | Formatea los ficheros .tf al estilo estandar de Terraform. |
| `terraform fmt -recursive` | Igual pero tambien entra en subcarpetas. |
| `terraform validate` | Comprueba que el codigo es sintacticamente correcto. No necesita credenciales. |

```bash
# Buena practica: siempre antes de hacer commit
terraform fmt -recursive
terraform validate
```

---

## Workspaces

| Comando | Para que sirve |
|---------|---------------|
| `terraform workspace list` | Lista todos los workspaces existentes. El activo tiene un `*`. |
| `terraform workspace show` | Muestra el workspace activo actualmente. |
| `terraform workspace new <nombre>` | Crea un nuevo workspace y cambia a el. |
| `terraform workspace select <nombre>` | Cambia al workspace indicado. |
| `terraform workspace delete <nombre>` | Borra un workspace (debe estar vacio, sin recursos). |

```bash
# Flujo tipico con workspaces
terraform workspace new dev
terraform apply
terraform workspace select prod
terraform apply
terraform workspace list
```

---

## Gestionar el state manualmente

| Comando | Para que sirve |
|---------|---------------|
| `terraform state mv <origen> <destino>` | Mueve/renombra un recurso dentro del state sin recrearlo. |
| `terraform state rm <recurso>` | Elimina un recurso del state sin borrarlo de la nube. |
| `terraform import <recurso> <id>` | Importa un recurso ya existente en la nube al state de Terraform. |
| `terraform refresh` | Actualiza el state con el estado real de la nube (sin hacer cambios). |

```bash
# Ejemplo: importar una VM de Azure que existe pero no esta en el state
terraform import azurerm_linux_virtual_machine.example /subscriptions/.../myVM

# Ejemplo: quitar un recurso del state sin borrarlo de la nube
terraform state rm aws_instance.example
```

---

## Backend y proveedores

| Comando | Para que sirve |
|---------|---------------|
| `terraform init -backend-config=backend.hcl` | Inicializa con configuracion de backend externa (file layout). |
| `terraform init -upgrade` | Actualiza los proveedores a la ultima version compatible. |
| `terraform providers` | Muestra los proveedores que usa el proyecto actual. |
| `terraform version` | Muestra la version de Terraform instalada. |

---

## Opciones utiles en plan y apply

| Opcion | Para que sirve |
|--------|---------------|
| `terraform plan -out=tfplan` | Guarda el plan en un fichero para aplicarlo despues exactamente. |
| `terraform apply tfplan` | Aplica exactamente el plan guardado (sin preguntar ni recalcular). |
| `terraform plan -var="puerto=9090"` | Pasa el valor de una variable directamente por linea de comandos. |
| `terraform plan -var-file="prod.tfvars"` | Usa un fichero de variables especifico. |
| `terraform plan -target=<recurso>` | Solo planifica/aplica un recurso concreto (usar con cuidado). |
| `terraform plan -destroy` | Muestra que borraria un destroy, sin ejecutarlo. |

```bash
# Flujo seguro para produccion: guardar el plan y luego aplicarlo
terraform plan -out=tfplan
# (revisar el plan)
terraform apply tfplan
```

---

## Depuracion

| Comando / Variable | Para que sirve |
|--------------------|---------------|
| `TF_LOG=DEBUG terraform apply` | Activa logs detallados para depurar errores. |
| `TF_LOG=ERROR terraform apply` | Solo muestra errores. Niveles: TRACE, DEBUG, INFO, WARN, ERROR. |
| `terraform console` | Abre una consola interactiva para evaluar expresiones HCL. |
| `terraform graph` | Genera un grafo de dependencias entre recursos (formato DOT). |

```bash
# Probar una expresion en la consola interactiva
terraform console
> var.server_port        # devuelve el valor de la variable
> cidrsubnet("10.0.0.0/16", 8, 1)   # evalua funciones
```

---

## Resumen del flujo mas habitual

```bash
# 1. Inicializar el proyecto (una sola vez o al cambiar de backend)
terraform init

# 2. Ver que va a cambiar
terraform plan

# 3. Aplicar los cambios
terraform apply

# 4. Al terminar la practica, borrar todo para no pagar
terraform destroy
```
