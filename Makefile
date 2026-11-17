TF_DIR        := terraform
ANSIBLE_DIR   := ansible
# Generated from Terraform and git-ignored (real IPs and user name).
INVENTORY     := $(ANSIBLE_DIR)/inventory/hosts.yml
# Proxmox credentials (PROXMOX_VE_*), git-ignored. Loaded only for Terraform.
TF_ENV        := $(TF_DIR)/.env
# Must match kubeconfig_local_path in ansible/inventory/group_vars/all.yml.
KUBECONFIG_PATH := $(HOME)/.kube/homelab.yaml
KUBECTL       = KUBECONFIG=$(KUBECONFIG_PATH) kubectl
# age private key used by SOPS. Never committed; loaded into the cluster by `make sops-key`.
SOPS_AGE_KEY_FILE ?= $(HOME)/.config/sops/age/keys.txt

# Run Terraform with the credentials from $(TF_ENV), without leaking them
# into your shell.
TERRAFORM     = test -f $(TF_ENV) || { echo "Missing $(TF_ENV) (Proxmox credentials)"; exit 1; }; \
                set -a && . ./$(TF_ENV) && set +a && terraform -chdir=$(TF_DIR)

.PHONY: help rebuild destroy inventory known-hosts-reset ansible bootstrap sops-key argocd-ui tf-check ansible-check platform-check

rebuild: ## Recreate the whole platform: VMs, inventory, k3s, then ArgoCD (AUTO_APPROVE=1 to skip the prompt)
	$(TERRAFORM) init -input=false
	$(TERRAFORM) apply $(if $(AUTO_APPROVE),-auto-approve)
	$(MAKE) inventory known-hosts-reset ansible
	$(KUBECTL) wait --for=condition=Ready nodes --all --timeout=180s
	$(KUBECTL) get nodes -o wide
	$(MAKE) bootstrap

destroy: ## Destroy every VM of the cluster (always asks for confirmation)
	$(TERRAFORM) destroy

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

inventory: ## Generate the Ansible inventory from Terraform outputs (git-ignored)
	terraform -chdir=$(TF_DIR) output -raw ansible_inventory > $(INVENTORY)
	@echo "Inventory written to $(INVENTORY)"

known-hosts-reset: ## Forget the SSH host keys of the VMs (after they were recreated)
	grep -oE '[0-9]+(\.[0-9]+){3}' $(INVENTORY) | xargs -n1 ssh-keygen -R

ansible: ## Configure the VMs and install k3s
	cd $(ANSIBLE_DIR) && ansible-playbook playbooks/site.yml

bootstrap: ## Install ArgoCD, load the SOPS key, then hand over to the root app (idempotent)
	$(KUBECTL) create namespace argocd --dry-run=client -o yaml | $(KUBECTL) apply -f -
	$(MAKE) sops-key
	$(KUBECTL) apply --server-side --force-conflicts -k platform/argocd
	$(KUBECTL) -n argocd rollout status deploy/argocd-repo-server --timeout=300s
	$(KUBECTL) -n argocd rollout status deploy/argocd-server --timeout=300s
	$(KUBECTL) apply -f platform/root.yaml
	@echo "ArgoCD is up. It now syncs platform/apps/ from Git. UI: make argocd-ui"

sops-key: ## Load the age private key into the cluster, so ArgoCD can decrypt secrets
	@test -f $(SOPS_AGE_KEY_FILE) || { echo "Missing age key $(SOPS_AGE_KEY_FILE) (see docs/runbooks/sops-age.md)"; exit 1; }
	@$(KUBECTL) -n argocd create secret generic sops-age \
		--from-file=keys.txt=$(SOPS_AGE_KEY_FILE) --dry-run=client -o yaml | $(KUBECTL) apply -f -

argocd-ui: ## Print the ArgoCD admin password and open the UI on https://localhost:8080
	@printf "admin password: "; $(KUBECTL) -n argocd get secret argocd-initial-admin-secret \
		-o jsonpath='{.data.password}' | base64 -d; echo
	$(KUBECTL) -n argocd port-forward svc/argocd-server 8080:443

tf-check: ## Run the same Terraform checks as the CI, locally
	terraform -chdir=$(TF_DIR) fmt -check -recursive
	terraform -chdir=$(TF_DIR) validate
	cd $(TF_DIR) && tflint --init && tflint
	checkov -d $(TF_DIR) --framework terraform --quiet

ansible-check: ## Run the same Ansible checks as the CI, locally
	cd $(ANSIBLE_DIR) && ansible-lint playbooks/site.yml roles/

platform-check: ## Run the same platform checks as the CI, locally
	./scripts/check-platform.sh
