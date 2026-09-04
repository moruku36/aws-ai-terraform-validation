output "alb_url" {
  description = "Public HTTP URL of the Application Load Balancer."
  value       = "http://${aws_lb.this.dns_name}"
}

output "instance_ids" {
  description = "IDs of the two private web instances."
  value       = { for az, instance in aws_instance.web : az => instance.id }
}

output "vpc_id" {
  description = "ID of the validation VPC."
  value       = aws_vpc.this.id
}
