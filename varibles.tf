variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}
variable "nextauth_secret" {
  description = "NextAuth secret used to encrypt session JWTs"
  type        = string
  sensitive   = true
}

variable "azure_client_id" {}
variable "azure_client_secret" {}
variable "azure_tenant_id" {}
