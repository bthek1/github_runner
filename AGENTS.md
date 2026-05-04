# AGENTS.md — AI Agent Instructions

## Project purpose

This repository provisions a **GitHub Actions self-hosted runner** inside a
Proxmox LXC container using Terraform. The runner is registered with a GitHub
repository or organisation so that CI jobs can execute on your own hardware.

---

## Key files and their roles

| File                             | Role                                                                  |
| -------------------------------- | --------------------------------------------------------------------- |
| `terraform/lxc/provider.tf`      | bpg/proxmox provider + required_providers                             |
| `terraform/lxc/versions.tf`      | Terraform version constraint                                          |
| `terraform/lxc/variables.tf`     | All input variables (provider creds, container sizing, runner config) |
| `terraform/lxc/main.tf`          | LXC container resource + remote-exec runner install provisioner       |
| `terraform/lxc/outputs.tf`       | Useful post-apply outputs (IP, runner name, SSH helper)               |
| `terraform/lxc/terraform.tfvars` | Live values — **gitignored, never commit**                            |
| `PLAN.md`                        | Design decisions and implementation notes                             |

---

## Terraform workflow

```
terraform init          # download providers
terraform plan          # review changes — ALWAYS before apply
terraform apply         # provision container and install runner
terraform destroy       # tear everything down
```

Always run `terraform plan` before `terraform apply`. Never skip it.

---

## Runner registration tokens

GitHub runner tokens are **short-lived** (1 hour) and must be generated
immediately before `terraform apply`. They are injected via the environment:

```bash
export TF_VAR_github_runner_token="<token from GitHub>"
terraform apply
```

Obtain a token from:

- **UI**: Settings → Actions → Runners → New self-hosted runner → token shown in configure step
- **API**: `POST /repos/{owner}/{repo}/actions/runners/registration-token` with a PAT that has `repo` scope

To re-register (e.g. after expiry), generate a new token and run `terraform apply` again —
the `null_resource` triggers on token change.

---

## Coding conventions

- Follow all rules in `.github/instructions/terraform.instructions.md`
- All sensitive variables (`github_runner_token`, `root_password`, etc.) must have `sensitive = true`
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
