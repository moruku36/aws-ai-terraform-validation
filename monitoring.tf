locals {
  monitoring_access_logs_bucket_name = lower("${local.name_prefix}-alb-logs-${data.aws_caller_identity.current.account_id}")
}

resource "aws_s3_bucket" "alb_access_logs" {
  bucket        = local.monitoring_access_logs_bucket_name
  force_destroy = true

  tags = {
    Name = "${local.name_prefix}-alb-access-logs"
  }
}

resource "aws_s3_bucket_public_access_block" "alb_access_logs" {
  bucket                  = aws_s3_bucket.alb_access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "alb_access_logs" {
  bucket = aws_s3_bucket.alb_access_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_access_logs" {
  bucket = aws_s3_bucket.alb_access_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_access_logs" {
  bucket = aws_s3_bucket.alb_access_logs.id

  rule {
    id     = "expire-access-logs"
    status = "Enabled"

    filter {
      prefix = var.monitoring_access_log_prefix
    }

    expiration {
      days = var.monitoring_log_retention_days
    }
  }
}

data "aws_iam_policy_document" "alb_access_logs" {
  statement {
    sid    = "AllowALBAccessLogDelivery"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }

    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.alb_access_logs.arn}/${var.monitoring_access_log_prefix}/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:*"]
    resources = [aws_s3_bucket.alb_access_logs.arn, "${aws_s3_bucket.alb_access_logs.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "alb_access_logs" {
  bucket = aws_s3_bucket.alb_access_logs.id
  policy = data.aws_iam_policy_document.alb_access_logs.json
}

resource "aws_cloudwatch_metric_alarm" "web_unavailable" {
  alarm_name          = "${local.name_prefix}-web-unavailable"
  alarm_description   = "No healthy targets are available behind the Application Load Balancer."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.monitoring_target_evaluation_periods
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = var.monitoring_target_period_seconds
  statistic           = "Minimum"
  threshold           = 1
  treat_missing_data  = "missing"

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.web.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "backend_unhealthy" {
  alarm_name          = "${local.name_prefix}-backend-unhealthy"
  alarm_description   = "At least one target behind the Application Load Balancer is unhealthy."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.monitoring_target_evaluation_periods
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = var.monitoring_target_period_seconds
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "missing"

  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.web.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "http_5xx" {
  alarm_name          = "${local.name_prefix}-http-5xx"
  alarm_description   = "Combined Application Load Balancer and target HTTP 5xx errors exceeded the threshold."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = var.monitoring_5xx_threshold
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "target_5xx"
    return_data = false

    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = var.monitoring_5xx_period_seconds
      stat        = "Sum"

      dimensions = {
        LoadBalancer = aws_lb.this.arn_suffix
        TargetGroup  = aws_lb_target_group.web.arn_suffix
      }
    }
  }

  metric_query {
    id          = "alb_5xx"
    return_data = false

    metric {
      metric_name = "HTTPCode_ELB_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = var.monitoring_5xx_period_seconds
      stat        = "Sum"

      dimensions = {
        LoadBalancer = aws_lb.this.arn_suffix
      }
    }
  }

  metric_query {
    id          = "combined_5xx"
    expression  = "FILL(target_5xx, 0) + FILL(alb_5xx, 0)"
    label       = "Combined HTTP 5xx"
    return_data = true
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2_cpu_high" {
  for_each = aws_instance.web

  alarm_name          = "${local.name_prefix}-cpu-high-${each.key}"
  alarm_description   = "Average EC2 CPU utilization exceeded the threshold."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.monitoring_cpu_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.monitoring_cpu_period_seconds
  statistic           = "Average"
  threshold           = var.monitoring_cpu_threshold
  treat_missing_data  = "missing"

  dimensions = {
    InstanceId = each.value.id
  }
}

resource "aws_cloudwatch_metric_alarm" "ec2_status_check_failed" {
  for_each = aws_instance.web

  alarm_name          = "${local.name_prefix}-status-check-failed-${each.key}"
  alarm_description   = "EC2 instance or system status checks failed, or the instance stopped reporting status checks."
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = var.monitoring_status_check_evaluation_periods
  metric_name         = "StatusCheckFailed"
  namespace           = "AWS/EC2"
  period              = var.monitoring_status_check_period_seconds
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    InstanceId = each.value.id
  }
}
