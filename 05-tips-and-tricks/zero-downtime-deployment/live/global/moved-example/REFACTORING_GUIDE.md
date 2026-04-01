# Refactoring Guide: Example with `moved` Blocks

## Summary

This example demonstrates how to safely refactor Terraform code using `moved` blocks to avoid downtime when renaming resource identifiers.

## The Problem

### Initial Scenario

Imagine you have a security group with the identifier `instance`:

```hcl
resource "aws_security_group" "instance" {
  name = var.security_group_name
}
```

### The Desired Change

You want to rename it to `cluster_instance` for greater clarity:

```hcl
resource "aws_security_group" "cluster_instance" {
  name = var.security_group_name
}
```

### What Would Happen Without `moved` Block?

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant TF as Terraform
    participant State as State File
    participant AWS as AWS Cloud
    
    Note over Dev: Change identifier from<br/>instance → cluster_instance
    
    Dev->>TF: terraform plan
    TF->>State: Compare code vs state
    State->>TF: Detects "instance" disappeared<br/>and "cluster_instance" is new
    TF->>Dev: ⚠️ Plan: DELETE aws_security_group.instance<br/>CREATE aws_security_group.cluster_instance
    
    Dev->>TF: terraform apply
    TF->>AWS: DELETE security group "instance"
    AWS-->>Dev: ❌ Security group deleted
    Note over AWS: Instances lose security<br/>rules
    TF->>AWS: CREATE security group "cluster_instance"
    AWS-->>Dev: ✅ New security group created
    
    Note over Dev,AWS: DOWNTIME during transition
```

**Consequences:**
- ❌ The old security group is deleted first
- ❌ EC2 instances lose their security rules temporarily
- ❌ Network traffic is rejected until the new security group is created
- ❌ Possible service downtime

## The Solution: `moved` Blocks

### Correct Code

```hcl
# New identifier after refactoring
resource "aws_security_group" "cluster_instance" {
  name = var.security_group_name
}

# moved block: tells Terraform the resource was renamed
moved {
  from = aws_security_group.instance
  to   = aws_security_group.cluster_instance
}
```

### What Happens With `moved` Block?

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant TF as Terraform
    participant State as State File
    participant AWS as AWS Cloud
    
    Note over Dev: Change identifier +<br/>add moved block
    
    Dev->>TF: terraform plan
    TF->>State: Detects moved block
    TF->>State: Updates reference:<br/>instance → cluster_instance
    TF->>Dev: ✅ Plan: 0 to add, 0 to change, 0 to destroy<br/># aws_security_group.instance has moved to<br/># aws_security_group.cluster_instance
    
    Dev->>TF: terraform apply
    TF->>State: Only updates state file
    State->>TF: Reference updated
    TF->>AWS: (No changes in AWS)
    AWS-->>Dev: ✅ Security group remains intact
    
    Note over Dev,AWS: NO DOWNTIME
```

**Result:**
- ✅ Terraform automatically updates the state file
- ✅ The security group in AWS remains intact
- ✅ No changes to real infrastructure
- ✅ No downtime

## Visual Comparison

```mermaid
graph TB
    subgraph "Without moved block"
        A1[Identifier change] --> A2[terraform plan]
        A2 --> A3[⚠️ DELETE + CREATE]
        A3 --> A4[terraform apply]
        A4 --> A5[❌ DOWNTIME]
    end
    
    subgraph "With moved block"
        B1[Identifier change] --> B2[Add moved block]
        B2 --> B3[terraform plan]
        B3 --> B4[✅ Only state update]
        B4 --> B5[terraform apply]
        B5 --> B6[✅ No changes in AWS]
    end
    
    style A5 fill:#ff6b6b
    style B6 fill:#51cf66
    style A3 fill:#ffd93d
    style B4 fill:#51cf66
```

## Steps to Refactor Correctly

### Step 1: Initial State

```hcl
resource "aws_security_group" "instance" {
  name = var.security_group_name
}
```

### Step 2: Add New Resource and `moved` Block

```hcl
# New identifier
resource "aws_security_group" "cluster_instance" {
  name = var.security_group_name
}

# moved block to automatically update state
moved {
  from = aws_security_group.instance
  to   = aws_security_group.cluster_instance
}
```

### Step 3: Verify with `terraform plan`

```bash
$ terraform plan

# aws_security_group.instance has moved to
# aws_security_group.cluster_instance
  # aws_security_group.cluster_instance will be updated in-place
  ~ resource "aws_security_group" "cluster_instance" {
      ~ id   = "sg-12345678" -> (known after apply)
        name = "moved-example-security-group"
        tags = {}
        # (8 unchanged attributes hidden)
    }

Plan: 0 to add, 0 to change, 0 to destroy.
```

### Step 4: Apply Changes

```bash
$ terraform apply
```

Terraform will update the state file without making changes in AWS.

### Step 5: (Optional) Remove Old Code

Once the state is updated, you can remove any references to the old identifier if no longer needed.

## Advantages of `moved` Blocks

```mermaid
mindmap
  root((Advantages of<br/>moved blocks))
    Automatic
      No manual commands required
      Runs on every terraform apply
    Documented
      Stays in source code
      Versioned in Git
      Clear change history
    Safe
      Terraform validates the move
      Prevents human errors
      Consistent across teams
    Scalable
      Works with multiple teams
      Each team gets change automatically
      No manual coordination required
```

## Comparison: `moved` vs `terraform state mv`

### Method 1: `moved` Blocks (Recommended)

**Advantages:**
- ✅ Automatic
- ✅ Documented in code
- ✅ Versioned in Git
- ✅ Consistent across teams
- ✅ Validated by Terraform

**Disadvantages:**
- ❌ Requires Terraform >= 1.1

**Example:**
```hcl
moved {
  from = aws_security_group.instance
  to   = aws_security_group.cluster_instance
}
```

### Method 2: `terraform state mv` (Manual)

**Advantages:**
- ✅ Works in older Terraform versions

**Disadvantages:**
- ❌ Requires manual execution
- ❌ Error-prone
- ❌ Not documented in code
- ❌ Each team must run it manually
- ❌ Easy to forget

**Example:**
```bash
terraform state mv \
  aws_security_group.instance \
  aws_security_group.cluster_instance
```

## Common Use Cases

### 1. Rename Resource Identifier

```hcl
# Before
resource "aws_security_group" "instance" { }

# After
resource "aws_security_group" "cluster_instance" { }

moved {
  from = aws_security_group.instance
  to   = aws_security_group.cluster_instance
}
```

### 2. Move Resource to Module

```hcl
# Before: Resource in root
# resource "aws_security_group" "instance" { }

# After: Resource in module
module "cluster" {
  source = "./modules/cluster"
}

moved {
  from = aws_security_group.instance
  to   = module.cluster.aws_security_group.instance
}
```

### 3. Change from `count` to `for_each`

```hcl
# Before
resource "aws_instance" "example" {
  count = 3
  # ...
}

# After
resource "aws_instance" "example" {
  for_each = toset(["instance-1", "instance-2", "instance-3"])
  # ...
}

moved {
  from = aws_instance.example[0]
  to   = aws_instance.example["instance-1"]
}

moved {
  from = aws_instance.example[1]
  to   = aws_instance.example["instance-2"]
}

moved {
  from = aws_instance.example[2]
  to   = aws_instance.example["instance-3"]
}
```

## Safe Refactoring Checklist

```mermaid
flowchart TD
    A[Start refactoring] --> B[1. Make code change]
    B --> C[2. Add moved block]
    C --> D[3. terraform plan]
    D --> E{Plan shows<br/>only move?}
    E -->|Yes| F[✅ Ready for apply]
    E -->|No| G[❌ Review moved block]
    G --> H{Is there DELETE?}
    H -->|Yes| I[⚠️ Verify if intentional]
    H -->|No| J[Review syntax]
    I --> K{Is intentional?}
    K -->|No| C
    K -->|Yes| L[Consider create_before_destroy]
    F --> M[4. terraform apply]
    M --> N[✅ Refactoring complete]
    
    style F fill:#51cf66
    style N fill:#51cf66
    style G fill:#ff6b6b
    style I fill:#ffd93d
```

## Best Practices

1. **Always use `terraform plan` first**
   - Verify the move is correct
   - Confirm no unexpected changes

2. **Document the reason for the change**
   - Add comments explaining why it was renamed
   - Facilitates future maintenance

3. **Keep `moved` blocks temporarily**
   - Don't delete them immediately after the change
   - Allows other teams to update their state

4. **Use Terraform versions >= 1.1**
   - Ensures full support for `moved` blocks

5. **Validate in staging environments first**
   - Test refactoring in staging before production

## Conclusion

`moved` blocks are the modern and recommended way to handle refactoring in Terraform. They provide:

- ✅ Automatic safety
- ✅ Code documentation
- ✅ Consistency across teams
- ✅ Downtime prevention

**Golden rule:** Always add a `moved` block when renaming resource identifiers, modules, or changing `count`/`for_each` structure.
