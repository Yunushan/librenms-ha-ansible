.PHONY: controller-bootstrap install lint yaml-parse docs-check python-smoke syntax-check inventory-check github-governance-check ci test-controller-collection-bootstrap test-galera-readiness test-galera-bootstrap-guardrails test-mariadb-series-guardrails test-runtime-support-guardrails test-platform-support-guardrails test-redis-sentinel-consensus-guardrails test-daily-maintenance-guardrails test-runtime-web-health-guardrails test-outage-recovery-guardrails test-failover-recovery-guardrails test-load-balancer-rollout-guardrails test-production-readiness-evidence-guardrails test-production-readiness-evidence-verifier test-awx-status-schedule-guardrails test-host-firewall-guardrails test-gluster-rrd-mount-guardrails test-post-reboot-rrdcached-guardrails test-fast-repair-guardrails test-github-governance-guardrails test-docker-ha-galera-config integration-platform-runtime integration-galera integration-haproxy-web integration-redis-sentinel standalone platform-bootstrap-ask-become-pass site site-ask-become-pass readiness-repair readiness-repair-ask-become-pass rrdcached-unit-repair rrdcached-unit-repair-ask-become-pass repair repair-ask-become-pass repair-check cluster doctor doctor-live status status-strict post-reboot maintenance-enter maintenance-exit galera-recover galera-recover-ask-become-pass ha-failover-test firewall backup restore-test validate production-readiness production-readiness-ask-become-pass diagnostics pre-maintenance post-change post-restart failover-drill upgrade-node-exit awx-controller awx-bootstrap os-upgrade-preflight os-upgrade-node os-upgrade-execute mariadb-upgrade-preflight runtime-upgrade runtime-upgrade-ask-become-pass test-upgrade-selector-guardrails docker-build docker-lint docker-python-smoke docker-shell docker-standalone docker-cluster docker-doctor docker-doctor-live docker-status docker-status-strict docker-post-reboot docker-maintenance-enter docker-maintenance-exit docker-galera-recover docker-ha-failover-test docker-backup docker-restore-test docker-validate docker-production-readiness docker-production-readiness-ask-become-pass docker-diagnostics docker-pre-maintenance docker-post-change docker-post-restart docker-failover-drill docker-upgrade-node-exit docker-awx-controller docker-awx-bootstrap
.PHONY: test-maintenance-stop-guardrails
.PHONY: test-post-reboot-service-guardrails

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

# Optional container and Kubernetes profiles use a separate inventory. They
# never become part of the package-based HA site workflow.
PLATFORM_INVENTORY ?= inventories/platforms/hosts.yml
CONTAINER_PLATFORM_LIMIT ?=
CONTAINER_PLATFORM_ACTION ?= preflight
CONTAINER_PLATFORM_CONFIRM ?= false
CONTAINER_PLATFORM_BECOME ?= false
CONTAINER_PLATFORM_EXAMPLES_ROOT ?= /opt/librenms-ha-ansible/examples/docker-ha
KUBERNETES_PLAYBOOK ?= kubernetes.yml
KUBERNETES_LIMIT ?= localhost
KUBERNETES_PLATFORM ?= kubernetes
KUBERNETES_ACTION ?= preflight
KUBERNETES_VALUES_FILE ?=
KUBERNETES_NAMESPACE ?= librenms
KUBERNETES_RELEASE ?= librenms
KUBERNETES_KUBECONFIG ?=
KUBERNETES_CONTEXT ?=
KUBERNETES_CONFIRM ?= false
KUBERNETES_TIMEOUT ?= 10m
KUBERNETES_CONNECTION_TIMEOUT ?= 30
K3S_LIMIT ?= k3s_nodes
K3S_ACTION ?= preflight
K3S_CONFIRM ?= false
K3S_NODE_ROLE ?= server
K3S_VERSION ?=
K3S_INSTALL_URL ?= https://get.k3s.io
K3S_INSTALL_CHECKSUM ?=
K3S_BOOTSTRAP_HOST ?=
K3S_SERVER_URL ?=
K3S_TIMEOUT ?= 120
RKE2_LIMIT ?= rke2_nodes
RKE2_ACTION ?= preflight
RKE2_CONFIRM ?= false
RKE2_NODE_ROLE ?= server
RKE2_VERSION ?=
RKE2_INSTALL_URL ?= https://get.rke2.io
RKE2_INSTALL_CHECKSUM ?=
RKE2_BOOTSTRAP_HOST ?=
RKE2_SERVER_URL ?=
RKE2_TIMEOUT ?= 120
MICROK8S_LIMIT ?= microk8s_nodes
MICROK8S_ACTION ?= preflight
MICROK8S_CONFIRM ?= false
MICROK8S_NODE_ROLE ?= primary
MICROK8S_PRIMARY_HOST ?=
MICROK8S_CHANNEL ?=
MICROK8S_JOIN_ENDPOINT ?=
MICROK8S_TIMEOUT ?= 120
KUBESPRAY_ACTION ?= preflight
KUBESPRAY_DIRECTORY ?=
KUBESPRAY_INVENTORY ?=
KUBESPRAY_CONFIRM ?= false
KUBESPRAY_TIMEOUT ?= 120
KUBEONE_ACTION ?= preflight
KUBEONE_MANIFEST ?=
KUBEONE_CONFIRM ?= false
KUBEONE_TIMEOUT ?= 120
GARDENER_ACTION ?= preflight
GARDENER_GARDEN ?=
GARDENER_PROJECT ?=
GARDENER_SHOOT ?=
GARDENER_KUBECONFIG_DESTINATION ?=
GARDENER_CONFIRM ?= false
GARDENER_TIMEOUT ?= 120

.PHONY: docker-ha docker-ha-ask-become-pass podman-ha podman-ha-ask-become-pass kubernetes k3s-app rke2-app microk8s-app okd-app kubespray-app kubeone-app gardener-app k3s k3s-ask-become-pass rke2 rke2-ask-become-pass microk8s microk8s-ask-become-pass kubespray kubeone gardener test-optional-platform-guardrails test-helm-chart

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

ci: python-smoke lint syntax-check test-controller-collection-bootstrap test-galera-readiness test-galera-bootstrap-guardrails test-mariadb-series-guardrails test-upgrade-selector-guardrails test-runtime-support-guardrails test-platform-support-guardrails test-redis-sentinel-consensus-guardrails test-daily-maintenance-guardrails test-runtime-web-health-guardrails test-outage-recovery-guardrails test-failover-recovery-guardrails test-load-balancer-rollout-guardrails test-production-readiness-evidence-guardrails test-production-readiness-evidence-verifier test-awx-status-schedule-guardrails test-host-firewall-guardrails test-gluster-rrd-mount-guardrails test-post-reboot-rrdcached-guardrails test-fast-repair-guardrails test-github-governance-guardrails test-optional-platform-guardrails

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

test-post-reboot-rrdcached-guardrails: test-post-reboot-service-guardrails
	bash tests/unit/test-post-reboot-rrdcached-guardrails.sh

test-post-reboot-service-guardrails:
	bash tests/unit/test-post-reboot-service-guardrails.sh

test-fast-repair-guardrails: test-maintenance-stop-guardrails
	bash tests/unit/test-fast-repair-guardrails.sh

test-maintenance-stop-guardrails:
	bash tests/unit/test-maintenance-stop-guardrails.sh

test-github-governance-guardrails:
	bash tests/unit/test-github-governance-guardrails.sh

test-docker-ha-galera-config:
	bash tests/unit/test-docker-ha-galera-config.sh

test-optional-platform-guardrails:
	bash tests/unit/test-optional-platform-guardrails.sh

test-helm-chart:
	bash tests/unit/test-helm-chart.sh

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

# Optional container profiles. The target is intentionally separate from
# site/standalone so a container experiment cannot touch the HA VM inventory.
docker-ha:
	@test -n "$(CONTAINER_PLATFORM_LIMIT)" || (echo "Refusing Docker profile: set CONTAINER_PLATFORM_LIMIT" && exit 2)
	@test "$(CONTAINER_PLATFORM_ACTION)" = "preflight" || test "$(CONTAINER_PLATFORM_ACTION)" = "status" || test "$(CONTAINER_PLATFORM_CONFIRM)" = "true" || (echo "Refusing Docker profile mutation: set CONTAINER_PLATFORM_CONFIRM=true" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(PLATFORM_INVENTORY) playbooks/docker.yml --limit "$(CONTAINER_PLATFORM_LIMIT)" --forks 1 -e "librenms_container_action=$(CONTAINER_PLATFORM_ACTION)" -e "librenms_container_confirm=$(CONTAINER_PLATFORM_CONFIRM)" -e "librenms_container_become=$(CONTAINER_PLATFORM_BECOME)" -e "librenms_container_examples_root=$(CONTAINER_PLATFORM_EXAMPLES_ROOT)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

docker-ha-ask-become-pass:
	@test -n "$(CONTAINER_PLATFORM_LIMIT)" || (echo "Refusing Docker profile: set CONTAINER_PLATFORM_LIMIT" && exit 2)
	@test "$(CONTAINER_PLATFORM_ACTION)" = "preflight" || test "$(CONTAINER_PLATFORM_ACTION)" = "status" || test "$(CONTAINER_PLATFORM_CONFIRM)" = "true" || (echo "Refusing Docker profile mutation: set CONTAINER_PLATFORM_CONFIRM=true" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(PLATFORM_INVENTORY) playbooks/docker.yml --ask-become-pass --become-method sudo --limit "$(CONTAINER_PLATFORM_LIMIT)" --forks 1 -e "librenms_container_action=$(CONTAINER_PLATFORM_ACTION)" -e "librenms_container_confirm=$(CONTAINER_PLATFORM_CONFIRM)" -e librenms_container_become=true -e "librenms_container_examples_root=$(CONTAINER_PLATFORM_EXAMPLES_ROOT)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

podman-ha:
	@test -n "$(CONTAINER_PLATFORM_LIMIT)" || (echo "Refusing Podman profile: set CONTAINER_PLATFORM_LIMIT" && exit 2)
	@test "$(CONTAINER_PLATFORM_ACTION)" = "preflight" || test "$(CONTAINER_PLATFORM_ACTION)" = "status" || test "$(CONTAINER_PLATFORM_CONFIRM)" = "true" || (echo "Refusing Podman profile mutation: set CONTAINER_PLATFORM_CONFIRM=true" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(PLATFORM_INVENTORY) playbooks/podman.yml --limit "$(CONTAINER_PLATFORM_LIMIT)" --forks 1 -e "librenms_container_action=$(CONTAINER_PLATFORM_ACTION)" -e "librenms_container_confirm=$(CONTAINER_PLATFORM_CONFIRM)" -e "librenms_container_become=$(CONTAINER_PLATFORM_BECOME)" -e "librenms_container_examples_root=$(CONTAINER_PLATFORM_EXAMPLES_ROOT)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

podman-ha-ask-become-pass:
	@test -n "$(CONTAINER_PLATFORM_LIMIT)" || (echo "Refusing Podman profile: set CONTAINER_PLATFORM_LIMIT" && exit 2)
	@test "$(CONTAINER_PLATFORM_ACTION)" = "preflight" || test "$(CONTAINER_PLATFORM_ACTION)" = "status" || test "$(CONTAINER_PLATFORM_CONFIRM)" = "true" || (echo "Refusing Podman profile mutation: set CONTAINER_PLATFORM_CONFIRM=true" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(PLATFORM_INVENTORY) playbooks/podman.yml --ask-become-pass --become-method sudo --limit "$(CONTAINER_PLATFORM_LIMIT)" --forks 1 -e "librenms_container_action=$(CONTAINER_PLATFORM_ACTION)" -e "librenms_container_confirm=$(CONTAINER_PLATFORM_CONFIRM)" -e librenms_container_become=true -e "librenms_container_examples_root=$(CONTAINER_PLATFORM_EXAMPLES_ROOT)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

# Optional Kubernetes application profile. Kubeconfig and values files are
# local to the controller; the chart never joins the package-based site role.
kubernetes:
	@test -n "$(KUBERNETES_VALUES_FILE)" || (echo "Refusing Kubernetes profile: set KUBERNETES_VALUES_FILE" && exit 2)
	@test "$(KUBERNETES_ACTION)" = "preflight" || test "$(KUBERNETES_ACTION)" = "status" || test "$(KUBERNETES_CONFIRM)" = "true" || (echo "Refusing Kubernetes mutation: set KUBERNETES_CONFIRM=true" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(PLATFORM_INVENTORY) playbooks/$(KUBERNETES_PLAYBOOK) --limit "$(KUBERNETES_LIMIT)" --timeout $(KUBERNETES_CONNECTION_TIMEOUT) --forks 1 -e "librenms_kubernetes_action=$(KUBERNETES_ACTION)" -e "librenms_kubernetes_platform=$(KUBERNETES_PLATFORM)" -e "librenms_kubernetes_confirm=$(KUBERNETES_CONFIRM)" -e "librenms_kubernetes_values_file=$(KUBERNETES_VALUES_FILE)" -e "librenms_kubernetes_namespace=$(KUBERNETES_NAMESPACE)" -e "librenms_kubernetes_release=$(KUBERNETES_RELEASE)" -e "librenms_kubernetes_timeout=$(KUBERNETES_TIMEOUT)" -e "librenms_kubernetes_kubeconfig=$(KUBERNETES_KUBECONFIG)" -e "librenms_kubernetes_context=$(KUBERNETES_CONTEXT)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

k3s-app: KUBERNETES_PLATFORM := k3s
k3s-app: kubernetes

rke2-app: KUBERNETES_PLATFORM := rke2
rke2-app: kubernetes

microk8s-app: KUBERNETES_PLATFORM := microk8s
microk8s-app: kubernetes

okd-app: KUBERNETES_PLATFORM := okd
okd-app: KUBERNETES_PLAYBOOK := okd.yml
okd-app: kubernetes

kubespray-app: KUBERNETES_PLATFORM := kubespray
kubespray-app: kubernetes

kubeone-app: KUBERNETES_PLATFORM := kubeone
kubeone-app: kubernetes

gardener-app: KUBERNETES_PLATFORM := gardener
gardener-app: kubernetes

# k3s and RKE2 install only a reviewed, checksum-pinned installer. Tokens are
# deliberately not Make variables; supply them through an Ansible Vault file.
k3s:
	@test -n "$(K3S_LIMIT)" || (echo "Refusing k3s action: set K3S_LIMIT" && exit 2)
	@test "$(K3S_ACTION)" = "preflight" || test "$(K3S_ACTION)" = "status" || test "$(K3S_CONFIRM)" = "true" || (echo "Refusing k3s mutation: set K3S_CONFIRM=true" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(PLATFORM_INVENTORY) playbooks/k3s.yml --limit "$(K3S_LIMIT)" --timeout $(K3S_TIMEOUT) --forks 1 -e "librenms_k3s_action=$(K3S_ACTION)" -e "librenms_k3s_confirm=$(K3S_CONFIRM)" -e "librenms_k3s_node_role=$(K3S_NODE_ROLE)" -e "librenms_k3s_version=$(K3S_VERSION)" -e "librenms_k3s_install_url=$(K3S_INSTALL_URL)" -e "librenms_k3s_install_checksum=$(K3S_INSTALL_CHECKSUM)" -e "librenms_k3s_bootstrap_host=$(K3S_BOOTSTRAP_HOST)" -e "librenms_k3s_server_url=$(K3S_SERVER_URL)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

k3s-ask-become-pass:
	@test -n "$(K3S_LIMIT)" || (echo "Refusing k3s action: set K3S_LIMIT" && exit 2)
	@test "$(K3S_ACTION)" = "preflight" || test "$(K3S_ACTION)" = "status" || test "$(K3S_CONFIRM)" = "true" || (echo "Refusing k3s mutation: set K3S_CONFIRM=true" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(PLATFORM_INVENTORY) playbooks/k3s.yml --ask-become-pass --become-method sudo --limit "$(K3S_LIMIT)" --timeout $(K3S_TIMEOUT) --forks 1 -e "librenms_k3s_action=$(K3S_ACTION)" -e "librenms_k3s_confirm=$(K3S_CONFIRM)" -e "librenms_k3s_node_role=$(K3S_NODE_ROLE)" -e "librenms_k3s_version=$(K3S_VERSION)" -e "librenms_k3s_install_url=$(K3S_INSTALL_URL)" -e "librenms_k3s_install_checksum=$(K3S_INSTALL_CHECKSUM)" -e "librenms_k3s_bootstrap_host=$(K3S_BOOTSTRAP_HOST)" -e "librenms_k3s_server_url=$(K3S_SERVER_URL)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

rke2:
	@test -n "$(RKE2_LIMIT)" || (echo "Refusing RKE2 action: set RKE2_LIMIT" && exit 2)
	@test "$(RKE2_ACTION)" = "preflight" || test "$(RKE2_ACTION)" = "status" || test "$(RKE2_CONFIRM)" = "true" || (echo "Refusing RKE2 mutation: set RKE2_CONFIRM=true" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(PLATFORM_INVENTORY) playbooks/rke2.yml --limit "$(RKE2_LIMIT)" --timeout $(RKE2_TIMEOUT) --forks 1 -e "librenms_rke2_action=$(RKE2_ACTION)" -e "librenms_rke2_confirm=$(RKE2_CONFIRM)" -e "librenms_rke2_node_role=$(RKE2_NODE_ROLE)" -e "librenms_rke2_version=$(RKE2_VERSION)" -e "librenms_rke2_install_url=$(RKE2_INSTALL_URL)" -e "librenms_rke2_install_checksum=$(RKE2_INSTALL_CHECKSUM)" -e "librenms_rke2_bootstrap_host=$(RKE2_BOOTSTRAP_HOST)" -e "librenms_rke2_server_url=$(RKE2_SERVER_URL)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

rke2-ask-become-pass:
	@test -n "$(RKE2_LIMIT)" || (echo "Refusing RKE2 action: set RKE2_LIMIT" && exit 2)
	@test "$(RKE2_ACTION)" = "preflight" || test "$(RKE2_ACTION)" = "status" || test "$(RKE2_CONFIRM)" = "true" || (echo "Refusing RKE2 mutation: set RKE2_CONFIRM=true" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(PLATFORM_INVENTORY) playbooks/rke2.yml --ask-become-pass --become-method sudo --limit "$(RKE2_LIMIT)" --timeout $(RKE2_TIMEOUT) --forks 1 -e "librenms_rke2_action=$(RKE2_ACTION)" -e "librenms_rke2_confirm=$(RKE2_CONFIRM)" -e "librenms_rke2_node_role=$(RKE2_NODE_ROLE)" -e "librenms_rke2_version=$(RKE2_VERSION)" -e "librenms_rke2_install_url=$(RKE2_INSTALL_URL)" -e "librenms_rke2_install_checksum=$(RKE2_INSTALL_CHECKSUM)" -e "librenms_rke2_bootstrap_host=$(RKE2_BOOTSTRAP_HOST)" -e "librenms_rke2_server_url=$(RKE2_SERVER_URL)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

microk8s:
	@test -n "$(MICROK8S_LIMIT)" || (echo "Refusing MicroK8s action: set MICROK8S_LIMIT" && exit 2)
	@test "$(MICROK8S_ACTION)" = "preflight" || test "$(MICROK8S_ACTION)" = "status" || test "$(MICROK8S_CONFIRM)" = "true" || (echo "Refusing MicroK8s mutation: set MICROK8S_CONFIRM=true" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(PLATFORM_INVENTORY) playbooks/microk8s.yml --limit "$(MICROK8S_LIMIT)" --timeout $(MICROK8S_TIMEOUT) --forks 1 -e "librenms_microk8s_action=$(MICROK8S_ACTION)" -e "librenms_microk8s_confirm=$(MICROK8S_CONFIRM)" -e "librenms_microk8s_node_role=$(MICROK8S_NODE_ROLE)" -e "librenms_microk8s_primary_host=$(MICROK8S_PRIMARY_HOST)" -e "librenms_microk8s_channel=$(MICROK8S_CHANNEL)" -e "librenms_microk8s_join_endpoint=$(MICROK8S_JOIN_ENDPOINT)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

microk8s-ask-become-pass:
	@test -n "$(MICROK8S_LIMIT)" || (echo "Refusing MicroK8s action: set MICROK8S_LIMIT" && exit 2)
	@test "$(MICROK8S_ACTION)" = "preflight" || test "$(MICROK8S_ACTION)" = "status" || test "$(MICROK8S_CONFIRM)" = "true" || (echo "Refusing MicroK8s mutation: set MICROK8S_CONFIRM=true" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(PLATFORM_INVENTORY) playbooks/microk8s.yml --ask-become-pass --become-method sudo --limit "$(MICROK8S_LIMIT)" --timeout $(MICROK8S_TIMEOUT) --forks 1 -e "librenms_microk8s_action=$(MICROK8S_ACTION)" -e "librenms_microk8s_confirm=$(MICROK8S_CONFIRM)" -e "librenms_microk8s_node_role=$(MICROK8S_NODE_ROLE)" -e "librenms_microk8s_primary_host=$(MICROK8S_PRIMARY_HOST)" -e "librenms_microk8s_channel=$(MICROK8S_CHANNEL)" -e "librenms_microk8s_join_endpoint=$(MICROK8S_JOIN_ENDPOINT)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

kubespray:
	@test -n "$(KUBESPRAY_DIRECTORY)" || (echo "Refusing Kubespray action: set KUBESPRAY_DIRECTORY" && exit 2)
	@test -n "$(KUBESPRAY_INVENTORY)" || (echo "Refusing Kubespray action: set KUBESPRAY_INVENTORY" && exit 2)
	@test "$(KUBESPRAY_ACTION)" = "preflight" || test "$(KUBESPRAY_ACTION)" = "plan" || test "$(KUBESPRAY_CONFIRM)" = "true" || (echo "Refusing Kubespray mutation: set KUBESPRAY_CONFIRM=true" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(PLATFORM_INVENTORY) playbooks/kubespray.yml --limit localhost --timeout $(KUBESPRAY_TIMEOUT) --forks 1 -e "librenms_kubespray_action=$(KUBESPRAY_ACTION)" -e "librenms_kubespray_confirm=$(KUBESPRAY_CONFIRM)" -e "librenms_kubespray_directory=$(KUBESPRAY_DIRECTORY)" -e "librenms_kubespray_inventory=$(KUBESPRAY_INVENTORY)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

kubeone:
	@test -n "$(KUBEONE_MANIFEST)" || (echo "Refusing KubeOne action: set KUBEONE_MANIFEST" && exit 2)
	@test "$(KUBEONE_ACTION)" = "preflight" || test "$(KUBEONE_ACTION)" = "plan" || test "$(KUBEONE_CONFIRM)" = "true" || (echo "Refusing KubeOne mutation: set KUBEONE_CONFIRM=true" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(PLATFORM_INVENTORY) playbooks/kubeone.yml --limit localhost --timeout $(KUBEONE_TIMEOUT) --forks 1 -e "librenms_kubeone_action=$(KUBEONE_ACTION)" -e "librenms_kubeone_confirm=$(KUBEONE_CONFIRM)" -e "librenms_kubeone_manifest=$(KUBEONE_MANIFEST)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

gardener:
	@test "$(GARDENER_ACTION)" = "preflight" || test "$(GARDENER_ACTION)" = "status" || test "$(GARDENER_ACTION)" = "kubeconfig" || (echo "Refusing Gardener action: use preflight, status, or kubeconfig" && exit 2)
	@test "$(GARDENER_ACTION)" = "preflight" || test -n "$(GARDENER_GARDEN)" || (echo "Refusing Gardener action: set GARDENER_GARDEN" && exit 2)
	@test "$(GARDENER_ACTION)" = "preflight" || test -n "$(GARDENER_PROJECT)" || (echo "Refusing Gardener action: set GARDENER_PROJECT" && exit 2)
	@test "$(GARDENER_ACTION)" = "preflight" || test -n "$(GARDENER_SHOOT)" || (echo "Refusing Gardener action: set GARDENER_SHOOT" && exit 2)
	@test "$(GARDENER_ACTION)" != "kubeconfig" || test -n "$(GARDENER_KUBECONFIG_DESTINATION)" || (echo "Refusing Gardener kubeconfig export: set GARDENER_KUBECONFIG_DESTINATION" && exit 2)
	@test "$(GARDENER_ACTION)" != "kubeconfig" || test "$(GARDENER_CONFIRM)" = "true" || (echo "Refusing Gardener kubeconfig export: set GARDENER_CONFIRM=true" && exit 2)
	$(ANSIBLE_PLAYBOOK) -i $(PLATFORM_INVENTORY) playbooks/gardener.yml --limit localhost --timeout $(GARDENER_TIMEOUT) --forks 1 -e "librenms_gardener_action=$(GARDENER_ACTION)" -e "librenms_gardener_confirm=$(GARDENER_CONFIRM)" -e "librenms_gardener_garden=$(GARDENER_GARDEN)" -e "librenms_gardener_project=$(GARDENER_PROJECT)" -e "librenms_gardener_shoot=$(GARDENER_SHOOT)" -e "librenms_gardener_kubeconfig_destination=$(GARDENER_KUBECONFIG_DESTINATION)" $(PLAYBOOK_FLAGS) $(ANSIBLE_EXTRA_ARGS)

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
