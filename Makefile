.PHONY: install lint inventory-check standalone cluster doctor ha-failover-test backup validate awx-controller docker-build docker-lint docker-shell docker-standalone docker-cluster docker-doctor docker-ha-failover-test docker-backup docker-validate docker-awx-controller

SSH_DIR ?= $(HOME)/.ssh
AWX_INVENTORY ?= inventories/ha/hosts.yml

install:
	ansible-galaxy collection install -r requirements.yml

lint:
	yamllint .
	ansible-lint

inventory-check:
	python3 scripts/validate-inventory.py --inventory inventories/ha/hosts.yml --group-vars inventories/ha/group_vars/all.yml

standalone:
	ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml

cluster:
	ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml

doctor:
	ansible-playbook -i inventories/ha/hosts.yml playbooks/doctor.yml

ha-failover-test:
	ansible-playbook -i inventories/ha/hosts.yml playbooks/ha-failover-test.yml -e librenms_failover_test_confirm=true

backup:
	ansible-playbook -i inventories/ha/hosts.yml playbooks/backup.yml

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

docker-doctor:
	docker compose run --rm -v $(SSH_DIR):/root/.ssh:ro ansible ansible-playbook -i inventories/ha/hosts.yml playbooks/doctor.yml

docker-ha-failover-test:
	docker compose run --rm -v $(SSH_DIR):/root/.ssh:ro ansible ansible-playbook -i inventories/ha/hosts.yml playbooks/ha-failover-test.yml -e librenms_failover_test_confirm=true

docker-backup:
	docker compose run --rm -v $(SSH_DIR):/root/.ssh:ro ansible ansible-playbook -i inventories/ha/hosts.yml playbooks/backup.yml

docker-validate:
	docker compose run --rm -v $(SSH_DIR):/root/.ssh:ro ansible ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml

docker-awx-controller:
	docker compose run --rm -v $(SSH_DIR):/root/.ssh:ro ansible ansible-playbook -i $(AWX_INVENTORY) playbooks/awx-controller.yml
