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

---

## Capitulo 5 — Tips & Tricks (loops, condicionales, zero-downtime)

**Lo crucial**: Terraform no es un lenguaje de programacion completo, pero tiene herramientas para evitar repeticion y gestionar deployments sin downtime.

### Loops

| Herramienta | Para que sirve | Cuando usarla |
|-------------|---------------|---------------|
| `count` | Crear N copias de un recurso | Numero fijo, recursos identicos |
| `for_each` | Crear recursos por nombre/clave | Recursos con identidad propia (recomendado sobre `count`) |
| `for` expression | Transformar listas/maps en expressions | Outputs, locals, valores dinamicos |
| `dynamic` block | Repetir bloques anidados dentro de un recurso | `ingress`, `tag`, `setting`... |
| `%{ for }` string directive | Loop dentro de un string heredoc | Generar configs de texto dinamicamente |

**Por que `for_each` es mejor que `count`**: `count` identifica recursos por indice numerico. Si borras un elemento del medio de la lista, Terraform recrea todos los posteriores. `for_each` identifica por clave — borrar un elemento solo destruye ese recurso.

```hcl
# count → recurso es aws_iam_user.example[0], [1], [2]  (fragil)
# for_each → recurso es aws_iam_user.example["alice"]   (robusto)
resource "aws_iam_user" "example" {
  for_each = toset(["alice", "bob", "carol"])
  name     = each.value
}
```

### Condicionales

Terraform no tiene `if/else` directo. Los patrones equivalentes son:

```hcl
# Crear/no crear un recurso
count = var.enable_feature ? 1 : 0

# Valor distinto segun condicion
instance_type = var.environment == "prod" ? "t3.large" : "t3.micro"

# Filtrar que recursos crear con for_each
for_each = { for k, v in var.users : k => v if v.enabled }

# Condicional dentro de un string (heredoc)
# %{ if condition }...%{ else }...%{ endif }
```

**`one()`**: funcion para acceder de forma segura a un recurso condicional (cuando `count` puede ser 0):
```hcl
output "ip" {
  value = one(aws_instance.example[*].public_ip)  # null si count=0
}
```

### Zero-Downtime Deployment

El problema: cuando Terraform reemplaza un recurso, por defecto destruye primero y crea despues → downtime.

**Solucion 1 — `create_before_destroy`**: invierte el orden (crea primero, destruye despues). Requiere `name_prefix` en lugar de `name` para evitar conflictos de nombre unico.

**Solucion 2 — Rolling deployment con ASG**: el parametro clave es `min_elb_capacity`. Le dice a Terraform: *"no destruyas las instancias viejas hasta que al menos N instancias nuevas esten healthy en el Load Balancer"*. En ningun momento hay cero instancias activas.

**Solucion 3 — Blue/Green deployment**: dos entornos completos (blue = activo, green = nuevo). Terraform crea green, cambia el DNS, destruye blue. Rollback instantaneo cambiando una variable.

| Solucion | Downtime | Rollback | Complejidad |
|----------|----------|----------|-------------|
| `create_before_destroy` | Minimo | No aplica | Baja |
| Rolling (ASG) | Cero | Dificil | Media |
| Blue/Green | Cero | Instantaneo (cambiar variable) | Alta |

> **En Azure**: el equivalente del ASG rolling es VMSS con `rolling_upgrade_policy`, o AKS con `upgrade_settings.max_surge` en los node pools.

---

## Capitulo 6 — Gestion de Secretos (Managing Secrets)

**Lo crucial**: nunca meter secretos (passwords, API keys, tokens) en el codigo ni en el state en texto plano. Hay tres niveles de problema: secretos del proveedor (quien lanza Terraform), secretos de los recursos (passwords de BD), y datos sensibles en el state.

### El problema fundamental

```
❌ MAL — secreto en el codigo:
variable "db_password" { default = "mi-password-secreto" }

✅ BIEN — secreto viene de fuera del codigo:
variable "db_password" { sensitive = true }   # sin default, se pasa por env var o secret store
```

Todo lo que pones en `default` de una variable acaba en git. Todo lo que pasa por Terraform acaba en el state (aunque uses `sensitive = true`, el valor sigue en el `.tfstate`). Por eso hay que:
1. No meter secretos en el codigo
2. Encriptar y restringir acceso al state

---

### 3 metodos para pasar secretos a Terraform

| Metodo | Como funciona | Pros | Contras |
|--------|--------------|------|---------|
| **Variables de entorno** | `export TF_VAR_db_password="..."` antes del `plan` | Simple, sin dependencias | Manual, no escala en equipo |
| **Ficheros cifrados** (KMS) | Fichero `.yml` cifrado con AWS KMS/Azure Key Vault, se descifra on-the-fly | Versionable, auditable | Requiere acceso a KMS |
| **Secret stores** | AWS Secrets Manager / Azure Key Vault — Terraform lo lee con `data` | Rotacion automatica, audit logs, estandar de equipo | Coste (~$0.40/secreto/mes en AWS) |

**El metodo recomendado para equipos es el secret store.** Es el unico que tiene rotacion automatica, audit logs y control de acceso centralizado.

---

### Patron con AWS Secrets Manager

```hcl
# 1. Ley el secreto del store (guardado previamente como JSON)
data "aws_secretsmanager_secret_version" "creds" {
  secret_id = "db-creds"   # nombre del secreto en Secrets Manager
}

# 2. Parsea el JSON
locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.creds.secret_string)
}

# 3. Usa los valores
resource "aws_db_instance" "example" {
  username = local.db_creds.username
  password = local.db_creds.password
}
```

**En Azure el equivalente** es `data "azurerm_key_vault_secret"` con Azure Key Vault. En `iac-azure` los secretos van siempre a Key Vault — el modulo `key-vault-certificate` y `key-vault` gestionan esto.

---

### KMS — Cifrado de ficheros con clave gestionada

Para cuando quieres versionar secretos en git cifrados (no en un secret store), usas KMS:

```hcl
# Crear la clave maestra (CMK)
resource "aws_kms_key" "cmk" {
  deletion_window_in_days = 7
  policy = data.aws_iam_policy_document.cmk_admin_policy.json
}

resource "aws_kms_alias" "cmk" {
  name          = "alias/mis-secretos"
  target_key_id = aws_kms_key.cmk.id
}
```

Luego se cifra el fichero con `aws kms encrypt` y Terraform lo descifra on-the-fly con `aws_kms_secrets`. El fichero cifrado se puede subir a git sin riesgo.

**En Azure el equivalente es Azure Key Vault con Customer Managed Keys (CMK).**

---

### IAM Roles para maquinas (evitar credenciales estaticas)

El problema: el CI/CD necesita credenciales para hacer `terraform apply`. La solucion **mala** es guardar `AWS_ACCESS_KEY_ID` en las variables del CI. La solucion **buena** es un IAM Role o OIDC.

**IAM Role para EC2** — la instancia asume el rol automaticamente, sin claves hardcodeadas:

```hcl
resource "aws_iam_role" "ci_runner" {
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_instance_profile" "ci_runner" {
  role = aws_iam_role.ci_runner.name
}

resource "aws_instance" "ci" {
  iam_instance_profile = aws_iam_instance_profile.ci_runner.name
}
```

**OIDC para GitHub Actions** — GitHub obtiene un token JWT firmado y lo intercambia por credenciales temporales de AWS/Azure. Sin credenciales estaticas en ningún lado:

```yaml
# GitHub Actions workflow
permissions:
  id-token: write   # necesario para OIDC

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789012:role/github-terraform
      aws-region: us-east-2
  # A partir de aqui, todas las llamadas de AWS usan credenciales temporales
```

**Tabla comparativa de opciones para maquinas:**

| | Credenciales estaticas | IAM Role | OIDC |
|---|---|---|---|
| Evita gestion manual | ✗ | ✓ | ✓ |
| Credenciales temporales | ✗ | ✓ | ✓ |
| Funciona dentro del cloud | ✗ | ✓ | ✗ |
| Funciona fuera del cloud (CI externo) | ✓ | ✗ | ✓ |

> **En Azure**: el equivalente de IAM Role es **Managed Identity**. El equivalente de OIDC para GitHub Actions es la **Federated Identity Credential** — exactamente el modulo `federated-identity-credential` de `iac-azure-modules`.
