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
- Added disposable database-import verification to restore tests and an
  opt-in AWX weekly restore-test schedule that selects the newest managed daily
  backup instead of relying on a hard-coded timestamp.
- Added SHA-256 artifact checksums to managed and manual backup manifests,
  checksum verification before restore imports, and post-copy checksum
  comparison for offsite rsync backups.
- Added an opt-in AWX monthly failover-drill schedule with explicit service-stop
  confirmation and a restricted set of supported test cases.
- Added a disposable five-container Redis Sentinel integration test that proves
  master election and a post-failover cache write in GitHub Actions.
- Added a disposable HAProxy web integration test that proves requests continue
  through the remaining backend after one web service stops.
- Added a Galera readiness-agent decision test that rejects `Non-Primary`,
  non-ready, donor, and inactive MariaDB nodes before HAProxy can route to them.
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
- Added GitHub issue forms and a pull request checklist for bug reports,
  HA/failover failures, LibreNMS validation failures, feature requests, and
  operator-safe reviews.
- Added cold-boot service recovery defaults so startup repair can reset failed
  HA units and start Gluster, Galera, Redis/Sentinel, RRDCacheD, HAProxy, and
  Keepalived before LibreNMS runtime gates evaluate the app layer.

### Changed

- Enabled guarded HA database recovery for managed PHP-FPM workers. The
  30-second startup repair timer now tracks database readiness transitions,
  gracefully reloads stale workers only after a successful database probe, and
  retries rate-limited recovery instead of prematurely marking it handled.
- Changed HA daily maintenance so only the node holding the shared maintenance
  lock enters HAProxy drain mode; competing timer runs no longer drain all web
  backends before they discover the lock is busy.
- Expanded `Makefile` with operator targets for pre-maintenance, post-change,
  post-restart, failover drill, diagnostics, status, maintenance, Galera
  recovery, restore testing, and Docker equivalents.
- Expanded GitHub Actions linting to include YAML parsing, Markdown link checks,
  sample inventory validation, and Ansible syntax-check orchestration.
- Added runtime dependency gating for LibreNMS dispatcher, scheduler, and daily
  maintenance units so they can wait for DB, Redis, and RRD storage after cold
  boot.
- Enabled Galera safe primary-component recovery by default and made Redis and
  Redis Sentinel systemd restart timing configurable for cleaner power-on
  convergence.
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
