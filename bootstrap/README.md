# Terraform backend bootstrap

This independent stack creates the remote-state bucket and GitHub Actions OIDC role. The application backend uses Terraform's S3-native lockfile. It intentionally has its own local state: do not configure the application backend here.

## First-time setup

1. Copy `terraform.tfvars.example` to `terraform.tfvars`.
2. Set a globally unique `state_bucket_name` and the exact `github_repository` value in `owner/repository` form.
3. If the AWS account already has a GitHub Actions OIDC provider, set its ARN as `github_oidc_provider_arn`; otherwise this stack creates one.
4. Review the bootstrap plan and apply it from an authenticated administrator session.

```powershell
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Use the three outputs to configure repository-level GitHub Actions variables. Do not store any AWS access keys in GitHub Secrets.
