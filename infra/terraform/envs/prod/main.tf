terraform {
  required_version = ">= 1.5"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
  }

  # Optional remote state with Hetzner Object Storage:
  # backend "s3" {
  #   endpoints = {
  #     s3 = "https://nbg1.your-objectstorage.com"
  #   }
  #   bucket                      = "openclaw-tfstate"
  #   key                         = "prod/terraform.tfstate"
  #   region                      = "main"
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  #   skip_requesting_account_id  = true
  #   skip_s3_checksum            = true
  #   use_path_style              = true
  # }
}

provider "hcloud" {
  token = var.hcloud_token
}

module "vps" {
  source = "../../modules/hetzner-vps"

  project_name        = var.project_name
  environment         = "prod"
  ssh_key_fingerprint = var.ssh_key_fingerprint
  ssh_allowed_cidrs   = var.ssh_allowed_cidrs
  server_type         = var.server_type
  server_location     = var.server_location
  app_user            = var.app_user
  app_directory       = var.app_directory

  cloud_init_user_data = templatefile("${path.module}/../../../cloud-init/user-data.yml.tpl", {
    app_user      = var.app_user
    app_directory = var.app_directory
  })
}

output "server_ip" {
  description = "Public IPv4 of OpenClaw server"
  value       = module.vps.server_ipv4
}

output "server_ipv6" {
  description = "Public IPv6 of OpenClaw server"
  value       = module.vps.server_ipv6
}

output "ssh_command" {
  description = "SSH command for app user"
  value       = module.vps.ssh_command
}
