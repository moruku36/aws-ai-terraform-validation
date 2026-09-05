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

variable "github_oidc_pr_subject" {
  description = "Exact GitHub OIDC sub claim permitted for trusted pull requests."
  type        = string

  validation {
    condition     = can(regex("^repo:[^:]+:pull_request$", var.github_oidc_pr_subject))
    error_message = "github_oidc_pr_subject must be an exact pull_request OIDC subject."
  }
}

variable "github_oidc_environment_subject" {
  description = "Exact GitHub OIDC sub claim permitted for the terraform-production Environment."
  type        = string

  validation {
    condition     = can(regex("^repo:[^:]+:environment:terraform-production$", var.github_oidc_environment_subject))
    error_message = "github_oidc_environment_subject must be an exact terraform-production Environment OIDC subject."
  }
}

variable "environment" {
  description = "Environment name used to scope monitoring resource permissions."
  type        = string
  default     = "dev"
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
