variable "container_vpn_ip" {
  description = "VPN IP to assign to the gh-runner container."
  type        = string
  default     = "10.8.0.8"
}

variable "vpn_server_host" {
  description = "Public IP or hostname of the WireGuard VPN server."
  type        = string
  default     = "3.104.200.207"
}

variable "vpn_server_user" {
  description = "SSH user on the VPN server."
  type        = string
  default     = "ubuntu"
}

variable "vpn_server_port" {
  description = "SSH port on the VPN server."
  type        = number
  default     = 2222
}

variable "vpn_ssh_key_path" {
  description = "Path to the SSH private key for the VPN server."
  type        = string
  default     = "~/.ssh/wireguard-key"
}

variable "vpn_server_pubkey" {
  description = "WireGuard public key of the VPN server."
  type        = string
  default     = "f6ki/InnhoO5nXqfddvZoE1xaPKoXnwEC5vCA0Wj5Ww="
}
