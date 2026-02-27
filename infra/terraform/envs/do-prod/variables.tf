variable "project_name" {
  description = "Name prefix for DigitalOcean resources."
  type        = string
  default     = "openclaw"
}

variable "region" {
  description = "DigitalOcean region slug."
  type        = string
  default     = "nyc1"
}

variable "size" {
  description = "DigitalOcean droplet size slug."
  type        = string
  default     = "s-1vcpu-2gb"
}

variable "ssh_allowed_cidrs" {
  description = "CIDR ranges allowed to SSH into the droplet."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_public_key_path" {
  description = "Absolute path to the local SSH public key file."
  type        = string
}
