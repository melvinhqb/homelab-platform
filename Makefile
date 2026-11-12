TF_DIR        := terraform
ANSIBLE_DIR   := ansible
# Generated from Terraform and git-ignored (real IPs and user name).
INVENTORY     := $(ANSIBLE_DIR)/inventory/hosts.yml

.PHONY: help inventory known-hosts-reset ansible tf-check

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
