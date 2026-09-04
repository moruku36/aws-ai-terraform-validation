[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$StateBucket,

  [Parameter(Mandatory = $false)]
  [string]$StateKey = "terraform/aws-validation.tfstate",

  [Parameter(Mandatory = $false)]
  [string]$Region = "ap-northeast-1"
)

$ErrorActionPreference = "Stop"

$backupPath = "terraform.tfstate.pre-remote-migration.backup"
if (-not (Test-Path -LiteralPath "terraform.tfstate")) {
  throw "terraform.tfstate was not found. Run this script from the current Terraform root before migration."
}

if (Test-Path -LiteralPath $backupPath) {
  throw "$backupPath already exists. Review or move it before retrying so an existing backup is never overwritten."
}

Copy-Item -LiteralPath "terraform.tfstate" -Destination $backupPath

if (-not (Test-Path -LiteralPath "backend.tf")) {
  Copy-Item -LiteralPath "backend.tf.example" -Destination "backend.tf"
}

terraform init -migrate-state -input=false `
  -backend-config="bucket=$StateBucket" `
  -backend-config="key=$StateKey" `
  -backend-config="region=$Region" `
  -backend-config="encrypt=true"

terraform plan -input=false -lock-timeout=5m -detailed-exitcode
$planExitCode = $LASTEXITCODE

if ($planExitCode -eq 0) {
  Write-Host "Remote state migration completed and Terraform reports No changes."
  exit 0
}

if ($planExitCode -eq 2) {
  Write-Error "Remote state migration completed, but Terraform found changes. Review the plan; no apply was run."
  exit 2
}

exit $planExitCode
