variable "environment" {
  description = "Environment name, used in resource names and tags."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging or prod."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the web servers."
  type        = string

  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "instance_type must be t3.micro or t3.small (budget limit)."
  }
}

variable "instance_names" {
  description = "Names of the web servers to create. One instance per name."
  type        = set(string)

  validation {
    condition     = length(var.instance_names) >= 1 && length(var.instance_names) <= 3
    error_message = "instance_names must contain between 1 and 3 names."
  }
}

variable "http_ingress_cidrs" {
  description = "CIDR blocks allowed to reach port 80."
  type        = list(string)

  validation {
    condition     = alltrue([for c in var.http_ingress_cidrs : can(cidrnetmask(c))])
    error_message = "Every entry must be a valid IPv4 CIDR, e.g. 0.0.0.0/0."
  }
}

variable "extra_tags" {
  description = "Additional tags merged into every resource."
  type        = map(string)
  default     = {}
}
