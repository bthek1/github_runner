# justfile — Terraform commands for Proxmox LXC management
# Usage: just <recipe>  (run `just` or `just -l` to see all recipes)

tf_dir := "terraform/lxc"

# List all available recipes
default:
	@just --list


# ── Init ────────────────────────────────────────────────────────────────────

# Initialise Terraform (download providers)
init:
	terraform -chdir={{tf_dir}} init

# Upgrade providers to latest allowed versions
upgrade:
	terraform -chdir={{tf_dir}} init -upgrade

# ── Plan / Apply / Destroy ───────────────────────────────────────────────────

# Show execution plan (infra only, no runner re-provision)
plan:
	source .envrc && terraform -chdir={{tf_dir}} plan -var-file=terraform.tfvars

# Apply changes (prompts for confirmation; infra only)
apply:
	source .envrc && terraform -chdir={{tf_dir}} apply -var-file=terraform.tfvars

# Apply without interactive prompt (infra only)
apply-auto:
	source .envrc && terraform -chdir={{tf_dir}} apply -var-file=terraform.tfvars -auto-approve

# Generate fresh runner tokens and plan (re-provisions runners)
runner-plan:
	#!/usr/bin/env bash
	set -euo pipefail
	source .envrc
	TOKEN1=$(gh api --method POST -H "Accept: application/vnd.github+json" \
	    /repos/bthek1/proxmox_github_runner/actions/runners/registration-token --jq '.token')
	TOKEN2=$(gh api --method POST -H "Accept: application/vnd.github+json" \
	    /repos/Recovery-Metrics/RM_DRF_Project/actions/runners/registration-token --jq '.token')
	export TF_VAR_github_runner_tokens="${TOKEN1},${TOKEN2}"
	terraform -chdir={{tf_dir}} plan -out=tfplan

# Generate fresh runner tokens, plan, and apply (re-provisions runners)
runner-apply:
	#!/usr/bin/env bash
	set -euo pipefail
	source .envrc
	TOKEN1=$(gh api --method POST -H "Accept: application/vnd.github+json" \
	    /repos/bthek1/proxmox_github_runner/actions/runners/registration-token --jq '.token')
	TOKEN2=$(gh api --method POST -H "Accept: application/vnd.github+json" \
	    /repos/Recovery-Metrics/RM_DRF_Project/actions/runners/registration-token --jq '.token')
	export TF_VAR_github_runner_tokens="${TOKEN1},${TOKEN2}"
	terraform -chdir={{tf_dir}} plan -out=tfplan
	terraform -chdir={{tf_dir}} apply tfplan

# Destroy all resources (prompts for confirmation)
destroy:
	source .envrc && terraform -chdir={{tf_dir}} destroy -var-file=terraform.tfvars

# Destroy without interactive prompt
destroy-auto:
	source .envrc && terraform -chdir={{tf_dir}} destroy -var-file=terraform.tfvars -auto-approve

# ── Inspect ──────────────────────────────────────────────────────────────────

# Show current Terraform state
show:
	terraform -chdir={{tf_dir}} show

# List resources in state
state:
	terraform -chdir={{tf_dir}} state list

# Show outputs
output:
	terraform -chdir={{tf_dir}} output

# Check runner status on GitHub for both repos
runners:
	gh api /repos/bthek1/proxmox_github_runner/actions/runners --jq '.runners[] | {name, status}'
	gh api /repos/Recovery-Metrics/RM_DRF_Project/actions/runners --jq '.runners[] | {name, status}'

# Check runner systemd services on the container
runner-services:
	ssh -i ~/.ssh/id_ed25519 root@192.168.2.101 "systemctl list-units 'actions.runner.*' --no-pager"

# ── Validate / Format ────────────────────────────────────────────────────────

# Validate configuration files
validate:
	terraform -chdir={{tf_dir}} validate

# Format all .tf files
fmt:
	terraform -chdir={{tf_dir}} fmt -recursive

# Check formatting without writing (CI-safe)
fmt-check:
	terraform -chdir={{tf_dir}} fmt -recursive -check

# ── Convenience ──────────────────────────────────────────────────────────────

# init → validate → plan
check: init validate plan

# init → validate → apply-auto (infra only, no runner re-provision)
deploy: init validate apply-auto
