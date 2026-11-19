terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }
}

locals {
  name_prefix = "acs730-${var.environment}"

  # Same in all three environments, so a local, not an input.
  instance_profile = "LabInstanceProfile"

  # Created once by hand with aws ssm put-parameter (see REPORT.md).
  # Terraform only reads it; nothing here creates it.
  db_password_parameter = "/acs730/assignment1/${var.environment}/db-password"

  common_tags = merge(
    {
      Project     = "acs730"
      Environment = var.environment
      ManagedBy   = "terraform"
    },
    var.extra_tags
  )
}

# The AL2023 AMI id changes whenever Amazon rebuilds the image.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Task 6: application secret read from Parameter Store, not hardcoded.
data "aws_ssm_parameter" "db_password" {
  name            = local.db_password_parameter
  with_decryption = true
}

resource "aws_security_group" "web" {
  name        = "${local.name_prefix}-web-sg"
  description = "ACS730 A1 ${var.environment} web servers - port 80 in, no port 22"

  # No port 22 rule. Access is through Session Manager.
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.http_ingress_cidrs
  }

  # Outbound must stay open: the SSM agent connects out on 443.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-web-sg" })
}

# for_each over names instead of count: each instance is addressed by
# its name (web["web-1"]), not its position (web[0]). Removing one name
# destroys only that instance; with count, removing index 0 would shift
# every later instance and Terraform would replace them.
resource "aws_instance" "web" {
  for_each = var.instance_names

  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = local.instance_profile

  # The application reads its DB password from a root-only file.
  # The value comes from Parameter Store and is marked sensitive,
  # so it never appears in plan output or pipeline logs.
  user_data = <<-EOF
    #!/bin/bash
    mkdir -p /etc/acs730
    cat > /etc/acs730/app.env <<'ENV'
    DB_PASSWORD=${data.aws_ssm_parameter.db_password.value}
    ENV
    chmod 600 /etc/acs730/app.env
  EOF

  # A new AMI release should not replace running servers between
  # the staging apply and the prod apply.
  lifecycle {
    ignore_changes = [ami]
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-${each.key}"
    Role = "web"
  })
}

# Task 7: CPU is reported even when the instance is idle, so the alarm
# reaches OK instead of staying in INSUFFICIENT_DATA.
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  for_each = aws_instance.web

  alarm_name        = "${local.name_prefix}-${each.key}-cpu-high"
  alarm_description = "Average CPU above 80% for two 5-minute periods on ${local.name_prefix}-${each.key}"

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"
  dimensions = {
    InstanceId = each.value.id
  }

  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "missing"

  tags = merge(local.common_tags, { Name = "${local.name_prefix}-${each.key}-cpu-high" })
}
