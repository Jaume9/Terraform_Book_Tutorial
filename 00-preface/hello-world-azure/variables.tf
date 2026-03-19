# Variables para la autenticación con Azure - Example format for reference
variable "azure_client_id" {
  description = "Azure Service Principal Client ID"
  type        = string
  sensitive   = true
}

variable "azure_client_secret" {
  description = "Azure Service Principal Client Secret"
  type        = string
  sensitive   = true
}

variable "azure_subscription_id" {
  description = "Azure Subscription ID"
  type        = string
  sensitive   = true
}

variable "azure_tenant_id" {
  description = "Azure Tenant ID"
  type        = string
  sensitive   = true
}

# Tu cuenta Microsoft
# └── Tenant (tu organización) ← azure_tenant_id
#     └── Suscripción (facturación) ← azure_subscription_id
#         └── Service Principal (usuario robot para Terraform)
#             ├── Client ID ← azure_client_id
#             └── Client Secret ← azure_client_secret (contraseña)