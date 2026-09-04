output "state_bucket_name" {
  description = "Configure this value as the TF_STATE_BUCKET GitHub Actions variable."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_key" {
  description = "Configure this value as the TF_STATE_KEY GitHub Actions variable."
  value       = var.state_key
}

output "github_actions_role_arn" {
  description = "Configure this value as the AWS_TERRAFORM_ROLE_ARN GitHub Actions variable."
  value       = aws_iam_role.github_actions_terraform.arn
}
