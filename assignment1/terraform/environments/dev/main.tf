terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  backend "s3" {
    bucket       = "acs730-tfstate-731254789382"
    key          = "assignment1/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "us-east-1"
}

module "web" {
  source = "../../modules/web"

  environment        = "dev"
  instance_type      = "t3.micro"
  instance_names     = ["web-1"]
  http_ingress_cidrs = ["0.0.0.0/0"]
}
