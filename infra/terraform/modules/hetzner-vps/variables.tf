variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "ssh_key_fingerprint" {
  description = "Fingerprint of existing Hetzner SSH key"
  type        = string
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed for SSH"
  type        = list(string)
  default     = []
}

variable "server_type" {
  description = "Hetzner server type"
  type        = string
  default     = "cx23"
}

variable "server_image" {
  description = "Hetzner OS image"
  type        = string
  default     = "ubuntu-24.04"
}

variable "server_location" {
  description = "Hetzner location"
  type        = string
  default     = "nbg1"
  validation {
    condition     = contains(["fsn1", "nbg1", "hel1", "ash", "hil"], var.server_location)
    error_message = "Location must be one of: fsn1, nbg1, hel1, ash, hil."
  }
}

variable "app_user" {
  description = "Non-root app user"
  type        = string
  default     = "openclaw"
}

variable "app_directory" {
  description = "OpenClaw state directory"
  type        = string
  default     = "/home/openclaw/.openclaw"
}

variable "cloud_init_user_data" {
  description = "Rendered cloud-init template"
  type        = string
}
