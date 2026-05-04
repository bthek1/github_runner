# GitHub Actions Self-Hosted Runner on Proxmox LXC

Provision a Proxmox LXC container using Terraform and automatically install and
register a GitHub Actions self-hosted runner inside it.

---

## Prerequisites

- Proxmox VE 7.x or 8.x with the bpg/proxmox provider accessible via API token or username/password
- Terraform ≥ 1.5
- SSH key at `~/.ssh/id_ed25519` injected into the container's root account
- GitHub PAT with `repo` scope (to generate a runner registration token)
- Ubuntu 24.04 LXC template present in Proxmox local storage
- `gh` CLI (optional, for one-step token generation)

---

## Credentials — `.envrc`

Copy your Proxmox credentials into `.envrc` (already gitignored) and source it before any Terraform command:

```bash
# .envrc
export TF_VAR_proxmox_endpoint="https://192.168.2.70:8006/"
export TF_VAR_proxmox_username="root@pam"
export TF_VAR_proxmox_password="<password>"
# or use an API token instead:
# export TF_VAR_proxmox_api_token="user@pam!token-id=<uuid>"
```

```bash
source .envrc
```

---

## How to get a runner registration token

**GitHub CLI (recommended):**

```bash
gh api --method POST \
  -H "Accept: application/vnd.github+json" \
  /repos/<owner>/<repo>/actions/runners/registration-token \
  --jq '.token'
```

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

## Deploy

```bash
# 1. Source Proxmox credentials
source .envrc

# 2. Generate a fresh runner token and export it
export TF_VAR_github_runner_token=$(gh api --method POST \
  -H "Accept: application/vnd.github+json" \
  /repos/<owner>/<repo>/actions/runners/registration-token \
  --jq '.token')

# 3. Deploy with just (recommended)
just deploy

# Or manually
cd terraform/lxc
terraform init
terraform plan
terraform apply
```

Edit `terraform.tfvars` first (copy from `terraform.tfvars.example`) to set your
`github_repo_url`, container ID, IP address, and other values.

---

## Key variables (`terraform.tfvars`)

| Variable                | Description                              | Default                             |
| ----------------------- | ---------------------------------------- | ----------------------------------- |
| `container_id`          | Proxmox VMID                             | —                                   |
| `container_hostname`    | Container hostname                       | —                                   |
| `network_ip`            | Static IP in CIDR or `dhcp`              | `dhcp`                              |
| `network_gateway`       | Default gateway (static only)            | `""`                                |
| `github_repo_url`       | Full repo URL to register runner against | —                                   |
| `github_runner_name`    | Display name in GitHub UI                | `proxmox-lxc-runner`                |
| `github_runner_labels`  | Runner labels list                       | `["self-hosted","linux","proxmox"]` |
| `github_runner_user`    | OS user that runs the service            | `runner`                            |
| `github_runner_version` | Runner binary version                    | `2.316.1`                           |

---

## Just recipes

```bash
just init        # terraform init
just plan        # terraform plan
just apply       # terraform apply (interactive)
just apply-auto  # terraform apply -auto-approve
just deploy      # init → validate → apply-auto
just destroy     # terraform destroy
just show        # terraform show
just output      # terraform output
just fmt         # format all .tf files
```

---

## Verify

After a successful apply, the runner appears in:

> Repository → Settings → Actions → Runners

It should show as **Idle** with the labels defined in `github_runner_labels`.

You can also SSH in to check the service status:

```bash
ssh root@$(cd terraform/lxc && terraform output -raw runner_ip)
systemctl status "actions.runner.*"
```

---

## Destroy

```bash
just destroy
```

This tears down the LXC container. The runner will appear offline in GitHub —
remove it manually from Settings → Actions → Runners if needed.

---

## Re-registration

If the runner token expires or you need to re-register:

1. Generate a new token (see above)
2. `export TF_VAR_github_runner_token="<new token>"`
3. Run `just apply` — the `null_resource` triggers on token change and re-runs the install provisioner
