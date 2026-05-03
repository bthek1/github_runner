# Plan: GitHub Self-Hosted Runner on Proxmox LXC via Terraform

## Goal

Provision a Proxmox LXC container using Terraform and automatically install and
register a GitHub Actions self-hosted runner inside it.

All existing files were copied from a generic LXC project. They need to be
updated to be specific to this use case.

---

## Update order

1. **AGENTS.md** — rewrite AI agent instructions for this project
2. **terraform/lxc/variables.tf** — add GitHub runner variables; tune defaults
3. **terraform/lxc/terraform.tfvars** — set runner-appropriate values (resources, ID, hostname, tags)
4. **terraform/lxc/main.tf** — add `remote-exec` provisioner to install and register the runner
5. **terraform/lxc/outputs.tf** — expose runner-relevant outputs
6. **README.md** — document the project end-to-end

---

## 1 — AGENTS.md

Replace the empty file with agent instructions covering:

- Project purpose: manage a GitHub Actions self-hosted runner on a Proxmox LXC container
- Key files and their roles
- Terraform workflow (plan → apply → destroy)
- How runner registration tokens work and must be kept secret
- Coding conventions: follow `terraform.instructions.md`, sensitive vars use `sensitive = true`
- What NOT to do: hardcode secrets, commit `terraform.tfvars`, skip `terraform plan`

---

## 2 — variables.tf additions

New variables required (append to existing file):

| Variable                | Type                 | Description                                                           |
| ----------------------- | -------------------- | --------------------------------------------------------------------- |
| `github_repo_url`       | `string`             | Full HTTPS URL of the repo or org, e.g. `https://github.com/org/repo` |
| `github_runner_token`   | `string` (sensitive) | Short-lived registration token from GitHub API                        |
| `github_runner_name`    | `string`             | Display name for the runner (defaults to hostname)                    |
| `github_runner_labels`  | `list(string)`       | Extra labels, e.g. `["self-hosted","linux","proxmox"]`                |
| `github_runner_user`    | `string`             | OS user that runs the runner service (defaults to `runner`)           |
| `github_runner_version` | `string`             | Runner binary version to download, e.g. `2.316.1`                     |

Tune existing defaults for a runner workload:

| Variable        | New default |
| --------------- | ----------- |
| `cpu_cores`     | `2`         |
| `memory_mb`     | `2048`      |
| `swap_mb`       | `1024`      |
| `disk_size`     | `20`        |
| `os_type`       | `ubuntu`    |
| `nesting`       | `true`      |
| `start_on_boot` | `true`      |

---

## 3 — terraform.tfvars

Changes needed:

```hcl
container_id       = 110          # pick a free VMID
container_hostname = "gh-runner"
container_tags     = ["terraform", "lxc", "github-runner"]
container_description = "GitHub Actions self-hosted runner"

cpu_cores  = 2
memory_mb  = 2048
swap_mb    = 1024
disk_size  = 20

start_on_boot = true
nesting       = true

github_repo_url       = "https://github.com/<org>/<repo>"
github_runner_name    = "proxmox-lxc-runner"
github_runner_labels  = ["self-hosted", "linux", "proxmox", "ubuntu-24.04"]
github_runner_user    = "runner"
github_runner_version = "2.316.1"
# github_runner_token   — inject via TF_VAR_github_runner_token, never hardcode
```

---

## 4 — main.tf provisioner

After the container is up, a `remote-exec` provisioner (on the `null_resource`)
installs dependencies and the runner:

### Steps executed inside the container

1. `apt-get update && apt-get install -y curl git jq`
2. Create runner OS user (`useradd -m runner`)
3. Download runner tarball from `https://github.com/actions/runner/releases`
4. Extract to `/home/runner/actions-runner/`
5. Run `./config.sh --unattended --url <repo> --token <token> --name <name> --labels <labels>`
6. Install as a `systemd` service via `./svc.sh install runner`
7. `systemctl enable --now actions.runner.*`

The `null_resource` must `depends_on` the container resource and trigger on the
runner token so re-registration is possible by changing the token.

---

## 5 — outputs.tf additions

| Output           | Value                         |
| ---------------- | ----------------------------- |
| `runner_ip`      | Static IP of the container    |
| `runner_name`    | `var.github_runner_name`      |
| `runner_labels`  | `var.github_runner_labels`    |
| `ssh_connection` | `ssh root@<ip>` helper string |

---

## 6 — README.md

Sections:

1. **Prerequisites** — Proxmox API token, SSH key in `~/.ssh/id_ed25519`, GitHub PAT with `repo` scope to generate a registration token
2. **How to get a runner registration token** — GitHub UI path or API call
3. **Secrets / environment variables** — `TF_VAR_proxmox_api_token`, `TF_VAR_github_runner_token`
4. **Deploy** — `terraform init`, `terraform plan`, `terraform apply`
5. **Verify** — where to check the runner appears in GitHub
6. **Destroy** — `terraform destroy`
7. **Re-registration** — how to rotate the runner token

---

## Security notes

- `github_runner_token` and all credentials must be `sensitive = true` and injected via env vars (`TF_VAR_*`), never committed
- `terraform.tfvars` is gitignored
- The runner container should be unprivileged (`unprivileged = true`) unless Docker-in-Docker is required
- If Docker support is needed: set `nesting = true` and install `docker.io` in the provisioner, add runner user to `docker` group

---

## Open decisions (resolve before implementation)

| #   | Question                        | Options                                                          |
| --- | ------------------------------- | ---------------------------------------------------------------- |
| 1   | Repo-level or org-level runner? | Repo runner (simpler token) vs org runner (shared)               |
| 2   | Docker support needed?          | Yes → add nesting + docker install; No → skip                    |
| 3   | Runner token delivery method    | Manual env var vs GitHub API call inside provisioner using a PAT |
| 4   | Multiple runners?               | Single container now; count/for_each later if needed             |
