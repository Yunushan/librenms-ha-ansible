# Changelog

## Unreleased

### Added

- Added HA runtime status reporting through `playbooks/status.yml`, including
  VIP ownership, HAProxy/Keepalived state, Galera, Redis Sentinel, GlusterFS,
  LibreNMS dispatcher and scheduler state, writable-path drift, unit drift, and
  optional webhook alerting.
- Added post-reboot convergence automation through `playbooks/post-reboot.yml`
  so operators can verify full-cluster power-on recovery without rerunning the
  full deployment playbook.
- Added planned node maintenance workflows through
  `playbooks/maintenance-enter.yml` and `playbooks/maintenance-exit.yml` for
  safer one-node shutdowns, upgrades, and rejoins.
- Added guarded Galera recovery through `playbooks/galera-recover.yml` with
  explicit confirmation, recovered-position ranking, and manual bootstrap-host
  selection.
- Added diagnostics bundle collection through `playbooks/diagnostics.yml` for
  failed validation, failover, maintenance, and post-reboot investigations.
- Added restore-readiness checks through `playbooks/restore-test.yml` so backup
  archives can be verified before relying on them.
- Added live network route and TCP matrix checks to `playbooks/doctor.yml` for
  HA ports used by web, Galera, Redis/Sentinel, and GlusterFS.
- Added additional HA failover drill cases for HAProxy service loss, dispatcher
  service loss, Redis master failover, and one Galera node outage.
- Added optional AWX bootstrap automation through `playbooks/awx-bootstrap.yml`
  for baseline project, inventory, source, and job-template creation.
- Added local CI helper scripts for YAML parsing, Markdown local link checking,
  inventory validation, and playbook syntax checks.
- Added operator documentation for failure scenarios, major OS upgrades,
  support tiers, command ordering, maintenance windows, diagnostics, and
  post-reboot behavior.
- Added operator checklist templates for common pre-flight checks, planned
  single-node maintenance, hard power-off tests, full cluster restarts, and
  failed validation triage.
- Added commented HA inventory examples for `maintenance_nodes`, live doctor
  checks, status alerts, failover drill targeting, diagnostics tuning,
  restore-test inputs, and guarded Galera recovery variables.
- Added an operator command map that matches common tasks and symptoms to the
  safest playbook or Make target.
- Added `scripts/ci-python-smoke.py` and `make python-smoke` for Python-only
  local checks that do not require Ansible.
- Added a local pre-commit `python-smoke` hook and contributor instructions for
  running the smoke checks before pushing.
- Added a maintainer release checklist covering local gates, inventory examples,
  documentation, operational safety, and release notes.
- Added a documentation index with a recommended reading order and task map for
  operator and maintainer docs.

### Changed

- Expanded `Makefile` with operator targets for pre-maintenance, post-change,
  post-restart, failover drill, diagnostics, status, maintenance, Galera
  recovery, restore testing, and Docker equivalents.
- Expanded GitHub Actions linting to include YAML parsing, Markdown link checks,
  sample inventory validation, and Ansible syntax-check orchestration.
- Added runtime dependency gating for LibreNMS dispatcher, scheduler, and daily
  maintenance units so they can wait for DB, Redis, and RRD storage after cold
  boot.
- Improved LibreNMS validation handling for Galera-backed schema consistency,
  Redis Sentinel runtime checks, poller registration convergence, and
  intentionally unavailable maintenance nodes.

### Operator Notes

- Major OS upgrades remain intentionally manual. Use the documented rolling
  upgrade path: enter maintenance for one node, upgrade with the distro vendor
  tooling, rejoin, validate, then continue to the next node.
- Hard power-off tests should use `maintenance_nodes` for intentionally offline
  hosts so status and validation distinguish planned absence from real failure.
- `make syntax-check` requires `ansible-playbook` on the controller. Windows
  operators should run it from WSL, a Linux controller, or the project Docker
  image.

## 0.1.0
- initial GitHub-ready Ansible project
- standalone and HA inventory examples
- modular roles for LibreNMS, MariaDB, Galera, Redis Sentinel, HAProxy, Keepalived, GlusterFS, and SNMP
- add-node and remove-node workflows
