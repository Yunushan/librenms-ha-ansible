# Repository Production-Readiness Assessment

This assessment scores the repository implementation, not a particular running
cluster. A live cluster is production-ready only after the required commands in
[support-matrix.md](support-matrix.md#production-readiness-gates) pass against
its real inventory.

## Current Source Score: 87 / 100

The score reflects the safeguards implemented and statically checked in this
repository. It is intentionally conservative: no source review can prove real
network paths, storage behavior, or recovery under load.

| Area | Score | Evidence and remaining limitation |
| --- | ---: | --- |
| Secrets and configuration safety | 16 / 20 | Inventory validation, vault-oriented examples, placeholder checks, constrained MariaDB binding, and required offsite backup configuration exist. A real secrets-manager integration and host firewall enforcement still need environment-specific verification. |
| HA design and failure containment | 18 / 20 | Three-member Galera and Sentinel expectations, HAProxy/Keepalived checks, shared maintenance-lock and RRD-mount verification, and strict application probes are present. CI proves HAProxy continues serving through the remaining web backend, Redis Sentinel elects a writable master, and the Galera readiness gate rejects unsuitable members. Actual VIP takeover, Galera quorum, Gluster healing, and timing still require a live drill. |
| Backup and recovery | 14 / 15 | Scheduled and manual backups record SHA-256 artifact digests; restore and go-live checks reject checksum mismatches before archive parsing or disposable database imports. Offsite rsync copies receive a checksum comparison after transfer. Recovery point and recovery time objectives must still be measured using the production backup target. |
| Upgrade safety | 14 / 15 | Daily updates serialize with a shared lock, drain only the lock-holding node, repair Git metadata, validate Composer and schema work, and can be disabled or version-pinned. A staging promotion pipeline remains preferable for organizations that cannot accept unattended release updates. |
| Automated quality assurance | 14 / 15 | GitHub Actions, the Docker lint image, and pre-commit share pinned core tooling; Ansible collections, the Docker base image, and GitHub Actions are pinned. Both CI toolchain installation paths run `pip check`, CI builds the controller image and runs `make ci` inside it, and Dependabot proposes monthly updates for supported dependency ecosystems. CI runs daily-maintenance drain-ordering, Galera readiness-agent, HAProxy web failover, and five-container Redis Sentinel election/write tests on every change. |
| Operations and observability | 11 / 15 | Status, diagnostics, recovery, backup, restore-test, maintenance, and production-readiness playbooks are documented. AWX can optionally manage a weekly restore-test schedule and an explicitly enabled monthly failover drill during an approved maintenance window. Alert routing, centralized logs, external monitoring, and on-call response targets must be established per deployment. |

## What Prevents a Higher Source Score

- No automated multi-node deployment test validates Galera, GlusterFS, HAProxy,
  and Keepalived together on every change.
- The experimental Docker Galera example now fails closed until an operator
  supplies an approved immutable image digest, but it is not a production
  container orchestration implementation or a CI-proven Galera deployment.
- CI proves HAProxy web-backend continuity plus Redis Sentinel election and a
  post-failover write, but does not yet run the existing Ansible fault-injection
  role or prove VIP takeover, Galera quorum, and Gluster healing. The optional
  AWX drill still needs live evidence.
- Python CI pins the core tools, but is not a hash-locked dependency supply
  chain. Use an organization-managed package mirror or a fully hash-locked
  build environment where that level of control is required.
- No repository-only test can prove the actual production DNS, TLS certificate,
  firewall rules, offsite backup target, capacity, or operator response.

## Path to Production Certification

Run the source checks first:

```bash
python3 -m pip install --requirement requirements-ci.txt
make ci
```

Then execute the live certification on the Ansible controller:

```bash
make production-readiness PLAYBOOK_FLAGS=--ask-become-pass
```

Finally, complete the planned maintenance and failover drills in the
[production readiness gates](support-matrix.md#production-readiness-gates).
Record the command output, timestamps, recovery times, and any deviations in
the operational change record. Only that evidence can raise a deployment from
repository-ready to production-certified.
