.PHONY: controller-bootstrap install lint yaml-parse docs-check python-smoke syntax-check inventory-check ci test-controller-collection-bootstrap test-galera-readiness test-galera-bootstrap-guardrails test-mariadb-series-guardrails test-runtime-support-guardrails test-platform-support-guardrails test-redis-sentinel-consensus-guardrails test-daily-maintenance-guardrails test-runtime-web-health-guardrails test-outage-recovery-guardrails test-failover-recovery-guardrails test-load-balancer-rollout-guardrails test-production-readiness-evidence-guardrails test-production-readiness-evidence-verifier test-awx-status-schedule-guardrails test-host-firewall-guardrails test-gluster-rrd-mount-guardrails test-post-reboot-rrdcached-guardrails test-docker-ha-galera-config integration-platform-runtime integration-galera integration-haproxy-web integration-redis-sentinel standalone platform-bootstrap-ask-become-pass site site-ask-become-pass cluster doctor doctor-live status status-strict post-reboot maintenance-enter maintenance-exit galera-recover galera-recover-ask-become-pass ha-failover-test firewall backup restore-test validate production-readiness diagnostics pre-maintenance post-change post-restart failover-drill upgrade-node-exit awx-controller awx-bootstrap docker-build docker-lint docker-python-smoke docker-shell docker-standalone docker-cluster docker-doctor docker-doctor-live docker-status docker-status-strict docker-post-reboot docker-maintenance-enter docker-maintenance-exit docker-galera-recover docker-ha-failover-test docker-backup docker-restore-test docker-validate docker-production-readiness docker-diagnostics docker-pre-maintenance docker-post-change docker-post-restart docker-failover-drill docker-upgrade-node-exit docker-awx-controller docker-awx-bootstrap

SSH_DIR ?= $(HOME)/.ssh
HA_INVENTORY ?= inventories/ha/hosts.yml
STANDALONE_INVENTORY ?= inventories/standalone/hosts.yml
AWX_INVENTORY ?= inventories/ha/hosts.yml
RESTORE_TEST_BACKUP_DIR ?=
MAINTENANCE_TARGET ?=
GALERA_RECOVER_BOOTSTRAP_HOST ?=
GALERA_RECOVER_CONFIRM ?= false
GALERA_RECOVER_TIE_BREAKER ?= manual
PLAYBOOK_FLAGS ?=
ANSIBLE_EXTRA_ARGS ?=
ANSIBLE_PLAYBOOK ?= ./scripts/ansible-playbook.sh
INTERACTIVE_BECOME_TIMEOUT ?= 120
INTERACTIVE_BECOME_FORKS ?= 1
DOCKER_ANSIBLE ?= docker compose run --rm -v $(SSH_DIR):/root/.ssh:ro ansible

controller-bootstrap:
	bash scripts/bootstrap-controller.sh

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

ci: python-smoke lint syntax-check test-controller-collection-bootstrap test-galera-readiness test-galera-bootstrap-guardrails test-mariadb-series-guardrails test-runtime-support-guardrails test-platform-support-guardrails test-redis-sentinel-consensus-guardrails test-daily-maintenance-guardrails test-runtime-web-health-guardrails test-outage-recovery-guardrails test-failover-recovery-guardrails test-load-balancer-rollout-guardrails test-production-readiness-evidence-guardrails test-production-readiness-evidence-verifier test-awx-status-schedule-guardrails test-host-firewall-guardrails test-gluster-rrd-mount-guardrails test-post-reboot-rrdcached-guardrails

test-controller-collection-bootstrap:
	bash tests/unit/test-controller-collection-bootstrap.sh

test-galera-readiness:
	bash tests/unit/test-galera-readiness-agent.sh

test-galera-bootstrap-guardrails:
	bash tests/unit/test-galera-bootstrap-guardrails.sh

test-mariadb-series-guardrails:
	bash tests/unit/test-mariadb-series-guardrails.sh

test-runtime-support-guardrails:
	bash tests/unit/test-runtime-support-guardrails.sh

test-platform-support-guardrails:
	bash tests/unit/test-platform-support-guardrails.sh

test-redis-sentinel-consensus-guardrails:
	bash tests/unit/test-redis-sentinel-consensus-guardrails.sh

test-daily-maintenance-guardrails:
	bash tests/unit/test-daily-maintenance-guardrails.sh

test-runtime-web-health-guardrails:
	bash tests/unit/test-runtime-web-health-guardrails.sh

test-outage-recovery-guardrails:
	bash tests/unit/test-outage-recovery-guardrails.sh

test-failover-recovery-guardrails:
	bash tests/unit/test-failover-recovery-guardrails.sh

test-load-balancer-rollout-guardrails:
	bash tests/unit/test-load-balancer-rollout-guardrails.sh

test-production-readiness-evidence-guardrails:
	bash tests/unit/test-production-readiness-evidence-guardrails.sh

test-production-readiness-evidence-verifier:
	bash tests/unit/test-production-readiness-evidence-verifier.sh

test-awx-status-schedule-guardrails:
	bash tests/unit/test-awx-status-schedule-guardrails.sh

test-host-firewall-guardrails:
	bash tests/unit/test-host-firewall-guardrails.sh

test-gluster-rrd-mount-guardrails:
	bash tests/unit/test-gluster-rrd-mount-guardrails.sh

test-post-reboot-rrdcached-guardrails:
	bash tests/unit/test-post-reboot-rrdcached-guardrails.sh

test-docker-ha-galera-config:
	bash tests/unit/test-docker-ha-galera-config.sh

integration-platform-runtime:
	docker compose build ansible
	bash tests/platform/managed-runtime-smoke.sh ubuntu:22.04 3.10 ubuntu-22
	bash tests/platform/managed-runtime-smoke.sh ubuntu:24.04 3.12 ubuntu-24
	bash tests/platform/managed-runtime-smoke.sh ubuntu:26.04 3.14 ubuntu-26
	bash tests/platform/managed-runtime-smoke.sh rockylinux/rockylinux:8 3.11 rocky-8
	bash tests/platform/managed-runtime-smoke.sh rockylinux/rockylinux:9 3.9 rocky-9
	bash tests/platform/managed-runtime-smoke.sh rockylinux/rockylinux:10 3.12 rocky-10
	bash tests/platform/managed-runtime-smoke.sh almalinux:8 3.11 alma-8
	bash tests/platform/managed-runtime-smoke.sh almalinux:9 3.9 alma-9
	bash tests/platform/managed-runtime-smoke.sh almalinux:10 3.12 alma-10

integration-haproxy-web:
	bash tests/integration/haproxy-web/test.sh

integration-galera:
	bash tests/integration/galera/test.sh

integration-redis-sentinel:
	bash tests/integration/redis-sentinel/test.sh

standalone:
	$(ANSIBLE_PLAYBOOK) -i $(STANDALONE_INVENTORY) playbooks/standalone.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

platform-bootstrap-ask-become-pass:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/platform-bootstrap.yml --ask-become-pass --timeout $(INTERACTIVE_BECOME_TIMEOUT) --forks $(INTERACTIVE_BECOME_FORKS) $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

site:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/site.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

site-ask-become-pass:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/site.yml --ask-become-pass --timeout $(INTERACTIVE_BECOME_TIMEOUT) --forks $(INTERACTIVE_BECOME_FORKS) $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

cluster:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/cluster.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

doctor:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/doctor.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

doctor-live:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/doctor.yml $(PLAYBOOK_FLAGS) -e librenms_doctor_network_tcp_checks_enabled=true $(ANSIBLE_EXTRA_ARGS)

status:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/status.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

status-strict:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/status.yml $(PLAYBOOK_FLAGS) -e librenms_status_alert_fail_on_degraded=true $(ANSIBLE_EXTRA_ARGS)

post-reboot:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/post-reboot.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

maintenance-enter:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/maintenance-enter.yml $(PLAYBOOK_FLAGS) -e librenms_maintenance_target=$(MAINTENANCE_TARGET) -e librenms_maintenance_confirm=true $(ANSIBLE_EXTRA_ARGS)

maintenance-exit:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/maintenance-exit.yml $(PLAYBOOK_FLAGS) -e librenms_maintenance_target=$(MAINTENANCE_TARGET) -e librenms_maintenance_confirm=true $(ANSIBLE_EXTRA_ARGS)

galera-recover:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/galera-recover.yml $(PLAYBOOK_FLAGS) -e librenms_galera_recover_bootstrap_host=$(GALERA_RECOVER_BOOTSTRAP_HOST) -e librenms_galera_recover_confirm=$(GALERA_RECOVER_CONFIRM) -e librenms_galera_recover_tie_breaker=$(GALERA_RECOVER_TIE_BREAKER) $(ANSIBLE_EXTRA_ARGS)

galera-recover-ask-become-pass:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/galera-recover.yml --ask-become-pass --timeout $(INTERACTIVE_BECOME_TIMEOUT) --forks $(INTERACTIVE_BECOME_FORKS) $(PLAYBOOK_FLAGS) -e librenms_galera_recover_bootstrap_host=$(GALERA_RECOVER_BOOTSTRAP_HOST) -e librenms_galera_recover_confirm=$(GALERA_RECOVER_CONFIRM) -e librenms_galera_recover_tie_breaker=$(GALERA_RECOVER_TIE_BREAKER) $(ANSIBLE_EXTRA_ARGS)

ha-failover-test:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/ha-failover-test.yml $(PLAYBOOK_FLAGS) -e librenms_failover_test_confirm=true $(ANSIBLE_EXTRA_ARGS)

firewall:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/firewall.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

backup:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/backup.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

restore-test:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/restore-test.yml $(PLAYBOOK_FLAGS) -e librenms_restore_test_backup_dir=$(RESTORE_TEST_BACKUP_DIR) $(ANSIBLE_EXTRA_ARGS)

validate:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/validate.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

production-readiness:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/production-readiness.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

diagnostics:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/diagnostics.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

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
	$(ANSIBLE_PLAYBOOK) -i $(AWX_INVENTORY) playbooks/awx-controller.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

awx-bootstrap:
	$(ANSIBLE_PLAYBOOK) -i $(AWX_INVENTORY) playbooks/awx-bootstrap.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

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
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/galera-recover.yml $(PLAYBOOK_FLAGS) -e librenms_galera_recover_bootstrap_host=$(GALERA_RECOVER_BOOTSTRAP_HOST) -e librenms_galera_recover_confirm=$(GALERA_RECOVER_CONFIRM) -e librenms_galera_recover_tie_breaker=$(GALERA_RECOVER_TIE_BREAKER) $(ANSIBLE_EXTRA_ARGS)

docker-ha-failover-test:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/ha-failover-test.yml $(PLAYBOOK_FLAGS) -e librenms_failover_test_confirm=true $(ANSIBLE_EXTRA_ARGS)

docker-backup:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/backup.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

docker-restore-test:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/restore-test.yml $(PLAYBOOK_FLAGS) -e librenms_restore_test_backup_dir=$(RESTORE_TEST_BACKUP_DIR) $(ANSIBLE_EXTRA_ARGS)

docker-validate:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/validate.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

docker-production-readiness:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/production-readiness.yml $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

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

PLATFORM_ACCEPTANCE_CONFIRM ?= false
PLATFORM_ACCEPTANCE_LIMIT ?= librenms_nodes

.PHONY: platform-acceptance

# This installs and verifies the platform package contract on the selected
# managed hosts. Keep it explicit because package installation can start or
# restart distribution services on an existing machine.
platform-acceptance:
	@if [ "$(PLATFORM_ACCEPTANCE_CONFIRM)" != "true" ]; then \
		printf '%s\n' 'Refusing platform acceptance: set PLATFORM_ACCEPTANCE_CONFIRM=true explicitly.' >&2; \
		exit 2; \
	fi
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/platform-acceptance.yml --limit "$(PLATFORM_ACCEPTANCE_LIMIT)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)
