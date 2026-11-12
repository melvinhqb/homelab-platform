TF_DIR        := terraform
ANSIBLE_DIR   := ansible
# Generated from Terraform and git-ignored (real IPs and user name).
INVENTORY     := $(ANSIBLE_DIR)/inventory/hosts.yml
# Proxmox credentials (PROXMOX_VE_*), git-ignored. Loaded only for Terraform.
TF_ENV        := $(TF_DIR)/.env
# Must match kubeconfig_local_path in ansible/inventory/group_vars/all.yml.
KUBECONFIG_PATH := $(HOME)/.kube/homelab.yaml

# Run Terraform with the credentials from $(TF_ENV), without leaking them
# into your shell.
TERRAFORM     = test -f $(TF_ENV) || { echo "Missing $(TF_ENV) (Proxmox credentials)"; exit 1; }; \
                set -a && . ./$(TF_ENV) && set +a && terraform -chdir=$(TF_DIR)

.PHONY: help rebuild destroy inventory known-hosts-reset ansible tf-check ansible-check

rebuild: ## Recreate the whole cluster: VMs, inventory, k3s, then check the nodes (AUTO_APPROVE=1 to skip the prompt)
	$(TERRAFORM) init -input=false
	$(TERRAFORM) apply $(if $(AUTO_APPROVE),-auto-approve)
	$(MAKE) inventory known-hosts-reset ansible
	KUBECONFIG=$(KUBECONFIG_PATH) kubectl wait --for=condition=Ready nodes --all --timeout=180s
	KUBECONFIG=$(KUBECONFIG_PATH) kubectl get nodes -o wide

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

tf-check: ## Run the same Terraform checks as the CI, locally
	terraform -chdir=$(TF_DIR) fmt -check -recursive
	terraform -chdir=$(TF_DIR) validate
	cd $(TF_DIR) && tflint --init && tflint
	checkov -d $(TF_DIR) --framework terraform --quiet

ansible-check: ## Run the same Ansible checks as the CI, locally
	cd $(ANSIBLE_DIR) && ansible-lint playbooks/site.yml roles/
