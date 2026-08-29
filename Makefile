.PHONY: controller-bootstrap install lint yaml-parse docs-check python-smoke syntax-check inventory-check github-governance-check ci test-controller-collection-bootstrap test-galera-readiness test-galera-bootstrap-guardrails test-mariadb-series-guardrails test-runtime-support-guardrails test-platform-support-guardrails test-redis-sentinel-consensus-guardrails test-daily-maintenance-guardrails test-runtime-web-health-guardrails test-outage-recovery-guardrails test-failover-recovery-guardrails test-load-balancer-rollout-guardrails test-production-readiness-evidence-guardrails test-production-readiness-evidence-verifier test-awx-status-schedule-guardrails test-host-firewall-guardrails test-gluster-rrd-mount-guardrails test-post-reboot-rrdcached-guardrails test-fast-repair-guardrails test-github-governance-guardrails test-docker-ha-galera-config integration-platform-runtime integration-galera integration-haproxy-web integration-redis-sentinel standalone platform-bootstrap-ask-become-pass site site-ask-become-pass readiness-repair readiness-repair-ask-become-pass rrdcached-unit-repair rrdcached-unit-repair-ask-become-pass repair repair-ask-become-pass repair-check cluster doctor doctor-live status status-strict post-reboot maintenance-enter maintenance-exit galera-recover galera-recover-ask-become-pass ha-failover-test firewall backup restore-test validate production-readiness production-readiness-ask-become-pass diagnostics pre-maintenance post-change post-restart failover-drill upgrade-node-exit awx-controller awx-bootstrap os-upgrade-preflight os-upgrade-node os-upgrade-execute mariadb-upgrade-preflight runtime-upgrade runtime-upgrade-ask-become-pass test-upgrade-selector-guardrails docker-build docker-lint docker-python-smoke docker-shell docker-standalone docker-cluster docker-doctor docker-doctor-live docker-status docker-status-strict docker-post-reboot docker-maintenance-enter docker-maintenance-exit docker-galera-recover docker-ha-failover-test docker-backup docker-restore-test docker-validate docker-production-readiness docker-production-readiness-ask-become-pass docker-diagnostics docker-pre-maintenance docker-post-change docker-post-restart docker-failover-drill docker-upgrade-node-exit docker-awx-controller docker-awx-bootstrap

SSH_DIR ?= $(HOME)/.ssh
HA_INVENTORY ?= inventories/ha/hosts.yml
STANDALONE_INVENTORY ?= inventories/standalone/hosts.yml
AWX_INVENTORY ?= inventories/ha/hosts.yml
RESTORE_TEST_BACKUP_DIR ?=
MAINTENANCE_TARGET ?=
GALERA_RECOVER_BOOTSTRAP_HOST ?=
GALERA_RECOVER_CONFIRM ?= false
GALERA_RECOVER_TIE_BREAKER ?=
GALERA_RECOVER_TIE_BREAKER_ARG = $(if $(strip $(GALERA_RECOVER_TIE_BREAKER)),-e librenms_galera_recover_tie_breaker=$(GALERA_RECOVER_TIE_BREAKER))
PLAYBOOK_FLAGS ?=
ANSIBLE_EXTRA_ARGS ?=
ANSIBLE_PLAYBOOK ?= ./scripts/ansible-playbook.sh
INTERACTIVE_BECOME_TIMEOUT ?= 120
INTERACTIVE_BECOME_FORKS ?= 1
FAST_REPAIR_CONFIRM ?= false
FAST_REPAIR_LIMIT ?= librenms_nodes
FAST_REPAIR_TIMEOUT ?= 30
FAST_REPAIR_FORKS ?= 1
FAST_REPAIR_BECOME_TIMEOUT ?= 60
FAST_REPAIR_MANAGER_ATTEMPTS ?= 12
FAST_REPAIR_MANAGER_PROBE_TIMEOUT ?= 10
READINESS_REPAIR_LIMIT ?= librenms_db
READINESS_REPAIR_TIMEOUT ?= 30
READINESS_REPAIR_FORKS ?= 1
OS_UPGRADE_LIMIT ?=
OS_UPGRADE_TARGET_DISTRIBUTION ?=
OS_UPGRADE_TARGET_MAJOR ?=
OS_UPGRADE_CONFIRM ?= false
OS_UPGRADE_EXECUTE ?= false
OS_UPGRADE_COMMAND ?=
OS_UPGRADE_TIMEOUT ?= 120
OS_UPGRADE_FORKS ?= 1
MARIADB_UPGRADE_LIMIT ?=
MARIADB_UPGRADE_TIMEOUT ?= 120
MARIADB_UPGRADE_FORKS ?= 1
RUNTIME_UPGRADE_LIMIT ?=
RUNTIME_UPGRADE_COMPONENTS ?= nginx,php
RUNTIME_UPGRADE_CONFIRM ?= false
RUNTIME_UPGRADE_MARIADB_CONFIRM ?= false
RUNTIME_UPGRADE_TIMEOUT ?= 120
RUNTIME_UPGRADE_FORKS ?= 1
RRDCACHED_UNIT_REPAIR_CONFIRM ?= false
RRDCACHED_UNIT_REPAIR_LIMIT ?= librenms_nodes
RRDCACHED_UNIT_REPAIR_TIMEOUT ?= 120
RRDCACHED_UNIT_REPAIR_FORKS ?= 1
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

github-governance-check:
	python3 scripts/ci-github-governance-check.py --branch main

ci: python-smoke lint syntax-check test-controller-collection-bootstrap test-galera-readiness test-galera-bootstrap-guardrails test-mariadb-series-guardrails test-upgrade-selector-guardrails test-runtime-support-guardrails test-platform-support-guardrails test-redis-sentinel-consensus-guardrails test-daily-maintenance-guardrails test-runtime-web-health-guardrails test-outage-recovery-guardrails test-failover-recovery-guardrails test-load-balancer-rollout-guardrails test-production-readiness-evidence-guardrails test-production-readiness-evidence-verifier test-awx-status-schedule-guardrails test-host-firewall-guardrails test-gluster-rrd-mount-guardrails test-post-reboot-rrdcached-guardrails test-fast-repair-guardrails test-github-governance-guardrails

test-controller-collection-bootstrap:
	bash tests/unit/test-controller-collection-bootstrap.sh

test-galera-readiness:
	bash tests/unit/test-galera-readiness-agent.sh

test-galera-bootstrap-guardrails:
	bash tests/unit/test-galera-bootstrap-guardrails.sh

test-mariadb-series-guardrails:
	bash tests/unit/test-mariadb-series-guardrails.sh

test-upgrade-selector-guardrails:
	bash tests/unit/test-upgrade-selector-guardrails.sh

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

test-fast-repair-guardrails:
	bash tests/unit/test-fast-repair-guardrails.sh

test-github-governance-guardrails:
	bash tests/unit/test-github-governance-guardrails.sh

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

os-upgrade-preflight:
	@test -n "$(OS_UPGRADE_LIMIT)" || (echo "Refusing OS upgrade preflight: set OS_UPGRADE_LIMIT to exactly one host" && exit 2)
	@test -n "$(OS_UPGRADE_TARGET_DISTRIBUTION)" || (echo "Refusing OS upgrade preflight: set OS_UPGRADE_TARGET_DISTRIBUTION" && exit 2)
	@test -n "$(OS_UPGRADE_TARGET_MAJOR)" || (echo "Refusing OS upgrade preflight: set OS_UPGRADE_TARGET_MAJOR" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/os-upgrade-preflight.yml --limit "$(OS_UPGRADE_LIMIT)" --timeout $(OS_UPGRADE_TIMEOUT) --forks $(OS_UPGRADE_FORKS) -e "librenms_os_upgrade_target_distribution=$(OS_UPGRADE_TARGET_DISTRIBUTION)" -e "librenms_os_upgrade_target_major=$(OS_UPGRADE_TARGET_MAJOR)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

os-upgrade-node:
	@test -n "$(OS_UPGRADE_LIMIT)" || (echo "Refusing OS upgrade execution: set OS_UPGRADE_LIMIT to exactly one host" && exit 2)
	@test "$(OS_UPGRADE_CONFIRM)" = "true" || (echo "Refusing OS upgrade execution: set OS_UPGRADE_CONFIRM=true after reviewing docs/upgrades.md" && exit 2)
	@test "$(OS_UPGRADE_EXECUTE)" = "true" || (echo "Refusing OS upgrade execution: set OS_UPGRADE_EXECUTE=true after reviewing the vendor command" && exit 2)
	@test -n "$(OS_UPGRADE_TARGET_DISTRIBUTION)" || (echo "Refusing OS upgrade execution: set OS_UPGRADE_TARGET_DISTRIBUTION" && exit 2)
	@test -n "$(OS_UPGRADE_TARGET_MAJOR)" || (echo "Refusing OS upgrade execution: set OS_UPGRADE_TARGET_MAJOR" && exit 2)
	@test -n "$(OS_UPGRADE_COMMAND)" || (echo "Refusing OS upgrade execution: set OS_UPGRADE_COMMAND to the reviewed vendor command" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/os-upgrade-node.yml --limit "$(OS_UPGRADE_LIMIT)" --timeout $(OS_UPGRADE_TIMEOUT) --forks $(OS_UPGRADE_FORKS) -e librenms_os_upgrade_action=execute -e librenms_os_upgrade_confirm=true -e librenms_os_upgrade_execute_command=true -e librenms_os_upgrade_reboot=false -e "librenms_os_upgrade_target_distribution=$(OS_UPGRADE_TARGET_DISTRIBUTION)" -e "librenms_os_upgrade_target_major=$(OS_UPGRADE_TARGET_MAJOR)" -e "librenms_os_upgrade_command=$(OS_UPGRADE_COMMAND)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

os-upgrade-execute: os-upgrade-node

mariadb-upgrade-preflight:
	@test -n "$(MARIADB_UPGRADE_LIMIT)" || (echo "Refusing MariaDB upgrade preflight: set MARIADB_UPGRADE_LIMIT to exactly one DB host" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/mariadb-upgrade-preflight.yml --limit "$(MARIADB_UPGRADE_LIMIT)" --timeout $(MARIADB_UPGRADE_TIMEOUT) --forks $(MARIADB_UPGRADE_FORKS) $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

runtime-upgrade:
	@test -n "$(RUNTIME_UPGRADE_LIMIT)" || (echo "Refusing runtime upgrade: set RUNTIME_UPGRADE_LIMIT to exactly one host" && exit 2)
	@test "$(RUNTIME_UPGRADE_CONFIRM)" = "true" || (echo "Refusing runtime upgrade: set RUNTIME_UPGRADE_CONFIRM=true after reviewing docs/upgrades.md" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/runtime-upgrade.yml --limit "$(RUNTIME_UPGRADE_LIMIT)" --timeout $(RUNTIME_UPGRADE_TIMEOUT) --forks $(RUNTIME_UPGRADE_FORKS) -e librenms_runtime_upgrade_action=execute -e librenms_runtime_upgrade_confirm=true -e "librenms_runtime_upgrade_components=$(RUNTIME_UPGRADE_COMPONENTS)" -e librenms_runtime_upgrade_mariadb_confirm=$(RUNTIME_UPGRADE_MARIADB_CONFIRM) $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

runtime-upgrade-ask-become-pass:
	@test -n "$(RUNTIME_UPGRADE_LIMIT)" || (echo "Refusing runtime upgrade: set RUNTIME_UPGRADE_LIMIT to exactly one host" && exit 2)
	@test "$(RUNTIME_UPGRADE_CONFIRM)" = "true" || (echo "Refusing runtime upgrade: set RUNTIME_UPGRADE_CONFIRM=true after reviewing docs/upgrades.md" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/runtime-upgrade.yml --ask-become-pass --become-method sudo --limit "$(RUNTIME_UPGRADE_LIMIT)" --timeout $(INTERACTIVE_BECOME_TIMEOUT) --forks $(INTERACTIVE_BECOME_FORKS) -e librenms_runtime_upgrade_action=execute -e librenms_runtime_upgrade_confirm=true -e "librenms_runtime_upgrade_components=$(RUNTIME_UPGRADE_COMPONENTS)" -e librenms_runtime_upgrade_mariadb_confirm=$(RUNTIME_UPGRADE_MARIADB_CONFIRM) $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

# Refresh only the socket-activated Galera readiness agent and clear stale
# probe workers. This does not touch MariaDB data or run site convergence.
readiness-repair:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/readiness-repair.yml --limit "$(READINESS_REPAIR_LIMIT)" --timeout $(READINESS_REPAIR_TIMEOUT) --forks $(READINESS_REPAIR_FORKS) $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

readiness-repair-ask-become-pass:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/readiness-repair.yml --ask-become-pass --limit "$(READINESS_REPAIR_LIMIT)" --timeout $(INTERACTIVE_BECOME_TIMEOUT) --forks $(INTERACTIVE_BECOME_FORKS) $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

# Install and validate the native foreground RRDCacheD systemd drop-in without
# starting or stopping the service. This is safe to run before a controlled
# reboot of a node whose old daemon is stuck in kernel I/O.
rrdcached-unit-repair:
	@test "$(RRDCACHED_UNIT_REPAIR_CONFIRM)" = "true" || (echo "Refusing RRDCacheD unit repair: set RRDCACHED_UNIT_REPAIR_CONFIRM=true after reviewing docs/fast-repair.md" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/rrdcached-unit-repair.yml --limit "$(RRDCACHED_UNIT_REPAIR_LIMIT)" --timeout $(RRDCACHED_UNIT_REPAIR_TIMEOUT) --forks $(RRDCACHED_UNIT_REPAIR_FORKS) -e librenms_rrdcached_unit_repair_confirm=true $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

rrdcached-unit-repair-ask-become-pass:
	@test "$(RRDCACHED_UNIT_REPAIR_CONFIRM)" = "true" || (echo "Refusing RRDCacheD unit repair: set RRDCACHED_UNIT_REPAIR_CONFIRM=true after reviewing docs/fast-repair.md" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/rrdcached-unit-repair.yml --ask-become-pass --become-method sudo --limit "$(RRDCACHED_UNIT_REPAIR_LIMIT)" --timeout $(INTERACTIVE_BECOME_TIMEOUT) --forks $(INTERACTIVE_BECOME_FORKS) -e librenms_rrdcached_unit_repair_confirm=true $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

# Bounded runtime repair. This deliberately does not run site.yml, bootstrap
# Galera, run migrations, or alter MariaDB data.
repair:
	@test "$(FAST_REPAIR_CONFIRM)" = "true" || (echo "Refusing repair: set FAST_REPAIR_CONFIRM=true after reviewing docs/fast-repair.md" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/fast-repair.yml --limit "$(FAST_REPAIR_LIMIT)" --timeout $(FAST_REPAIR_TIMEOUT) --forks $(FAST_REPAIR_FORKS) -e librenms_fast_repair_confirm=true -e ansible_become_timeout=$(FAST_REPAIR_BECOME_TIMEOUT) -e librenms_fast_repair_manager_attempts=$(FAST_REPAIR_MANAGER_ATTEMPTS) -e librenms_fast_repair_manager_probe_timeout=$(FAST_REPAIR_MANAGER_PROBE_TIMEOUT) $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

repair-ask-become-pass:
	@test "$(FAST_REPAIR_CONFIRM)" = "true" || (echo "Refusing repair: set FAST_REPAIR_CONFIRM=true after reviewing docs/fast-repair.md" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/fast-repair.yml --ask-become-pass --become-method sudo --limit "$(FAST_REPAIR_LIMIT)" --timeout $(FAST_REPAIR_BECOME_TIMEOUT) --forks $(FAST_REPAIR_FORKS) -e librenms_fast_repair_confirm=true -e ansible_become_timeout=$(FAST_REPAIR_BECOME_TIMEOUT) -e librenms_fast_repair_manager_attempts=$(FAST_REPAIR_MANAGER_ATTEMPTS) -e librenms_fast_repair_manager_probe_timeout=$(FAST_REPAIR_MANAGER_PROBE_TIMEOUT) $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

repair-check:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/fast-repair-check.yml --limit "$(FAST_REPAIR_LIMIT)" --timeout $(FAST_REPAIR_TIMEOUT) --forks $(FAST_REPAIR_FORKS) $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

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
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/galera-recover.yml $(PLAYBOOK_FLAGS) -e librenms_galera_recover_bootstrap_host=$(GALERA_RECOVER_BOOTSTRAP_HOST) -e librenms_galera_recover_confirm=$(GALERA_RECOVER_CONFIRM) $(GALERA_RECOVER_TIE_BREAKER_ARG) $(ANSIBLE_EXTRA_ARGS)

galera-recover-ask-become-pass:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/galera-recover.yml --ask-become-pass --timeout $(INTERACTIVE_BECOME_TIMEOUT) --forks $(INTERACTIVE_BECOME_FORKS) $(PLAYBOOK_FLAGS) -e librenms_galera_recover_bootstrap_host=$(GALERA_RECOVER_BOOTSTRAP_HOST) -e librenms_galera_recover_confirm=$(GALERA_RECOVER_CONFIRM) $(GALERA_RECOVER_TIE_BREAKER_ARG) $(ANSIBLE_EXTRA_ARGS)

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

production-readiness-ask-become-pass:
	$(ANSIBLE_PLAYBOOK) -i $(HA_INVENTORY) playbooks/production-readiness.yml --ask-become-pass --become-method sudo --timeout $(INTERACTIVE_BECOME_TIMEOUT) --forks $(INTERACTIVE_BECOME_FORKS) $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

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
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/galera-recover.yml $(PLAYBOOK_FLAGS) -e librenms_galera_recover_bootstrap_host=$(GALERA_RECOVER_BOOTSTRAP_HOST) -e librenms_galera_recover_confirm=$(GALERA_RECOVER_CONFIRM) $(GALERA_RECOVER_TIE_BREAKER_ARG) $(ANSIBLE_EXTRA_ARGS)

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

docker-production-readiness-ask-become-pass:
	$(DOCKER_ANSIBLE) ansible-playbook -i $(HA_INVENTORY) playbooks/production-readiness.yml --ask-become-pass --timeout $(INTERACTIVE_BECOME_TIMEOUT) --forks $(INTERACTIVE_BECOME_FORKS) $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

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
