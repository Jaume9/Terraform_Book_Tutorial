# Resumen por capitulos: lo crucial de cada uno

---

## Capitulo 0 — Hello World (primeros pasos)

**Lo crucial**: entender el ciclo basico de Terraform.

```bash
terraform init     # descarga el proveedor (AWS o Azure)
terraform plan     # muestra que va a crear (sin hacer nada)
terraform apply    # crea los recursos en la nube
terraform destroy  # borra todo (hazlo siempre al terminar para no pagar)
```

Todo fichero `.tf` tiene esta estructura minima:
```hcl
provider "aws" { region = "us-east-2" }      # donde desplegar

resource "aws_instance" "ejemplo" {           # que crear
  ami           = "ami-xxx"
  instance_type = "t2.micro"
}
```

**Diferencia AWS vs Azure**: en Azure todo recurso necesita un `resource_group` previo. En AWS no.

---

## Capitulo 1 — Por que Terraform

**Lo crucial**: entender que problema resuelve y por que es mejor que hacerlo a mano.

- **Infraestructura como codigo (IaC)**: defines la infraestructura en ficheros `.tf` que se guardan en git. Cualquiera puede reproducir el mismo entorno exacto.
- **Idempotente**: puedes ejecutar `terraform apply` 100 veces y el resultado es siempre el mismo. Solo cambia lo que ha cambiado en el codigo.
- **Terraform vs alternativas**:
  - Ansible/Chef/Puppet → configuran servidores ya existentes
  - CloudFormation → solo AWS
  - Terraform → crea infraestructura en cualquier nube, multi-cloud

---

## Capitulo 2 — Sintaxis de Terraform

**Lo crucial**: los bloques basicos del lenguaje HCL.

| Bloque | Para que sirve | Ejemplo |
|--------|---------------|---------|
| `resource` | Crear algo en la nube | `aws_instance`, `azurerm_linux_virtual_machine` |
| `variable` | Parametro configurable | `var.server_port` |
| `output` | Valor que muestra Terraform al acabar | IP publica, URL del LB |
| `data` | Leer algo que ya existe sin crearlo | VPC por defecto, subnets |
| `locals` | Variable interna calculada | prefijos de nombres |

**Interpolacion**: meter variables dentro de strings con `${var.nombre}`.

**user_data**: script bash que se ejecuta cuando arranca una VM. Se usa para instalar software o levantar un servidor web.

**Security Group**: cortafuegos virtual. En AWS todo el trafico esta bloqueado por defecto, hay que abrirlo explicitamente con `ingress`/`egress`.

---

## Capitulo 3 — Gestion del Estado (State)

**Lo crucial**: como Terraform recuerda lo que ha creado y como organizar multiples entornos.

- **State file** (`terraform.tfstate`): fichero JSON donde Terraform guarda lo que existe en la nube. Al hacer `plan`, compara tu codigo con este fichero para saber que cambiar. Nunca editarlo a mano ni subirlo a git.

- **Backend remoto**: guardar el state en S3 (AWS) o Azure Blob en lugar de en tu ordenador local, para que todo el equipo comparta el mismo estado.

- **Workspaces**: mismo codigo, varios states (dev/staging/prod). Util para experimentos. **No usar en produccion** porque el workspace activo es invisible en el codigo.

- **File layout**: una carpeta por entorno. La separacion es fisica: si estas en `stage/` es imposible tocar `prod/` por accidente. **Este es el patron correcto para produccion.**

```
prod/webserver/   → su propio state, sus propias credenciales
stage/webserver/  → su propio state, sus propias credenciales
```

---

## Capitulo 4 — Modulos (infraestructura reutilizable)

**Lo crucial**: no copiar y pegar codigo entre entornos.

Un modulo es una **carpeta con `.tf` que funciona como una funcion**: la defines una vez y la llamas con distintos parametros.

```hcl
# Mismo modulo, dos entornos distintos
module "webserver_stage" {
  source        = "../modules/webserver-cluster"
  instance_type = "t3.micro"   # barato
  min_size      = 1
}

module "webserver_prod" {
  source        = "../modules/webserver-cluster"
  instance_type = "t3.small"   # mas potente
  min_size      = 2            # alta disponibilidad
}
```

| Elemento del modulo | Equivalente en programacion |
|--------------------|-----------------------------|
| `variable` | argumentos de la funcion |
| `locals` | variables internas (no accesibles desde fuera) |
| `output` | valor de retorno (`return`) |

**Gotcha importante**: usar `${path.module}/fichero` para referenciar ficheros dentro del modulo, no rutas relativas simples.

**Versionado**: en produccion siempre fijar la version del modulo (`version = "3.14.0"`), nunca usar `latest`.
