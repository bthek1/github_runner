# GitHub Actions Self-Hosted Runner on Proxmox LXC

Provision a Proxmox LXC container using Terraform and automatically install and
register a GitHub Actions self-hosted runner inside it.

---

## Prerequisites

- Proxmox host with the bpg/proxmox provider accessible via API token
- SSH key at `~/.ssh/id_ed25519` injected into the container's root account
- GitHub PAT with `repo` scope (to generate a runner registration token)
- Ubuntu 24.04 LXC template present in Proxmox local storage

---

## How to get a runner registration token

**GitHub UI:**

1. Go to your repository → Settings → Actions → Runners → **New self-hosted runner**
2. Copy the token shown in the **Configure** step (it starts with `A...`)

**GitHub API:**

```bash
curl -s -X POST \
  -H "Authorization: Bearer <YOUR_PAT>" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/<owner>/<repo>/actions/runners/registration-token \
  | jq -r .token
```

Tokens expire after **1 hour** — generate one immediately before running `terraform apply`.

---

## Secrets / environment variables

Export these before running any Terraform command:

```bash
export TF_VAR_proxmox_endpoint="https://proxmox.local:8006/"
export TF_VAR_proxmox_api_token="user@pam!token-id=<uuid>"
export TF_VAR_github_runner_token="<short-lived token from above>"
```

Never put these values in `terraform.tfvars` or any committed file.

---

## Deploy

```bash
cd terraform/lxc

terraform init

terraform plan

terraform apply
```

Edit `terraform.tfvars` first to set `github_repo_url` to your repository URL.

---

## Verify

After a successful apply, the runner appears in:

> Repository → Settings → Actions → Runners

It should show as **Idle** with the labels defined in `github_runner_labels`.

You can also SSH in to check the service status:

```bash
ssh root@$(terraform output -raw runner_ip)
systemctl status "actions.runner.*"
```

---

## Destroy

```bash
terraform destroy
```

This tears down the LXC container. The runner will appear offline in GitHub —
remove it manually from Settings → Actions → Runners if needed.

---

## Re-registration

If the runner token expires or you need to re-register:

1. Generate a new token (see above)
2. Export `TF_VAR_github_runner_token="<new token>"`
3. Run `terraform apply` — the `null_resource` triggers on token change and re-runs the install provisioner
