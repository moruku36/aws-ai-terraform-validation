# AWS AI Terraform Validation

[English](README.md) | [日本語](README.ja.md)

A disposable AWS lab evaluating AI-assisted infrastructure delivery from construction through CI/CD, OIDC, remote state, monitoring, fault tests, and cleanup. The documented AWS test environment has been deleted.

## Validation scope

The recorded experiment built a Tokyo-region VPC, public/private subnets, an ALB, and private EC2 backends; verified HTTP 200; and exercised GitHub Actions with OIDC temporary credentials, S3 remote state and native lockfiles, CloudWatch alarms, ALB access logs, and backend failure/recovery.

The final cleanup removed the root and bootstrap resources, remote state, OIDC provider, and temporary IAM resources. The documented test environment is deleted.

Start with the [multi-cloud final comparison](docs/10-multi-cloud-final-report.md). The repository preserves implementation and evidence, not a running service.


## Contents

- [bootstrap/](bootstrap)
- [docs/](docs)
- [scripts/](scripts)

## Detailed documentation

The [Japanese guide](README.ja.md) retains the complete original setup instructions, configuration, examples, project status, and limitations. Supporting documents keep their existing language.
