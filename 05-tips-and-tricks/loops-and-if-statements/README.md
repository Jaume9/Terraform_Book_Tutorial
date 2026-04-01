# Terraform Tips: Loops, Conditionals, Zero-Downtime & Gotchas (AWS & Azure)

This README explains the patterns and trade-offs used in the
`loops-and-if-statements` examples. It covers:

- How Terraform implements loops and conditional logic (count, for_each,
  for-expressions, conditional expressions)
- Zero-downtime deployment strategies used in the examples
- Common Terraform gotchas and platform-specific notes for AWS and Azure
- Quick commands, debugging tips and best practices

Target audience: people who are learning how to model infrastructure with
Terraform and how to use loops/conditionals safely in production.

Contents in this folder
- `modules/` : small, focused modules demonstrating `for`, `for_each`, and
  simple patterns (e.g., multiple EC2 instances, IAM users)
- `live/` : wrapper examples (global, stage, prod) that consume the modules

1. Loops in Terraform
---------------------

Terraform provides several constructs for repetition. Choose the right
tool for the job:

- `count` — creates N copies of a resource. Use numeric index access
  (`resource.name[count.index]`). Good for identical, small sets.
- `for_each` — iterate over sets, lists or maps to create resources keyed
  by the element (or map key). Use when you want stable identity across
  runs (keys remain stable even if order changes).
- `for` expressions (in locals/variables) — produce lists or maps from
  other collections; useful for transforming data.

When to use each
- Use `count` if you need N identical instances and order/indexing is
  fine. Be careful: removing an item from the middle shifts indexes and
  may cause replacements.
- Use `for_each` if you have unique keys for each item (recommended for
  sets of named resources). `for_each` is usually safer for long-lived
  infra because keys remain stable.

Example: `for_each` creating multiple IAM users

```hcl
variable "users" {
  type = map(string)
  default = {
    alice = "Alice Smith"
    bob   = "Bob Jones"
  }
}

resource "aws_iam_user" "users" {
  for_each = var.users
  name     = each.key
}
```

Example: `for` expression to transform a map to a list

```hcl
locals {
  names = [for k, v in var.users : k]
}
```

2. Conditionals (if / ternary)
------------------------------

Terraform's conditional expression syntax is `condition ? true_val : false_val`.
There is also the `if` expression inside `for` expressions to filter items:

```hcl
variable "create_db" { type = bool }

resource "aws_db_instance" "db" {
  count = var.create_db ? 1 : 0
  # rest of config
}
```

Notes:
- Avoid embedding complex logic in variables — prefer clear variables and
  short locals for transformations.
- Conditionals that choose a resource `count` can cause resource index
  shifts and replacements. Use `for_each` with stable keys when possible.

3. Zero-downtime deployment patterns
-----------------------------------

The examples in this repo show two common strategies to update running
applications without downtime:

a) Blue-Green / Create-Before-Destroy (Terraform-level)

- Use `create_before_destroy` in `lifecycle` for the launch configuration
  and ASG resources. Terraform creates a new ASG (v2), waits for instances
  to become healthy, then deletes the old ASG (v1).
- Use `min_elb_capacity` (ASG) so Terraform waits until the new ASG has a
  minimum number of healthy instances in the ALB before deleting the old
  ASG.

Sequence (high-level):
1. Terraform creates new launch configuration + new ASG (v2).
2. v2 instances boot, run `user-data`, and register with the ALB.
3. When at least `min_elb_capacity` instances in v2 pass health checks,
   Terraform deregisters v1 instances and then destroys v1 ASG.

Pros: simple to reason about in Terraform; avoids downtime when configured
properly. Cons: double-running resources while v2 warms up (temporary
capacity increase).

b) In-place Rolling Updates (AWS `instance_refresh`)

- Use ASG's `instance_refresh` with `min_healthy_percentage` to let AWS
  replace instances in small batches while ensuring a minimum healthy
  capacity.
- Terraform triggers the instance refresh; AWS performs the actual
  replacement.

Pros: no parallel ASG; controlled rolling updates. Cons: less control in
Terraform about the exact timing; relies on AWS features.

Observability demo (curl loop)

To observe zero-downtime in action, the examples use a `server_text`
variable in the instance user-data that prints a small HTML page. Change
the `server_text` value in a wrapper and `terraform apply` while running a
curl loop in another terminal:

```bash
while true; do curl -s http://<load_balancer_url>/ | sed -n 's/.*<h1>\(.*\)<\/h1>.*/\1/p'; sleep 1; done
```

You should see the text alternate between old/new values while both
versions are registered; eventually only the new value remains.

4. Terraform gotchas — general and platform notes (AWS & Azure)
--------------------------------------------------------------

General Terraform gotchas
- Provider pinning: always pin provider versions in `required_providers`.
  Unexpected provider upgrades can change resource behavior.
- Implicit vs explicit dependencies: Terraform infers many dependencies,
  but sometimes you need `depends_on` to control ordering for non-obvious
  cases (e.g., when a side-effect is needed before a resource creation).
- `create_before_destroy` pitfalls: it's powerful but temporarily doubles
  resource count; be careful with quotas and limits.
- State management: use remote state (S3 + DynamoDB for locking) in teams
  to avoid state corruption and concurrent runs.
- `count` index shifts: removing an item from the middle of a list shifts
  indexes; prefer `for_each` with stable keys for long-lived resources.
- Interpolation and expression changes: prefer the modern HCL2 style.

AWS-specific gotchas
- AMI and region differences: AMIs are region-specific. Use `data "aws_ami"`
  lookups or pass AMI IDs via variables.
- Availability Zones (AZs): when using `default` VPC/subnets for examples,
  be mindful of AZ distribution. ASGs spread across subnets — ensure
  you have enough capacity in each AZ.
- Long file path / git clone errors on Windows: Terraform clones git module
  sources into `.terraform/modules/...` which can create very long paths.
  Fixes: move repo to a shorter path, enable `git config --global core.longpaths true`,
  or use local paths during development.
- IAM eventual consistency: changes to IAM policy or roles can take a few
  seconds to propagate. If a resource immediately needs a newly created
  role, add a short wait or retry logic outside Terraform.
- State locking: prefer S3 + DynamoDB lock table to avoid concurrent
  runs overwriting state.

Azure-specific gotchas
- Authentication tokens expire: when using Azure CLI auth, sessions may
  expire and cause provider authentication errors during long CI jobs.
- Provider aliases and multiple subscriptions: use provider `alias` and
  explicit provider configurations when targeting multiple subscriptions
  or tenants.
- Resource group and location: ensure you consistently pass `location` and
  `resource_group` to resources rather than relying on defaults.
- Network security order: creating NICs, subnets and NSGs requires the
  right ordering; sometimes `depends_on` is required to avoid race
  conditions.

5. Best practices & checklist
-----------------------------

- Pin provider versions in `required_providers`.
- Use remote state with locking for team workflows.
- Prefer `for_each` over `count` for resources that require stable
  identity.
- Use `create_before_destroy` intentionally — document capacity impact.
- Write small wrapper `tfvars` files for stage/prod to reduce manual flags.
- Validate and format code before committing:

```bash
terraform fmt -recursive
terraform validate
```

- Use CI pipelines with `terraform init -backend-config=...` and a plan
  approval step before `apply`.

6. Quick commands (PowerShell examples)

```powershell
# Initialize with backend config (if using partial backend config)
terraform init -reconfigure -backend-config=../backend.hcl

# Format and validate
terraform fmt -recursive
terraform validate

# Plan & apply (example for stage wrapper)
cd live\stage\services\webserver-cluster
terraform init
terraform plan -out plan.stage
terraform apply 'plan.stage'

# Destroy (careful in production!)
terraform destroy -auto-approve
```

7. Where to look in this repo

- Blue-green / create-before-destroy examples: see
  `zero-downtime-deployment/modules/services/webserver-cluster` (also in
  this repo's earlier chapter).
- Loops & conditionals examples in this folder:
  - `modules/landing-zone/iam-user` (module demonstrating `count`/`for_each` patterns)
  - `live/global/*` wrappers showing `for-expressions` and `module` usage

If you want, I can:
- Add inline comments to all Terraform files in this folder explaining each
  block and why it's written that way.
- Create `example.tfvars` for `stage` and `prod` to make running the
  examples easier.
- Run `terraform fmt` and `terraform validate` across the folder.

Tell me which follow-up you want and I'll implement it next.
