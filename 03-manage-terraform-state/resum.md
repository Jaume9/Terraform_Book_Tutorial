# Capitulo 3: Gestion del Estado (State) en Terraform

---

## Los 3 conceptos en una frase cada uno

- **State file**: fichero donde Terraform guarda lo que existe en la nube. Al hacer `plan`, compara tu codigo con este fichero para saber que hay que crear, cambiar o borrar.

- **Workspaces**: despliega el mismo codigo en varios entornos a la vez (dev, staging, prod), cada uno con su propio state file. Es para tener el mismo codigo corriendo en sitios distintos simultaneamente. Se puede usar como si fueran brancas de git o tambien para testear en otro workspace/(rama) si los cambios realizados funcionarian antes de aplicarlo en PROD.

- **File layout**: cada carpeta es un proyecto independiente con su propio state. La separacion es fisica: si estas dentro de `stage/`, es imposible tocar `prod/` por accidente.

---

## El problema que resuelve este capitulo

Hasta ahora trabajabas con **un solo entorno** (una carpeta, un estado). En produccion real necesitas al menos tres: **dev, staging y prod**. La pregunta es: como los organizas?

Terraform ofrece **dos soluciones**:

---

## Solucion 1: Workspaces

Imagina que tienes **un solo `main.tf`** pero varios ficheros de estado guardados por separado.

```
mis-recursos/
├── main.tf          ← un solo codigo
└── estado-dev       ← estado del workspace "dev"
    estado-staging   ← estado del workspace "staging"
    estado-prod      ← estado del workspace "prod"
```

Cambias de entorno con un comando:
```bash
terraform workspace new dev
terraform workspace select prod
```

Dentro del codigo puedes hacer logica condicional:
```hcl
instance_type = terraform.workspace == "prod" ? "t3.large" : "t3.micro"
```

**Problema**: los workspaces son "invisibles". Al mirar el repositorio no sabes en que entorno estas. Es facil equivocarse y destruir prod pensando que estas en dev.

**Uso recomendado**: aprender, experimentar, pruebas temporales. **Nunca en produccion.**

---

## Solucion 2: File Layout (diseno de carpetas)

Cada entorno es **una carpeta distinta** con su propio codigo y estado:

```
infraestructura/
├── global/          ← recursos compartidos (S3, IAM...)
├── stage/
│   ├── data-stores/mysql/      ← base de datos de staging
│   └── services/webserver/     ← servidor web de staging
└── prod/
    ├── data-stores/mysql/      ← base de datos de produccion
    └── services/webserver/     ← servidor web de produccion
```

Para desplegar en staging:
```bash
cd stage/services/webserver
terraform apply     # es imposible tocar prod por accidente
```

**Ventaja clave**: la separacion es visible en git, se pueden usar credenciales distintas por entorno, y se puede dar acceso a developers solo a `stage/` sin que puedan tocar `prod/`.

**Uso recomendado**: siempre en produccion.

---

## Donde se guarda el estado (Backend)

El estado no debe vivir en tu ordenador local. Debe estar en la nube para que todo el equipo comparta el mismo estado y nadie pise el trabajo de otro.

| | AWS | Azure |
|--|-----|-------|
| **Donde se guarda** | S3 Bucket | Storage Account (Blob) |
| **Bloqueo** (evita que 2 personas apliquen a la vez) | DynamoDB (recurso separado) | Incluido en el Blob (nativo) |
| **Coste aprox.** | ~$3-5/mes | ~$1-3/mes |

Azure es mas simple porque el bloqueo viene incluido. En AWS necesitas crear y mantener una tabla DynamoDB extra.

---

## Regla de oro del capitulo

```
¿Es algo temporal / para aprender?  → Workspaces
¿Es algo que importa en produccion? → File Layout
```

---

## Lo que viene en capitulos siguientes

| Problema | Solucion |
|----------|----------|
| Codigo duplicado entre `stage/` y `prod/` | **Capitulo 4**: Modulos |
| Tener que entrar en 10 carpetas para hacer deploy | **Capitulo 10**: Terragrunt |

---

## Conceptos clave en detalle

### State File (`terraform.tfstate`)

Es el **"cerebro"** de Terraform. Un fichero JSON que guarda el estado actual de tu infraestructura: que recursos existen, con que configuracion y que ID tienen en AWS/Azure.

```json
{
  "resource": "aws_instance.example",
  "id": "i-0abc123",
  "ip": "54.23.11.5"
}
```

**Para que sirve**: cuando haces `terraform plan`, Terraform compara el codigo con el state file para saber que hay que crear, modificar o borrar. Sin el, no sabe que existe ya.

**Regla**: nunca editar el state file a mano. Nunca guardarlo en git (puede tener secretos). En produccion, guardarlo en S3 o Azure Blob.

---

### Workspaces

Son **multiples copias del state file** usando el mismo codigo. Como tener varias "ranuras de guardado" en un videojuego.

```bash
terraform workspace new dev      # crea state file para dev
terraform workspace new prod     # crea state file para prod
terraform workspace select dev   # cambia a dev
```

```
S3 bucket/
├── env:/dev/terraform.tfstate
├── env:/staging/terraform.tfstate
└── env:/prod/terraform.tfstate
```

El codigo puede cambiar comportamiento segun el workspace:
```hcl
size = terraform.workspace == "prod" ? "t3.large" : "t3.micro"
```

**Problema gordo**: si olvidas en que workspace estas y ejecutas `terraform destroy`... puedes cargarte prod. El workspace no es visible en el codigo.

---

### File Layout

Es **una carpeta por entorno y por componente**. El aislamiento es fisico: para tocar prod tienes que estar dentro de la carpeta `prod/`.

```
infra/
├── stage/
│   ├── data-stores/mysql/    → su propio state file
│   └── services/webserver/   → su propio state file
└── prod/
    ├── data-stores/mysql/    → su propio state file
    └── services/webserver/   → su propio state file
```

Cada carpeta tiene su propio `terraform init` / `apply` / `destroy`. Es imposible borrar prod por accidente desde la carpeta de stage.

---

### Comparativa resumida

| | State File | Workspaces | File Layout |
|--|-----------|------------|-------------|
| **Que es** | Fichero con el estado actual | Multiples states, un codigo | Multiples carpetas, multiples states |
| **Cuando se usa** | Siempre (es automatico) | Aprender / experimentos | Produccion |
| **Riesgo de error** | — | Alto (workspace invisible) | Bajo (carpeta visible) |
| **Credenciales distintas por entorno** | — | No | Si |

---

## Cuando usar Workspaces: ejemplos practicos

### Caso 1: probar un cambio sin tocar produccion

```bash
# Situacion: tienes prod desplegado y quieres probar un cambio

# 1. Creas un workspace temporal para tu prueba
terraform workspace new mi-prueba

# 2. Haces el cambio en main.tf y lo despliegas SOLO en este workspace
terraform apply
# → crea recursos nuevos, prod no se toca

# 3. Pruebas que funciona

# 4. Cuando terminas, lo borras todo
terraform destroy
terraform workspace delete mi-prueba

# 5. Vuelves a prod intacto
terraform workspace select default
```

En este momento existen **dos states independientes** a la vez:
```
S3 bucket/
├── env:/default/terraform.tfstate   ← prod, sin tocar
└── env:/mi-prueba/terraform.tfstate ← tu experimento
```

### Caso 2: varios desarrolladores trabajando en paralelo

Cada desarrollador crea su propio workspace para no pisarse con los demas:

```bash
# Developer A
terraform workspace new juan-nueva-bd
terraform apply

# Developer B (al mismo tiempo)
terraform workspace new maria-nuevo-lb
terraform apply
```

### Cuando NO usar workspaces (usar file layout en su lugar)

- Cuando dev/staging/prod tienen **credenciales distintas**
- Cuando **distintas personas** deben tener acceso a distintos entornos
- Cuando es infraestructura de produccion real con datos importantes
