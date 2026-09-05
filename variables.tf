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

variable "monitoring_access_log_prefix" {
  description = "S3 prefix used for Application Load Balancer access logs."
  type        = string
  default     = "access-logs"
}

variable "monitoring_log_retention_days" {
  description = "Number of days to retain Application Load Balancer access logs."
  type        = number
  default     = 14

  validation {
    condition     = var.monitoring_log_retention_days >= 1
    error_message = "monitoring_log_retention_days must be at least 1."
  }
}

variable "monitoring_target_period_seconds" {
  description = "CloudWatch evaluation period for target health alarms."
  type        = number
  default     = 60
}

variable "monitoring_target_evaluation_periods" {
  description = "Consecutive target health periods required to enter ALARM."
  type        = number
  default     = 2
}

variable "monitoring_5xx_period_seconds" {
  description = "CloudWatch evaluation period for the combined HTTP 5xx alarm."
  type        = number
  default     = 300
}

variable "monitoring_5xx_threshold" {
  description = "Combined ALB and target HTTP 5xx count that enters ALARM."
  type        = number
  default     = 5
}

variable "monitoring_cpu_period_seconds" {
  description = "CloudWatch evaluation period for EC2 CPU alarms."
  type        = number
  default     = 300
}

variable "monitoring_cpu_evaluation_periods" {
  description = "Consecutive CPU periods required to enter ALARM."
  type        = number
  default     = 3
}

variable "monitoring_cpu_threshold" {
  description = "Average EC2 CPU utilization percentage that enters ALARM."
  type        = number
  default     = 80
}

variable "monitoring_status_check_period_seconds" {
  description = "CloudWatch evaluation period for EC2 status check alarms."
  type        = number
  default     = 60
}

variable "monitoring_status_check_evaluation_periods" {
  description = "Consecutive failed or missing EC2 status check periods required to enter ALARM."
  type        = number
  default     = 2
}
