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
