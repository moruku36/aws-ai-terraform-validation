variable "aws_region" {
  description = "Region for the Terraform backend and GitHub Actions IAM role."
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Name prefix for bootstrap resources."
  type        = string
  default     = "ai-terraform-validation"
}

variable "state_bucket_name" {
  description = "Globally unique, DNS-compatible S3 bucket name for Terraform state."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a DNS-compatible S3 bucket name between 3 and 63 characters."
  }
}

variable "state_key" {
  description = "Exact S3 object key used for the application Terraform state."
  type        = string
  default     = "terraform/aws-validation.tfstate"
}

variable "github_repository" {
  description = "Exact GitHub repository allowed to assume the CI role, for example owner/repository."
  type        = string

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must have the format owner/repository."
  }
}

variable "github_branch" {
  description = "Protected branch permitted to apply Terraform."
  type        = string
  default     = "main"
}

variable "github_actions_role_name" {
  description = "IAM role name assumed by GitHub Actions through OIDC."
  type        = string
  default     = "ai-terraform-validation-github-actions"
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN. Set this when the AWS account already has one."
  type        = string
  default     = null
  nullable    = true
}
