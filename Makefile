.PHONY: install lint yaml-parse docs-check python-smoke syntax-check inventory-check ci standalone cluster doctor doctor-live status status-strict post-reboot maintenance-enter maintenance-exit galera-recover ha-failover-test backup restore-test validate diagnostics pre-maintenance post-change post-restart failover-drill upgrade-node-exit awx-controller awx-bootstrap docker-build docker-lint docker-python-smoke docker-shell docker-standalone docker-cluster docker-doctor docker-doctor-live docker-status docker-status-strict docker-post-reboot docker-maintenance-enter docker-maintenance-exit docker-galera-recover docker-ha-failover-test docker-backup docker-restore-test docker-validate docker-diagnostics docker-pre-maintenance docker-post-change docker-post-restart docker-failover-drill docker-upgrade-node-exit docker-awx-controller docker-awx-bootstrap

SSH_DIR ?= $(HOME)/.ssh
HA_INVENTORY ?= inventories/ha/hosts.yml
STANDALONE_INVENTORY ?= inventories/standalone/hosts.yml
AWX_INVENTORY ?= inventories/ha/hosts.yml
RESTORE_TEST_BACKUP_DIR ?=
MAINTENANCE_TARGET ?=
GALERA_RECOVER_BOOTSTRAP_HOST ?=
GALERA_RECOVER_CONFIRM ?= false
PLAYBOOK_FLAGS ?=
ANSIBLE_EXTRA_ARGS ?=
DOCKER_ANSIBLE ?= docker compose run --rm -v $(SSH_DIR):/root/.ssh:ro ansible

install:
	ansible-galaxy collection install -r requirements.yml

lint:
	yamllint .
	ansible-lint

yaml-parse:
	python3 scripts/ci-parse-yaml.py

docs-check:
	python3 scripts/ci-check-markdown-links.py

python-smoke:
	python3 scripts/ci-python-smoke.py

syntax-check:
	python3 scripts/ci-ansible-syntax-check.py

inventory-check:
	python3 scripts/validate-inventory.py --inventory inventories/ha/hosts.yml --group-vars inventories/ha/group_vars/all.yml

ci: python-smoke lint syntax-check

standalone:
	ansible-playbook -i $(STANDALONE_INVENTORY) playbooks/standalone.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

cluster:
	ansible-playbook -i $(HA_INVENTORY) playbooks/cluster.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

doctor:
	ansible-playbook -i $(HA_INVENTORY) playbooks/doctor.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

doctor-live:
	ansible-playbook -i $(HA_INVENTORY) playbooks/doctor.yml $(PLAYBOOK_FLAGS) -e librenms_doctor_network_tcp_checks_enabled=true $(ANSIBLE_EXTRA_ARGS)

status:
	ansible-playbook -i $(HA_INVENTORY) playbooks/status.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

status-strict:
	ansible-playbook -i $(HA_INVENTORY) playbooks/status.yml $(PLAYBOOK_FLAGS) -e librenms_status_alert_fail_on_degraded=true $(ANSIBLE_EXTRA_ARGS)

post-reboot:
	ansible-playbook -i $(HA_INVENTORY) playbooks/post-reboot.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

maintenance-enter:
	ansible-playbook -i $(HA_INVENTORY) playbooks/maintenance-enter.yml $(PLAYBOOK_FLAGS) -e librenms_maintenance_target=$(MAINTENANCE_TARGET) -e librenms_maintenance_confirm=true $(ANSIBLE_EXTRA_ARGS)

maintenance-exit:
	ansible-playbook -i $(HA_INVENTORY) playbooks/maintenance-exit.yml $(PLAYBOOK_FLAGS) -e librenms_maintenance_target=$(MAINTENANCE_TARGET) -e librenms_maintenance_confirm=true $(ANSIBLE_EXTRA_ARGS)

galera-recover:
	ansible-playbook -i $(HA_INVENTORY) playbooks/galera-recover.yml $(PLAYBOOK_FLAGS) -e librenms_galera_recover_bootstrap_host=$(GALERA_RECOVER_BOOTSTRAP_HOST) -e librenms_galera_recover_confirm=$(GALERA_RECOVER_CONFIRM) $(ANSIBLE_EXTRA_ARGS)

ha-failover-test:
	ansible-playbook -i $(HA_INVENTORY) playbooks/ha-failover-test.yml $(PLAYBOOK_FLAGS) -e librenms_failover_test_confirm=true $(ANSIBLE_EXTRA_ARGS)

backup:
	ansible-playbook -i $(HA_INVENTORY) playbooks/backup.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

restore-test:
	ansible-playbook -i $(HA_INVENTORY) playbooks/restore-test.yml $(PLAYBOOK_FLAGS) -e librenms_restore_test_backup_dir=$(RESTORE_TEST_BACKUP_DIR) $(ANSIBLE_EXTRA_ARGS)

validate:
	ansible-playbook -i $(HA_INVENTORY) playbooks/validate.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

diagnostics:
	ansible-playbook -i $(HA_INVENTORY) playbooks/diagnostics.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

pre-maintenance:
	$(MAKE) doctor-live
	$(MAKE) status-strict
	$(MAKE) backup
	$(MAKE) validate

post-change:
	$(MAKE) cluster
	$(MAKE) post-reboot
	$(MAKE) validate

post-restart:
	$(MAKE) post-reboot
	$(MAKE) status-strict
	$(MAKE) validate

failover-drill:
	$(MAKE) pre-maintenance
	$(MAKE) ha-failover-test

upgrade-node-exit:
	$(MAKE) maintenance-exit
	$(MAKE) cluster
	$(MAKE) post-reboot
	$(MAKE) validate

awx-controller:
	ansible-playbook -i $(AWX_INVENTORY) playbooks/awx-controller.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

awx-bootstrap:
	ansible-playbook -i $(AWX_INVENTORY) playbooks/awx-bootstrap.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

docker-build:
	docker compose build ansible

docker-lint:
	docker compose run --rm ansible make lint

docker-python-smoke:
	$(DOCKER_ANSIBLE) python3 scripts/ci-python-smoke.py

docker-shell:
	$(DOCKER_ANSIBLE) bash

docker-standalone:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(STANDALONE_INVENTORY) playbooks/standalone.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

docker-cluster:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/cluster.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

docker-doctor:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/doctor.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

docker-doctor-live:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/doctor.yml $(PLAYBOOK_FLAGS) -e librenms_doctor_network_tcp_checks_enabled=true $(ANSIBLE_EXTRA_ARGS)

docker-status:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/status.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

docker-status-strict:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/status.yml $(PLAYBOOK_FLAGS) -e librenms_status_alert_fail_on_degraded=true $(ANSIBLE_EXTRA_ARGS)

docker-post-reboot:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/post-reboot.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

docker-maintenance-enter:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/maintenance-enter.yml $(PLAYBOOK_FLAGS) -e librenms_maintenance_target=$(MAINTENANCE_TARGET) -e librenms_maintenance_confirm=true $(ANSIBLE_EXTRA_ARGS)

docker-maintenance-exit:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/maintenance-exit.yml $(PLAYBOOK_FLAGS) -e librenms_maintenance_target=$(MAINTENANCE_TARGET) -e librenms_maintenance_confirm=true $(ANSIBLE_EXTRA_ARGS)

docker-galera-recover:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/galera-recover.yml $(PLAYBOOK_FLAGS) -e librenms_galera_recover_bootstrap_host=$(GALERA_RECOVER_BOOTSTRAP_HOST) -e librenms_galera_recover_confirm=$(GALERA_RECOVER_CONFIRM) $(ANSIBLE_EXTRA_ARGS)

docker-ha-failover-test:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/ha-failover-test.yml $(PLAYBOOK_FLAGS) -e librenms_failover_test_confirm=true $(ANSIBLE_EXTRA_ARGS)

docker-backup:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/backup.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

docker-restore-test:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/restore-test.yml $(PLAYBOOK_FLAGS) -e librenms_restore_test_backup_dir=$(RESTORE_TEST_BACKUP_DIR) $(ANSIBLE_EXTRA_ARGS)

docker-validate:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/validate.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

docker-diagnostics:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/diagnostics.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

docker-pre-maintenance:
	$(MAKE) docker-doctor-live
	$(MAKE) docker-status-strict
	$(MAKE) docker-backup
	$(MAKE) docker-validate

docker-post-change:
	$(MAKE) docker-cluster
	$(MAKE) docker-post-reboot
	$(MAKE) docker-validate

docker-post-restart:
	$(MAKE) docker-post-reboot
	$(MAKE) docker-status-strict
	$(MAKE) docker-validate

docker-failover-drill:
	$(MAKE) docker-pre-maintenance
	$(MAKE) docker-ha-failover-test

docker-upgrade-node-exit:
	$(MAKE) docker-maintenance-exit
	$(MAKE) docker-cluster
	$(MAKE) docker-post-reboot
	$(MAKE) docker-validate

docker-awx-controller:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(AWX_INVENTORY) playbooks/awx-controller.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

docker-awx-bootstrap:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(AWX_INVENTORY) playbooks/awx-bootstrap.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)
