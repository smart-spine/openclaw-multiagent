variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

variable "ssh_key_fingerprint" {
  description = "Fingerprint of existing Hetzner SSH key"
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed for SSH access"
  type        = list(string)
  default     = []
}

variable "project_name" {
  description = "Project name prefix"
  type        = string
  default     = "openclaw"
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cx23"
}

variable "server_location" {
  description = "Hetzner location"
  type        = string
  default     = "nbg1"
}

variable "app_user" {
  description = "Non-root user for deployment"
  type        = string
  default     = "openclaw"
}

variable "app_directory" {
  description = "OpenClaw state directory on VPS"
  type        = string
  default     = "/home/openclaw/.openclaw"
}
