TF_DIR        := terraform
# Generated from Terraform and git-ignored (real IPs and user name).
INVENTORY     := ansible/inventory/hosts.yml

.PHONY: help inventory tf-check

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-12s %s\n", $$1, $$2}'

inventory: ## Generate the Ansible inventory from Terraform outputs (git-ignored)
	terraform -chdir=$(TF_DIR) output -raw ansible_inventory > $(INVENTORY)
	@echo "Inventory written to $(INVENTORY)"

tf-check: ## Run the same Terraform checks as the CI, locally
	terraform -chdir=$(TF_DIR) fmt -check -recursive
	terraform -chdir=$(TF_DIR) validate
	cd $(TF_DIR) && tflint --init && tflint
	checkov -d $(TF_DIR) --framework terraform --quiet
