variable "aws_region" {
  description = "AWS region in which to create all resources."
  type        = string
  default     = "ap-northeast-1"
}

variable "project_name" {
  description = "Short name used in resource Name tags."
  type        = string
  default     = "ai-terraform-validation"
}

variable "environment" {
  description = "Environment label used in tags."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "availability_zones" {
  description = "Exactly two Tokyo Availability Zones for the public and private subnets."
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"]

  validation {
    condition     = length(var.availability_zones) == 2
    error_message = "Specify exactly two Availability Zones."
  }
}

variable "public_subnet_cidrs" {
  description = "Two CIDR blocks for ALB public subnets."
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Specify exactly two public subnet CIDRs."
  }
}

variable "private_subnet_cidrs" {
  description = "Two CIDR blocks for EC2 private subnets."
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Specify exactly two private subnet CIDRs."
  }
}

variable "instance_type" {
  description = "Small EC2 instance type for this validation environment."
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "Optional Nginx-capable Amazon Linux 2023 AMI ID. Leave null to use the latest AL2023 AMI."
  type        = string
  default     = null
  nullable    = true
}

variable "create_amazonlinux_s3_endpoint" {
  description = "Create a gateway S3 endpoint so AL2023 can install Nginx without a NAT gateway."
  type        = bool
  default     = true
}
