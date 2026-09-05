locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
  subnet_map = {
    for index, az in var.availability_zones :
    az => {
      public_cidr  = var.public_subnet_cidrs[index]
      private_cidr = var.private_subnet_cidrs[index]
    }
  }
  resolved_ami_id = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux_2023[0].id
}

data "aws_ami" "amazon_linux_2023" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["137112412989"] # Amazon

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-6.1-x86_64"]
  }
}

data "aws_prefix_list" "s3" {
  name = "com.amazonaws.${var.aws_region}.s3"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "${local.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${local.name_prefix}-igw" }
}

resource "aws_subnet" "public" {
  for_each                = local.subnet_map
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value.public_cidr
  map_public_ip_on_launch = false

  tags = { Name = "${local.name_prefix}-public-${each.key}" }
}

resource "aws_subnet" "private" {
  for_each                = local.subnet_map
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value.private_cidr
  map_public_ip_on_launch = false

  tags = { Name = "${local.name_prefix}-private-${each.key}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = { Name = "${local.name_prefix}-private-rt" }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Allows public HTTP only to the Application Load Balancer."
  vpc_id      = aws_vpc.this.id

  tags = { Name = "${local.name_prefix}-alb-sg" }
}

resource "aws_security_group" "ec2" {
  name        = "${local.name_prefix}-ec2-sg"
  description = "Allows HTTP only from the Application Load Balancer."
  vpc_id      = aws_vpc.this.id

  tags = { Name = "${local.name_prefix}-ec2-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_to_ec2_http" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.ec2.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
}

resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb_http" {
  security_group_id            = aws_security_group.ec2.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
}

resource "aws_vpc_security_group_egress_rule" "ec2_to_s3_https" {
  security_group_id = aws_security_group.ec2.id
  prefix_list_id    = data.aws_prefix_list.s3.id
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_endpoint" "amazonlinux_repositories" {
  count             = var.create_amazonlinux_s3_endpoint ? 1 : 0
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = ["s3:GetObject"]
      Resource  = "arn:aws:s3:::al2023-repos-${var.aws_region}-de612dc2/*"
    }]
  })

  tags = { Name = "${local.name_prefix}-amazonlinux-repositories-s3-endpoint" }
}

resource "aws_lb" "this" {
  name               = trim(substr(replace("${local.name_prefix}-alb", "_", "-"), 0, 32), "-")
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = values(aws_subnet.public)[*].id

  tags = {
    Name               = "${local.name_prefix}-alb"
    ValidationScenario = "cicd-real-apply"
  }
}

resource "aws_lb_target_group" "web" {
  name        = trim(substr(replace("${local.name_prefix}-web-tg", "_", "-"), 0, 32), "-")
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.this.id

  health_check {
    enabled  = true
    path     = "/"
    protocol = "HTTP"
    matcher  = "200"
  }

  tags = { Name = "${local.name_prefix}-web-tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_instance" "web" {
  for_each                    = aws_subnet.private
  ami                         = local.resolved_ami_id
  instance_type               = var.instance_type
  subnet_id                   = each.value.id
  vpc_security_group_ids      = [aws_security_group.ec2.id]
  associate_public_ip_address = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    # Package download is restricted to the S3 gateway endpoint on TCP 443.
    dnf install -y nginx
    cat > /usr/share/nginx/html/index.html <<HTML
    <!doctype html><html><body><h1>${local.name_prefix}</h1><p>Served by $(hostname -f)</p></body></html>
    HTML
    systemctl enable --now nginx
  EOF

  depends_on = [aws_vpc_endpoint.amazonlinux_repositories]

  tags = { Name = "${local.name_prefix}-web-${each.key}" }
}

resource "aws_lb_target_group_attachment" "web" {
  for_each         = aws_instance.web
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = each.value.id
  port             = 80
}
