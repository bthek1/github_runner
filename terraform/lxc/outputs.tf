# outputs.tf — Outputs for the Proxmox LXC container

output "container_id" {
  description = "The VMID of the LXC container."
  value       = proxmox_virtual_environment_container.lxc.vm_id
}

output "container_hostname" {
  description = "Hostname of the LXC container."
  value       = proxmox_virtual_environment_container.lxc.initialization[0].hostname
}

output "network_ip" {
  description = "Configured IPv4 address (or 'dhcp')."
  value       = var.network_ip
}

output "runner_ip" {
  description = "Static IP address of the runner container (without prefix length)."
  value       = split("/", var.network_ip)[0]
}

output "runner_name" {
  description = "Display name of the GitHub Actions runner."
  value       = var.github_runner_name
}

output "runner_labels" {
  description = "Labels attached to the GitHub Actions runner."
  value       = var.github_runner_labels
}

output "ssh_connection" {
  description = "SSH command to connect to the runner container."
  value       = "ssh root@${split("/", var.network_ip)[0]}"
}
