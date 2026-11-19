output "instance_ids" {
  description = "Map of instance name to instance id."
  value       = { for name, inst in aws_instance.web : name => inst.id }
}

output "public_ips" {
  description = "Map of instance name to public IP."
  value       = { for name, inst in aws_instance.web : name => inst.public_ip }
}

output "security_group_id" {
  description = "Id of the web security group."
  value       = aws_security_group.web.id
}

output "cpu_alarm_names" {
  description = "Map of instance name to CloudWatch alarm name."
  value       = { for name, alarm in aws_cloudwatch_metric_alarm.cpu_high : name => alarm.alarm_name }
}

output "db_password_parameter" {
  description = "Name (not value) of the SSM parameter the module reads."
  value       = local.db_password_parameter
}
