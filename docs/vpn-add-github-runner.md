# Plan: Add gh-runner LXC Container to WireGuard VPN

## Status: COMPLETE ✓ (2026-06-01)

| Host | LAN IP | VPN IP |
|------|--------|--------|
| VPN server (AWS EC2) | 3.104.200.207 | 10.8.0.1 |
| Proxmox host | 192.168.2.70 | 10.8.0.2 |
| gh-runner LXC | 192.168.2.101 | **10.8.0.8** ✓ |

---

## What was done

### Incident (2026-06-01 ~04:20 UTC)
Container rebooted. `/etc/resolv.conf` pointed to `nameserver 10.8.0.1` (VPN server) but the
container had no route to the VPN subnet — all DNS timed out, all 9 runners went offline.

**Temporary workarounds applied at the time:**
- `/etc/resolv.conf` manually set to `nameserver 8.8.8.8`
- `net.ipv4.ip_forward = 1` added to `/etc/sysctl.conf` on Proxmox host
- `[Route]` block for `10.8.0.0/24 via 192.168.2.70` added to `/etc/systemd/network/eth0.network`

---

### Fix: Terraform — keypair generation + peer registration ✓

**`terraform/wireguard/`** — new module with `null` provider only.

`main.tf` runs a single `local-exec` that:
1. Generates a WireGuard keypair → `terraform/wireguard/wg_privatekey` + `wg_publickey` (gitignored)
2. SSHes to the VPN server and calls `sudo wg set wg0 peer ...` + appends to `/etc/wireguard/wg0.conf`

Registered peer public key: `VOyC7oasVKDbc4u/TxoRDRXg8mUraDX7ZL4qWUyGOxg=`

```bash
cd terraform/wireguard && terraform init && terraform apply -auto-approve
```

---

### Fix: Ansible — container config + workaround cleanup ✓

**`ansible/vpn.yml`** against `[gh_runner]` and `[proxmox]` in `ansible/inventory.ini`:

| Task | Result |
|------|--------|
| Install `wireguard-tools` | changed |
| Write `/etc/wireguard/wg0.conf` (Interface + Peer) | changed |
| `systemctl enable --now wg-quick@wg0` | changed |
| Restore clean `eth0.network` (remove workaround route block) | changed |
| Remove runtime route `10.8.0.0/24 via 192.168.2.70` | ok |
| Reload `systemd-networkd` | changed |
| Ping 10.8.0.1 — 0% packet loss, ~22ms | ok |
| nslookup github.com via 10.8.0.1 — resolved | ok |
| Remove `net.ipv4.ip_forward = 1` from Proxmox `/etc/sysctl.conf` | done (via SSH) |
| Restore `nameserver 10.8.0.1` in container `/etc/resolv.conf` | done (via `pct exec`) |

```bash
ansible-playbook -i ansible/inventory.ini ansible/vpn.yml
```

---

## Current state

```
wg show (on gh-runner)
  interface: wg0  — 10.8.0.8/24
  peer: f6ki/...  — endpoint 3.104.200.207:51820
  latest handshake: active
  persistent keepalive: every 25 seconds

nslookup github.com → Server: 10.8.0.1 → 4.237.22.38  ✓
9/9 runner services: active running                      ✓
```

---

## Re-run anytime

```bash
just vpn-setup   # terraform apply + ansible-playbook
```

This is idempotent — safe to re-run if the container is rebuilt or VPN config is lost.
