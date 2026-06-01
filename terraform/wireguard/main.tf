# main.tf — Generate WireGuard keypair and register gh-runner as a VPN peer.
#
# Uses a single local-exec so the generated public key is immediately available
# to the SSH command that registers the peer — no data source timing issues.

resource "null_resource" "wg_peer_setup" {
  triggers = {
    container_vpn_ip = var.container_vpn_ip
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      wg genkey | tee ${path.module}/wg_privatekey | wg pubkey > ${path.module}/wg_publickey
      chmod 600 ${path.module}/wg_privatekey
      PUBKEY=$(tr -d '\n' < ${path.module}/wg_publickey)

      ssh -p ${var.vpn_server_port} \
          -i ${var.vpn_ssh_key_path} \
          -o StrictHostKeyChecking=no \
          -o BatchMode=yes \
          ${var.vpn_server_user}@${var.vpn_server_host} \
          "sudo wg set wg0 peer '$PUBKEY' allowed-ips ${var.container_vpn_ip}/32 && \
           printf '\n[Peer]\n# gh-runner LXC\nPublicKey = %s\nAllowedIPs = ${var.container_vpn_ip}/32\n' \
           '$PUBKEY' | sudo tee -a /etc/wireguard/wg0.conf > /dev/null && \
           echo 'Peer registered: '$PUBKEY"
    EOT
  }
}
