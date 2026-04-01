# Architecture — Zero-Downtime Deployment

This document contains diagrams that illustrate the zero-downtime deployment
strategies implemented in this example repository.

## Blue-Green replacement (create_before_destroy)

```mermaid
sequenceDiagram
  participant User
  participant ALB
  participant ASG_V1 as ASG v1
  participant ASG_V2 as ASG v2

  Note over ASG_V1: v1 running
  User->>ALB: Request
  ALB->>ASG_V1: Forward

  Note over ASG_V2: Terraform creates v2
  ASG_V2->>ALB: Register instances
  ALB-->>ASG_V2: Health checks pass

  alt min_elb_capacity reached
    Terraform->>ASG_V1: Deregister instances
    ASG_V1->>ASG_V1: Terminate instances
  end

  Note over ASG_V2: v2 serves all traffic

```

## Instance Refresh (in-place rolling)

```mermaid
flowchart LR
  User --> ALB
  ALB --> ASG[ASG (instance_refresh)]
  subgraph Refresh
    ASG --> Batch1
    ASG --> Batch2
    ASG --> Batch3
  end
  Batch1 --> ALB
  Batch2 --> ALB
  Batch3 --> ALB
```

## Notes

- `min_elb_capacity` ensures Terraform waits until a minimum number of
  instances in the new ASG are healthy before deleting the old ASG.
- `instance_refresh` performs the replacement inside the same ASG and is
  controlled using `min_healthy_percentage`.
