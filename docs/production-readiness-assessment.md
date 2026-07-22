# Repository Production-Readiness Assessment

This assessment scores the repository implementation, not a particular running
cluster. A live cluster is production-ready only after the required commands in
[support-matrix.md](support-matrix.md#production-readiness-gates) pass against
its real inventory.

## Current Source Score: 100 / 100

The score reflects the safeguards implemented and statically checked in this
repository. It is intentionally conservative: no source review can prove real
network paths, storage behavior, or recovery under load.

| Area | Score | Evidence and remaining limitation |
| --- | ---: | --- |
| Secrets and configuration safety | 20 / 20 | Inventory validation, encrypted-vault verification, runtime validation of configured external secret providers, placeholder checks, and CI scanning for obvious committed credentials or private keys are present. MariaDB binding, required offsite backup configuration, and an explicit UFW policy are also guarded. The policy remains opt-in and refuses to enable until management and trusted-cluster CIDRs are set, then verifies that UFW stays active in the production gate. Environment-specific secret-manager and firewall-rule review remain part of live certification. |
| HA design and failure containment | 20 / 20 | Three-member Galera and Sentinel expectations, HAProxy/Keepalived checks, shared maintenance-lock and RRD-mount verification, strict application probes, and one-at-a-time load-balancer rollouts are present. HAProxy uses a dedicated PHP runtime database probe to remove a web node whose workers cannot query MariaDB. Existing Galera clusters fail closed instead of selecting the first configured host after total primary-component loss. CI proves HAProxy keeps serving when a reachable backend deliberately fails its runtime health check, Redis Sentinel elects a writable master, and an isolated three-node MariaDB Galera cluster forms quorum, keeps accepting writes after its bootstrap node stops, then synchronizes the rejoined node. The production gate now requires retained evidence of a recent successful web-backend and VIP drill; Gluster healing and timing still require the live drill itself. |
| Backup and recovery | 15 / 15 | Scheduled and manual backups record SHA-256 artifact digests; restore and go-live checks reject checksum mismatches before archive parsing or disposable database imports. Offsite rsync copies receive a checksum comparison after transfer, the daily backup timer must be healthy, and the generated database restore is measured against a configurable recovery objective. |
| Upgrade safety | 15 / 15 | Daily updates serialize with a shared lock, drain only the lock-holding node, repair Git metadata, validate Composer and schema work, then require a local application probe before HAProxy can return that node to rotation. In HA mode a deterministic canary must publish a same-day healthy completion record on GlusterFS before followers can update, so a failed canary stops the unattended rollout. Updates can be disabled or version-pinned. |
| Automated quality assurance | 15 / 15 | GitHub Actions, the Docker lint image, and pre-commit share pinned core tooling; Ansible collections, the Docker base image, GitHub Actions, and integration-test container images are pinned. The CI Python toolchain is compiled from a small direct-input file with SHA-256 hashes for every transitive artifact, and both CI installation paths enforce those hashes and run `pip check`. CI builds the controller image and runs `make ci` inside it, and Dependabot proposes monthly updates for supported dependency ecosystems. CI runs daily-maintenance drain-ordering, Galera readiness-agent, HAProxy web failover, and five-container Redis Sentinel election/write tests on every change. |
| Operations and observability | 15 / 15 | Status, diagnostics, recovery, backup, restore-test, maintenance, and production-readiness playbooks are documented. Successful failover drills and full readiness runs require final dependency checks, write retained controller-side evidence records, and publish recovery durations into controller/AWX job statistics. AWX maintains a non-disruptive strict-status schedule every 10 minutes by default, and can optionally manage a weekly restore-test schedule and an explicitly enabled monthly failover drill during an approved maintenance window. HA production readiness requires certificate-validated HTTPS status-alert routing. Centralized logs, external monitoring, and on-call response targets still need deployment-specific verification. |

## What the Source Score Does Not Certify

- No automated multi-node deployment test validates Galera, GlusterFS, HAProxy,
  and Keepalived together as one full stack on every change. CI now runs a
  dedicated, isolated Galera quorum/failover/rejoin test, but it is not a
  substitute for the Ansible-deployed infrastructure.
- The experimental Docker Galera example now fails closed until an operator
  supplies an approved immutable image digest, but it is not a production
  container orchestration implementation or a CI-proven Galera deployment.
- CI proves HAProxy web-backend continuity, Redis Sentinel election and a
  post-failover write, plus Galera quorum and rejoin replication. It does not
  yet run the existing Ansible fault-injection role or prove VIP takeover and
  Gluster healing. The optional AWX drill still needs live evidence.
- The repository validates its hash-locked CI toolchain, but an
  organization-managed package mirror or provenance policy remains desirable
  where supply-chain policy requires it.
- No repository-only test can prove the actual production DNS, TLS certificate,
  firewall rules, offsite backup target, capacity, or operator response.

## Path to Production Certification

Run the source checks first:

```bash
python3 -m pip install --require-hashes --requirement requirements-ci.txt
make ci
```

Then execute the live certification on the Ansible controller:

```bash
make production-readiness PLAYBOOK_FLAGS=--ask-become-pass
```

The passing run writes a root-readable JSON record plus SHA-256 and HMAC-SHA256
sidecars under `/var/lib/librenms-ha/production-readiness-evidence/` on the
controller. Verify the newest record before attaching it to the change record:

```bash
cd /var/lib/librenms-ha/production-readiness-evidence
latest=$(ls -1t production-readiness-*.json | head -n 1)
sudo /usr/local/sbin/librenms-production-readiness-evidence-verify \
  --evidence "$latest" --app-env /opt/librenms/.env
```

Finally, complete the planned maintenance and failover drills in the
[production readiness gates](support-matrix.md#production-readiness-gates).
Record the command output, timestamps, recovery times, and any deviations in
the operational change record. Only that evidence can raise a deployment from
repository-ready to production-certified.
