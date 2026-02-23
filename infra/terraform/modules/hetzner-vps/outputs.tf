output "server_id" {
  description = "Server ID"
  value       = hcloud_server.main.id
}

output "server_ipv4" {
  description = "Server public IPv4"
  value       = hcloud_server.main.ipv4_address
}

output "server_ipv6" {
  description = "Server public IPv6"
  value       = hcloud_server.main.ipv6_address
}

output "server_status" {
  description = "Server status"
  value       = hcloud_server.main.status
}

output "ssh_key_id" {
  description = "Resolved SSH key ID"
  value       = data.hcloud_ssh_key.main.id
}

output "firewall_id" {
  description = "Firewall ID"
  value       = hcloud_firewall.main.id
}

output "ssh_command" {
  description = "SSH command for app user"
  value       = "ssh ${var.app_user}@${hcloud_server.main.ipv4_address}"
}

output "ssh_command_root" {
  description = "SSH command for root"
  value       = "ssh root@${hcloud_server.main.ipv4_address}"
}
