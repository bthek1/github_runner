output "container_vpn_ip" {
  description = "VPN IP assigned to the gh-runner container."
  value       = var.container_vpn_ip
}

output "pubkey_path" {
  description = "Path to the generated WireGuard public key file."
  value       = "${path.module}/wg_publickey"
}

output "privatekey_path" {
  description = "Path to the generated WireGuard private key file (sensitive)."
  value       = "${path.module}/wg_privatekey"
  sensitive   = true
}
