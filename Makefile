.PHONY: install lint standalone cluster validate awx-controller docker-build docker-lint docker-shell docker-standalone docker-cluster docker-validate docker-awx-controller

SSH_DIR ?= $(HOME)/.ssh
AWX_INVENTORY ?= inventories/ha/hosts.yml

install:
	ansible-galaxy collection install -r requirements.yml

lint:
	yamllint .
	ansible-lint

standalone:
	ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml

cluster:
	ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml

validate:
	ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml

awx-controller:
	ansible-playbook -i $(AWX_INVENTORY) playbooks/awx-controller.yml

docker-build:
	docker compose build ansible

docker-lint:
	docker compose run --rm ansible make lint

docker-shell:
	docker compose run --rm -v $(SSH_DIR):/root/.ssh:ro ansible bash

docker-standalone:
	docker compose run --rm -v $(SSH_DIR):/root/.ssh:ro ansible ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml

docker-cluster:
	docker compose run --rm -v $(SSH_DIR):/root/.ssh:ro ansible ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml

docker-validate:
	docker compose run --rm -v $(SSH_DIR):/root/.ssh:ro ansible ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml

docker-awx-controller:
	docker compose run --rm -v $(SSH_DIR):/root/.ssh:ro ansible ansible-playbook -i $(AWX_INVENTORY) playbooks/awx-controller.yml
