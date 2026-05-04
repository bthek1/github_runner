# AGENTS.md — AI Agent Instructions

## Project purpose

This repository provisions a **GitHub Actions self-hosted runner** inside a
Proxmox LXC container using Terraform. The runner is registered with a GitHub
repository or organisation so that CI jobs can execute on your own hardware.

---

## Key files and their roles

| File                                     | Role                                                                  |
| ---------------------------------------- | --------------------------------------------------------------------- |
| `terraform/lxc/provider.tf`              | bpg/proxmox provider + required_providers                             |
| `terraform/lxc/versions.tf`              | Terraform version constraint (Terraform ≥ 1.5, bpg/proxmox ~> 0.75)   |
| `terraform/lxc/variables.tf`             | All input variables (provider creds, container sizing, runner config) |
| `terraform/lxc/main.tf`                  | LXC container resource + remote-exec runner install provisioner       |
| `terraform/lxc/outputs.tf`               | Useful post-apply outputs (IP, runner name, SSH helper)               |
| `terraform/lxc/terraform.tfvars`         | Live values — **gitignored, never commit**                            |
| `terraform/lxc/terraform.tfvars.example` | Template to copy from when creating `terraform.tfvars`                |
| `.envrc`                                 | Exports `TF_VAR_proxmox_*` credentials — sourced before any tf cmd    |
| `justfile`                               | Convenience recipes: `just plan`, `just apply`, `just deploy`, etc.   |
| `PROXMOX_LXC_TERRAFORM_GUIDE.md`         | Step-by-step knowledge-transfer guide for the full setup              |

---

## Terraform workflow

```bash
# Source credentials first
source .envrc

# Standard workflow
terraform -chdir=terraform/lxc init
terraform -chdir=terraform/lxc plan
terraform -chdir=terraform/lxc apply

# Or use just recipes
just init
just plan
just apply
just deploy   # init → validate → apply-auto
```

Always run `terraform plan` before `terraform apply`. Never skip it.

---

## Runner registration tokens

GitHub runner tokens are **short-lived** (1 hour) and must be generated
immediately before `terraform apply`. Generate one token per target org/repo,
in the same order as `github_runner_targets`, and pass them as a comma-separated
string via `TF_VAR_github_runner_tokens`:

```bash
source .envrc
export TF_VAR_github_runner_tokens="$(
  gh api --method POST -H "Accept: application/vnd.github+json" \
    /repos/bthek1/github_runner/actions/runners/registration-token --jq '.token'
),$(
  gh api --method POST -H "Accept: application/vnd.github+json" \
    /repos/Recovery-Metrics/RM_DRF_Project/actions/runners/registration-token --jq '.token'
)"
terraform -chdir=terraform/lxc apply
```

Obtain a token from:

- **gh CLI (org)**: `gh api --method POST /orgs/{org}/actions/runners/registration-token --jq '.token'`
- **gh CLI (repo)**: `gh api --method POST /repos/{owner}/{repo}/actions/runners/registration-token --jq '.token'`
- **UI**: Settings → Actions → Runners → New self-hosted runner → token shown in configure step

To re-register (e.g. after expiry), generate new tokens and run `terraform apply` again —
the `null_resource` triggers on token change.

---

## Coding conventions

- Follow all rules in `.github/instructions/terraform.instructions.md`
- All sensitive variables (`github_runner_tokens`, `root_password`, etc.) must have `sensitive = true`
- Inject credentials via `TF_VAR_*` environment variables — never hardcode them
- `terraform.tfvars` and `*.tfstate*` are gitignored — do not commit them
- Run `terraform fmt` before any commit touching `.tf` files

---

## What NOT to do

- **Never hardcode** tokens, passwords, or API keys in `.tf` files or `terraform.tfvars`
- **Never commit** `terraform.tfvars` — it is gitignored for a reason
- **Never skip** `terraform plan` before `terraform apply`
- Do not set `unprivileged = false` unless Docker-in-Docker is explicitly required
- Do not add runner tokens to git history, even in environment files
