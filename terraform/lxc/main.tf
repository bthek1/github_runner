# main.tf — Proxmox LXC container resource

resource "proxmox_virtual_environment_container" "lxc" {
  node_name   = var.proxmox_node
  vm_id       = var.container_id
  description = var.container_description
  tags        = var.container_tags

  unprivileged = var.unprivileged

  features {
    nesting = var.nesting
  }

  started       = var.start_on_create
  start_on_boot = var.start_on_boot

  initialization {
    hostname = var.container_hostname

    # Network: set static IP or DHCP
    ip_config {
      ipv4 {
        address = var.network_ip
        gateway = var.network_ip != "dhcp" ? var.network_gateway : null
      }
    }

    user_account {
      password = var.root_password != "" ? var.root_password : null
      keys     = var.ssh_public_keys != "" ? [var.ssh_public_keys] : []
    }
  }

  cpu {
    cores = var.cpu_cores
  }

  memory {
    dedicated = var.memory_mb
    swap      = var.swap_mb
  }

  disk {
    datastore_id = var.datastore_id
    size         = var.disk_size
  }

  network_interface {
    name    = "eth0"
    bridge  = var.network_bridge
    enabled = true
  }

  operating_system {
    template_file_id = var.template_file_id
    type             = var.os_type
  }
}

resource "null_resource" "extra_user" {
  count = var.extra_username != "" ? 1 : 0

  depends_on = [proxmox_virtual_environment_container.lxc]

  connection {
    type        = "ssh"
    host        = split("/", var.network_ip)[0]
    user        = "root"
    private_key = file("~/.ssh/id_ed25519")
    timeout     = "120s"
  }

  provisioner "remote-exec" {
    inline = [
      "id ${var.extra_username} >/dev/null 2>&1 || useradd -m -s /bin/bash ${var.extra_username}",
      "printf '%s:%s' '${var.extra_username}' '${var.extra_user_password}' | chpasswd",
    ]
  }
}

resource "null_resource" "github_runner" {
  depends_on = [proxmox_virtual_environment_container.lxc]

  triggers = {
    runner_tokens = var.github_runner_tokens
  }

  connection {
    type        = "ssh"
    host        = split("/", var.network_ip)[0]
    user        = "root"
    private_key = file("~/.ssh/id_ed25519")
    timeout     = "300s"
  }

  provisioner "remote-exec" {
    inline = [
      # Fix DNS (LXC containers may not inherit host resolver)
      "printf 'nameserver 1.1.1.1\\nnameserver 8.8.8.8\\n' > /etc/resolv.conf",

      # Dependencies
      "apt-get update -qq",
      "apt-get install -y -qq curl git jq libssl-dev libpango-1.0-0 libpangoft2-1.0-0 libcairo2 libgdk-pixbuf2.0-0 libffi-dev shared-mime-info fonts-liberation",

      # Create runner OS user
      "id ${var.github_runner_user} >/dev/null 2>&1 || useradd -m -s /bin/bash ${var.github_runner_user}",

      # Download runner binary once into a staging directory
      "mkdir -p /home/${var.github_runner_user}/runner-src",
      "curl -fsSL -o /home/${var.github_runner_user}/runner-src/runner.tar.gz https://github.com/actions/runner/releases/download/v${var.github_runner_version}/actions-runner-linux-x64-${var.github_runner_version}.tar.gz",

      # Configure parallel runner instances per target (POSIX-compatible nested loop)
      "TARGETS='${join(",", var.github_runner_targets)}'",
      "TOKENS='${var.github_runner_tokens}'",
      "PARALLEL=${var.github_runner_parallel}",

      # Stop, disable, and remove ALL existing runner services and directories before re-provisioning
      "for svc in $(systemctl list-unit-files | grep actions.runner | awk '{print $1}'); do systemctl stop \"$svc\" 2>/dev/null || true; systemctl disable \"$svc\" 2>/dev/null || true; rm -f \"/etc/systemd/system/$svc\"; done",
      "systemctl daemon-reload",
      "for dir in /home/${var.github_runner_user}/actions-runner*; do [ -d \"$dir\" ] && (cd \"$dir\" && sudo -u ${var.github_runner_user} ./config.sh remove --unattended 2>/dev/null || true) && rm -rf \"$dir\"; done",

      "i=0",
      "for target in $(printf '%s' \"$TARGETS\" | tr ',' ' '); do",
      "  token=$(printf '%s' \"$TOKENS\" | cut -d, -f$((i+1)))",
      "  j=0",
      "  while [ \"$j\" -lt \"$PARALLEL\" ]; do",
      "    idx=$((i * PARALLEL + j))",
      "    dir=/home/${var.github_runner_user}/actions-runner-$idx",
      "    mkdir -p \"$dir\"",
      "    cd \"$dir\" && tar xzf /home/${var.github_runner_user}/runner-src/runner.tar.gz",
      "    chown -R ${var.github_runner_user}:${var.github_runner_user} \"$dir\"",
      "    sudo -u ${var.github_runner_user} ./config.sh --unattended --url \"$target\" --token \"$token\" --name ${var.github_runner_name}-$idx --labels '${join(",", var.github_runner_labels)}' --replace",
      "    ./svc.sh install ${var.github_runner_user}",
      "    j=$((j+1))",
      "  done",
      "  i=$((i+1))",
      "done",

      # Enable and start all installed runner services
      "systemctl enable --now $(systemctl list-unit-files | grep actions.runner | awk '{print $1}')",
    ]
  }
}
