# Support Matrix and Production Readiness

This repository aims to be practical rather than vague: it separates what is
expected to work, what should be lab-tested first, and what still needs an
operator decision.

## Distribution Tiers

Upstream LibreNMS installation examples currently cover Ubuntu 24.04, Ubuntu
22.04, Debian 12, Debian 13, and CentOS 8. This repository also validates the
following production-targeted release families: Ubuntu 22.04/24.04/26.04,
Debian 12/13, and Red Hat Enterprise Linux, Rocky Linux, and AlmaLinux 8/9/10.
The package stream and vendor repository still need to be validated on the
exact target image before a production declaration.

| Distro family | Tier | Expected state | Before production |
| --- | --- | --- | --- |
| Ubuntu LTS (22.04, 24.04, 26.04) | Primary | Best fit with upstream LibreNMS examples and package names. | Run the full HA command sequence and one node-maintenance drill. |
| Debian stable | Primary | Best fit with upstream LibreNMS examples and package names. | Run the full HA command sequence and one node-maintenance drill. |
| Linux Mint | Primary-ish | Uses Debian-family logic. | Validate package names, PHP-FPM service name, and firewall behavior in a lab. |
| RHEL / Red Hat Enterprise Linux (8, 9, 10) | Strong best-effort | RedHat-family mappings exist. | Validate repositories, PHP extensions, SELinux policy, service names, and Galera packaging. |
| AlmaLinux (8, 9, 10) | Strong best-effort | RedHat-family mappings exist. | Validate repositories, PHP extensions, SELinux policy, service names, and Galera packaging. |
| Rocky Linux (8, 9, 10) | Strong best-effort | RedHat-family mappings exist. | Validate repositories, PHP extensions, SELinux policy, service names, and Galera packaging. |
| Fedora | Strong best-effort | RedHat-family mappings exist, but package cadence is faster. | Pin package sources or test every upgrade in a lab first. |
| CentOS / CentOS Stream | Best-effort | Package availability can vary by stream and mirror. | Expect repo and PHP tuning. Validate before every production use. |
| Arch Linux / Manjaro | Best-effort | Package names and service defaults can drift quickly. | Treat as lab-first. Expect overrides. |
| Alpine Linux | Best-effort | Package and service model differs from systemd-first paths. | Expect OpenRC/service overrides and more manual validation. |
| Gentoo | Best-effort | Package atoms and service behavior vary by profile. | Expect package and service overrides. |

The common role validates the selected major release and the installed runtime
versions during convergence. Set `librenms_runtime_support_enabled: false` only
for a deliberate lab or vendor-supported exception; disabling it does not make
an unsupported combination production-ready.

New major distro releases should still start as lab-only until the full checklist
passes. For example, an Ubuntu 24.04 to 26.04 upgrade should be tested one node
at a time with the major-upgrade workflow before being treated as production
ready.

## Application Runtime Versions

The role checks the versions actually installed on each managed host. It does
not replace the distribution or LibreNMS package resolver, and it does not
override Composer constraints. For an exact newer package, configure the
vendor-supported repository before running the playbook.

| Runtime | Supported production series | Requested target | Verification |
| --- | --- | --- | --- |
| nginx | 1.18 through 1.31 | 1.31.x | `nginx -v` during common convergence; the HAProxy web integration uses nginx 1.31.3. |
| PHP | 8.2 through 8.5 | 8.5 | The PHP CLI runtime used alongside PHP-FPM is detected on managed web nodes. |
| Python | 3.10 through 3.14 | 3.14 | Managed hosts are checked during convergence; CI also installs the pinned controller toolchain on Python 3.14. |
| Laravel | 12 and 13 | 13 | The resolved `laravel/framework` version is read from the installed Composer autoloader. |
| RRDtool | 1.7 through 1.10 | 1.10.x | The installed `rrdtool --version` series is checked before service configuration. |

## MariaDB Series

The default `distro` mode follows the operating system's package stream. The
optional MariaDB Community repository mode is Debian-family only and requires
an immutable SHA-256 checksum for the repository setup script. Confirm lifecycle
and package details against the [MariaDB 11.4 release notes](https://mariadb.com/docs/release-notes/community-server/11.4),
[MariaDB 11.8 release notes](https://mariadb.com/docs/release-notes/community-server/11.8),
and [MariaDB 12.3 release notes](https://mariadb.com/docs/release-notes/community-server/12.3)
before planning a major-series change.

| MariaDB series | Local/standalone Community repo | Built-in Galera profile | Notes |
| --- | --- | --- | --- |
| 11.4 | Supported | Supported | Long-term series; use for a fresh or explicitly planned HA deployment. |
| 11.8 | Supported | Supported | Long-term series; recommended Community-repository choice for new Galera deployments. |
| 12.3 | Supported | Not supported by this repository's Community package path | MariaDB 12.3 is a long-term Community Server series, but its Community repository does not ship the Galera package required by this role. |

The playbook never changes an installed major series during normal convergence.
Use the documented maintenance and upgrade procedure, with an off-cluster
backup and a tested restore, for every major-series change.

## Topology Support

| Topology | Support level | Notes |
| --- | --- | --- |
| Standalone LibreNMS | Primary | Single-node install with local database, local Redis/cache, and local RRD storage. Backups are still required. |
| Distributed LibreNMS app/poller nodes with external DB/Redis/storage | Primary | Good fit when database, Redis, or storage are managed outside this repo. |
| Full three-node HA with HAProxy, Keepalived, Galera, Redis Sentinel, and GlusterFS | Primary on primary distros | The main target of this repository. Requires regular drills and backups. |
| Dockerized HA example | Lab/example | Useful for learning and CI-style validation. Disposable HAProxy web-backend, three-node Galera continuity, and Redis Sentinel election tests run in CI; this is not a complete production container platform. |
| AWX controller | Optional management plane | Supported as a separate controller-side service. It has its own backup and upgrade lifecycle. |

## Production Readiness Gates

Do not call a cluster production-ready until these gates pass.

| Gate | Required proof | Command or source |
| --- | --- | --- |
| Inventory shape | Inventory validates and all role groups match the intended topology. | `python3 scripts/validate-inventory.py --inventory inventories/ha/hosts.yml --group-vars inventories/ha/group_vars/all.yml` |
| YAML and local checks | Repository YAML and helper scripts parse cleanly. | `python3 scripts/ci-parse-yaml.py`, `make ci` on a Linux controller |
| Source governance | Protected `main`, green required GitHub checks, no open security alerts, private vulnerability reporting, Dependabot security updates, and CodeQL enabled. | GitHub repository Security and branch-protection settings |
| Preflight | OS, package, disk, memory, time, VIP, and route checks pass. | `playbooks/doctor.yml` |
| Live network paths | Web, Galera, Redis/Sentinel, and Gluster ports are reachable between expected peers. | `playbooks/doctor.yml -e librenms_doctor_network_tcp_checks_enabled=true` |
| Deployment convergence | Config and services converge without failed tasks. | `playbooks/cluster.yml` |
| HA status | VIP, HAProxy, Keepalived, Galera, Redis/Sentinel, Gluster, scheduler, dispatcher, and writable paths are healthy. | `playbooks/status.yml -e librenms_status_alert_fail_on_degraded=true` |
| Application validation | LibreNMS validation is clean. | `playbooks/validate.yml` |
| Backup and restore-test | A backup exists, its SHA-256 manifest and archives validate, and its database dump imports into a disposable database that is removed afterwards. | `playbooks/backup.yml`, `playbooks/restore-test.yml` |
| Readiness evidence | A successful full readiness run leaves a secret-free, root-readable JSON record plus verified SHA-256 and HMAC-SHA256 sidecars. The retained record must also pass the root-only controller verifier without exposing the app key. | `playbooks/production-readiness.yml`, `/usr/local/sbin/librenms-production-readiness-evidence-verify --evidence <record>` |
| Post-reboot convergence | A full cluster restart settles without rerunning `cluster.yml`. | `playbooks/post-reboot.yml` |
| Planned one-node maintenance | One node can be drained, powered down/rebooted, rejoined, and validated. | `maintenance-enter.yml`, `maintenance-exit.yml`, `validate.yml` |
| Failover drill | Web/VIP drill passes; data-layer drills pass during a maintenance window. | `playbooks/ha-failover-test.yml` |
| Diagnostics path | Operators know where bundles are written and can collect one during an incident. | `playbooks/diagnostics.yml` |

## Expected HA Behavior

| Event | Expected behavior | Normal transient impact | Not normal |
| --- | --- | --- | --- |
| One web/app node stopped gracefully | HAProxy removes it and the VIP continues serving through remaining nodes. | Existing sessions to that backend may retry or reconnect. | Multi-minute VIP outage or all web backends marked down. |
| Current VIP owner stopped gracefully | Keepalived moves the VIP to another eligible load balancer. | A short ARP/TCP reconnection window. | VIP absent after the configured advert/failover window. |
| One LibreNMS dispatcher stopped | Another dispatcher should keep queue work moving if Redis and DB are healthy. | LibreNMS validation may briefly show stale dispatcher rows. | No active dispatcher remains after the retry window. |
| Redis master stopped | Sentinel elects a new master and clients reconnect. | Cache, queue, and lock operations can retry during election. | Sentinels disagree on master or no Redis node accepts writes. |
| One Galera member stopped | Remaining members stay Primary/Synced and HAProxy routes DB traffic to live backends. | Some connections to the stopped member fail and reconnect. | Cluster loses Primary component with two nodes still reachable. |
| One Gluster peer stopped | Replicated volume should remain available if quorum and replica layout allow it. | RRD writes may slow while the storage layer heals. | RRD mount disappears from surviving app nodes. |
| One whole node powered off hard | Surviving nodes should keep VIP, DB, Redis, and poller service available after detection windows. | Browser requests can wait on TCP timeout, Redis failover, or backend retry. | 2-3 minute outage after tuning and clean HA status. |
| Full cluster powered off and started again | Boot-time repair and `post-reboot.yml` should converge services without a redeploy. | Several minutes of red validation while Galera, Redis, Gluster, and dispatchers settle. | No Galera Primary, no Redis master, or no active dispatcher after convergence windows. |

## Behavior Limits

The project can reduce downtime, but it cannot make every failure instant.

| Area | Limit | Practical mitigation |
| --- | --- | --- |
| Hard power-off detection | The surviving stack must wait for TCP, VRRP, HAProxy, Galera, Redis Sentinel, and client retry timers. | Use `maintenance-enter.yml` for planned work. Tune HAProxy checks and Redis Sentinel timers only after measuring. |
| Browser sessions | Existing requests can be pinned to a backend that disappears. | Keep HAProxy health checks fast and use application-safe retry behavior. |
| Redis Sentinel | Failover is quorum-based and intentionally not instantaneous. | Keep three Sentinels reachable, avoid stopping two Redis nodes, and run Redis failover drills. |
| Galera quorum | A three-node cluster tolerates one DB node loss, not arbitrary two-node loss. | Never power off a second Galera node until the first is Synced again. |
| Gluster quorum/heal | Storage availability depends on replica and quorum behavior, not only this playbook. | Monitor Gluster heal state and keep backups outside the cluster. |
| RRD graph gaps | Missed polling intervals cannot be recreated later. | Verify SNMP and dispatcher recovery quickly; accept that outage intervals remain gaps. |
| LibreNMS validation | Validation checks application state and can show stale dispatcher rows during node-loss tests. | Wait for dispatcher heartbeat cleanup or use `maintenance_nodes` for intentional offline nodes. |
| Best-effort distros | Family mappings may not match every package, service, or security policy. | Override variables and lab-test before production. |

## Operator-Reviewed by Design

These tasks intentionally require human review:

- Galera disaster bootstrap after a total outage.
- Gluster peer or brick recovery after storage failure.
- Destructive node removal from DB, Redis, or storage membership.
- Major OS release upgrades.
- SELinux or local security hardening changes.
- Changing Galera, Redis Sentinel, or Gluster quorum behavior.

Use `diagnostics.yml` before repeated recovery attempts so the first failure
state is preserved. For symptom-driven incident triage, use
[failure-scenarios.md](failure-scenarios.md).

## Minimum Production Runbook

For a healthy existing HA cluster before planned maintenance:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/doctor.yml \
  --ask-become-pass \
  -e librenms_doctor_network_tcp_checks_enabled=true
ansible-playbook -i inventories/ha/hosts.yml playbooks/status.yml \
  --ask-become-pass \
  -e librenms_status_alert_fail_on_degraded=true
ansible-playbook -i inventories/ha/hosts.yml playbooks/backup.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml --ask-become-pass
```

If any step fails, collect diagnostics before changing another layer:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/diagnostics.yml --ask-become-pass
```

Then fix the failing layer and restart from the failed step.
