SHELL := /bin/bash

.PHONY: help tf-init tf-plan tf-apply tf-destroy tf-output ip \
	bootstrap deploy push-env push-config push-google-secrets render-google-secrets google-refresh-token status logs ssh tunnel check

.DEFAULT_GOAL := help

ENV ?= prod
TERRAFORM_DIR := infra/terraform/envs/$(ENV)
VPS_USER ?= openclaw
VPS_IP ?= $(shell cd $(TERRAFORM_DIR) && terraform output -raw server_ip 2>/dev/null)
SSH_KEY_ARG := $(if $(OPENCLAW_SSH_KEY),-i $(OPENCLAW_SSH_KEY) -o IdentitiesOnly=yes,)

# Terraform

tf-init:
	cd $(TERRAFORM_DIR) && terraform init

tf-plan:
	cd $(TERRAFORM_DIR) && terraform plan

tf-apply:
	cd $(TERRAFORM_DIR) && terraform apply

tf-destroy:
	cd $(TERRAFORM_DIR) && terraform destroy

tf-output:
	cd $(TERRAFORM_DIR) && terraform output

ip:
	cd $(TERRAFORM_DIR) && terraform output -raw server_ip

# Deploy

bootstrap:
	./deploy/bootstrap.sh $(VPS_IP)

deploy:
	./deploy/deploy.sh $(VPS_IP)

push-env:
	./scripts/push-env.sh $(VPS_IP)

push-config:
	./scripts/push-config.sh $(VPS_IP)

push-google-secrets:
	./scripts/push-google-secrets.sh $(VPS_IP)

render-google-secrets:
	python3 ./scripts/render-google-oauth-secrets.py

google-refresh-token:
	python3 ./scripts/get-google-refresh-token.py

status:
	./deploy/status.sh $(VPS_IP)

logs:
	./deploy/logs.sh $(VPS_IP)

ssh:
	@IP="$(VPS_IP)"; \
	if [[ -z "$$IP" ]]; then echo "No VPS IP found. Run 'make ip' after tf-apply."; exit 1; fi; \
	ssh -o StrictHostKeyChecking=accept-new $(SSH_KEY_ARG) $(VPS_USER)@$$IP

tunnel:
	@IP="$(VPS_IP)"; \
	if [[ -z "$$IP" ]]; then echo "No VPS IP found. Run 'make ip' after tf-apply."; exit 1; fi; \
	echo "Gateway: http://127.0.0.1:18789"; \
	ssh -N -L 18789:127.0.0.1:18789 -o StrictHostKeyChecking=accept-new $(SSH_KEY_ARG) $(VPS_USER)@$$IP

check:
	bash -n deploy/bootstrap.sh
	bash -n deploy/deploy.sh
	bash -n deploy/status.sh
	bash -n deploy/logs.sh
	bash -n scripts/common.sh
	bash -n scripts/push-env.sh
	bash -n scripts/push-config.sh
	bash -n scripts/push-google-secrets.sh
	bash -n scripts/import-google-oauth-client.sh
	python3 -m py_compile scripts/get-google-refresh-token.py
	python3 -m py_compile scripts/render-google-oauth-secrets.py

help:
	@echo "OpenClaw Hetzner Toolkit"
	@echo ""
	@echo "Terraform:"
	@echo "  make tf-init tf-plan tf-apply"
	@echo "  make tf-destroy"
	@echo "  make tf-output"
	@echo ""
	@echo "Deploy:"
	@echo "  make bootstrap"
	@echo "  make deploy"
	@echo "  make push-env"
	@echo "  make push-config"
	@echo "  make push-google-secrets"
	@echo "  make render-google-secrets"
	@echo "  make google-refresh-token"
	@echo "  make status"
	@echo "  make logs"
	@echo "  make tunnel"
