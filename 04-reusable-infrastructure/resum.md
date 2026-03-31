# Capitulo 4: Modulos en Terraform

Un modulo es una carpeta con ficheros `.tf` que puedes reutilizar. Como una funcion: la escribes una vez y la llamas con distintos parametros.

---

## Module Basics (estructura basica)

Un modulo es simplemente una carpeta con su propio `main.tf`:

```
modules/
└── webserver/
    ├── main.tf       ← recursos del modulo
    ├── variables.tf  ← parametros de entrada
    └── outputs.tf    ← valores de salida
```

Para usarlo desde otro fichero:

```hcl
module "webserver_staging" {
  source = "../../modules/webserver"   # ruta a la carpeta del modulo
}
```

Despues de añadir o cambiar un modulo hay que ejecutar `terraform init` para que Terraform lo registre.

---

## Module Inputs (parametros de entrada)

Son las `variable` definidas dentro del modulo. Permiten personalizar el comportamiento al llamarlo.

**Dentro del modulo** (`modules/webserver/variables.tf`):
```hcl
variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
}

variable "environment" {
  description = "Nombre del entorno (staging, prod...)"
  type        = string
}
```

**Al llamar al modulo**:
```hcl
module "webserver_staging" {
  source        = "../../modules/webserver"
  instance_type = "t3.micro"    # input
  environment   = "staging"     # input
}

module "webserver_prod" {
  source        = "../../modules/webserver"
  instance_type = "t3.large"    # mismo modulo, distintos inputs
  environment   = "prod"
}
```

---

## Module Locals (variables internas)

Son valores calculados dentro del modulo que no se exponen al exterior ni se pueden sobreescribir desde fuera. Sirven para evitar repetir expresiones largas.

```hcl
locals {
  # valor calculado una vez, usado en varios recursos
  name_prefix = "${var.environment}-${var.project_name}"

  # mapa de configuracion segun el entorno
  instance_config = {
    staging = "t3.micro"
    prod    = "t3.large"
  }
}

resource "aws_instance" "web" {
  instance_type = local.instance_config[var.environment]   # usa el local
  tags = {
    Name = local.name_prefix   # reuso sin repetir la expresion
  }
}
```

**Diferencia con variables**: los `locals` no se pueden pasar desde fuera, son solo para uso interno del modulo.

---

## Module Outputs (valores de salida)

Son los `output` del modulo: los valores que el modulo "devuelve" al codigo que lo llama.

**Dentro del modulo** (`modules/webserver/outputs.tf`):
```hcl
output "public_ip" {
  value = aws_instance.web.public_ip
}

output "alb_dns_name" {
  value = aws_lb.example.dns_name
}
```

**Al usar el output desde fuera**:
```hcl
module "webserver_staging" {
  source = "../../modules/webserver"
  # ...
}

# Acceder al output con: module.<nombre_modulo>.<nombre_output>
output "staging_ip" {
  value = module.webserver_staging.public_ip
}
```

---

## Module Gotchas (errores comunes)

### 1. Rutas de ficheros

Dentro de un modulo, las rutas relativas como `./scripts/init.sh` se resuelven desde donde se llama al modulo, no desde donde esta el modulo. Para referenciar ficheros del propio modulo usa `path.module`:

```hcl
# MAL: ruta relativa ambigua
user_data = file("./scripts/init.sh")

# BIEN: ruta relativa al directorio del modulo
user_data = file("${path.module}/scripts/init.sh")
```

### 2. Variables de entorno inline

Los bloques `inline` (como reglas de security group dentro del recurso) no se pueden combinar con recursos separados del mismo tipo. Hay que elegir uno u otro:

```hcl
# MAL: mezclar inline con recursos separados
resource "aws_security_group" "example" {
  ingress { ... }   # inline
}
resource "aws_security_group_rule" "extra" { ... }  # separado → conflicto

# BIEN: solo recursos separados (mas flexible en modulos)
resource "aws_security_group" "example" { }
resource "aws_security_group_rule" "http" { ... }
resource "aws_security_group_rule" "https" { ... }
```

### 3. terraform init obligatorio

Cada vez que añades o cambias el `source` de un modulo debes ejecutar `terraform init` antes del `plan` o `apply`.

---

## Module Versioning (versiones)

Importante para garantizar que el modulo no cambia de forma inesperada al ejecutar `terraform init`.

### Modulos locales

No tienen versionado, se usa directamente la carpeta. El control de versiones lo hace git (tags, ramas).

### Modulos del Terraform Registry

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.0"   # version fija: reproducible y segura

  # version = "~> 3.0"  # permite 3.x pero no 4.0
  # version = ">= 3.0"  # cualquier version >= 3.0 (menos seguro)
}
```

### Modulos en git

```hcl
module "webserver" {
  # apunta a un tag especifico de git
  source = "git::https://github.com/mi-org/mi-repo.git//modules/webserver?ref=v1.2.0"
}
```

**Regla**: en produccion siempre fijar la version. Nunca usar `latest` o sin version.

---

## Resumen

| Concepto | Para que sirve |
|----------|---------------|
| **Basics** | Carpeta reutilizable que se llama con `module {}` |
| **Inputs** | `variable` dentro del modulo → personalizan el comportamiento |
| **Locals** | Valores internos calculados, no accesibles desde fuera |
| **Outputs** | `output` dentro del modulo → devuelven valores al exterior |
| **Gotchas** | Usar `path.module` para rutas, evitar mezclar inline con separado |
| **Versioning** | Fijar siempre la version para evitar cambios inesperados |
