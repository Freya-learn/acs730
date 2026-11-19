output "instance_ids" {
  value = module.web.instance_ids
}

output "public_ips" {
  value = module.web.public_ips
}

output "security_group_id" {
  value = module.web.security_group_id
}

output "cpu_alarm_names" {
  value = module.web.cpu_alarm_names
}

output "db_password_parameter" {
  value = module.web.db_password_parameter
}
