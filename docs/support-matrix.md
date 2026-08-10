# Support Matrix and Production Readiness

This repository aims to be practical rather than vague: it separates what is
expected to work, what should be lab-tested first, and what still needs an
operator decision.

## Distribution Tiers

Upstream LibreNMS installation examples currently cover Ubuntu 24.04, Ubuntu
22.04, Debian 12, Debian 13, and CentOS 8. This repository also validates the
following production-targeted release families: Ubuntu 22.04/24.04/26.04,
Debian 12/13, and Red Hat Enterprise Linux, Rocky Linux, and AlmaLinux 8/9/10.
Primary support means this repository owns the platform mappings and CI
guardrails. It does not mean Red Hat certification or that a package-container
test substitutes for the live production-readiness gates.

### What is and is not fully certified

Ubuntu 26.04 and RHEL-family 8/9/10 are **implemented primary targets**, not a
blanket certification for every image, minor release, repository subscription,
architecture, or HA storage design. The repository's public CI covers Ubuntu
22.04/24.04/26.04 and Rocky/Alma Linux 8/9/10 package surfaces plus selected
managed-runtime checks. It cannot exercise subscription-only RHEL repositories or prove a
customer's network, SELinux policy, storage export, and three-node failure
behavior. Treat an exact RHEL host as production-ready only after the subscribed
host acceptance run and the live readiness, reboot, maintenance, backup/restore,
and failover gates below pass.

RHEL 8 has an additional implementation constraint: its supported DNF bindings
are tied to the distribution's platform Python, while the pinned Ansible
controller requires a newer target Python. The playbook therefore uses the
managed Python runtime for Ansible and the native `dnf` CLI for EL8 package
transactions. This is intentional and is covered by guardrail tests; it still
needs an exact subscribed-RHEL convergence test before production approval.

The distro MariaDB stream is also an explicit part of the support contract:
Ubuntu 22.04 uses 10.6, Ubuntu 24.04 uses 10.11, Ubuntu 26.04 uses 11.8, and
RHEL-family 8/9/10 uses the vendor 10.11 stream. The MariaDB role checks the
installed series during convergence and stops before a silent stream change.
Upstream MariaDB 11.4/11.8/12.3 remains an explicit Debian-family option for
fresh local installs; upstream Galera is limited to 11.4/11.8 and is not a
generic upgrade path for an existing cluster.

| Distro family | Tier | Expected state | Before production |
| --- | --- | --- | --- |
| Ubuntu LTS (22.04, 24.04, 26.04) | Primary | Debian-family mappings; Ubuntu 22.04 explicitly selects PHP 8.3 from the documented Ondrej PHP repository, while Ubuntu 24.04/26.04 use their native supported stream. Distro MariaDB is guarded at 10.6/10.11/11.8 respectively. | Run the full HA command sequence and one node-maintenance drill. |
| Debian stable | Primary | Best fit with upstream LibreNMS examples and package names. | Run the full HA command sequence and one node-maintenance drill. |
| Linux Mint | Primary-ish | Uses Debian-family logic. | Validate package names, PHP-FPM service name, and firewall behavior in a lab. |
| RHEL / Red Hat Enterprise Linux (8.10+, 9.4+, 10.x) | Primary source path | Uses the tested EL mappings, including firewalld, enforcing SELinux, EL8 managed Python, EL10 Valkey, and the vendor MariaDB 10.11 stream. Subscription-only repositories are not exercised in public CI. | Run package resolution and all live readiness/failover gates on subscribed RHEL images. |
| AlmaLinux (8.10+, 9.4+, 10.x) | Primary | Package-resolution CI covers all three majors and the common EL runtime path. | Run the live HA readiness, reboot, maintenance, and failover gates on the exact image. |
| Rocky Linux (8.10+, 9.4+, 10.x) | Primary | Package-resolution CI covers all three majors and the common EL runtime path. | Run the live HA readiness, reboot, maintenance, and failover gates on the exact image. |
| Fedora | Strong best-effort | RedHat-family mappings exist, but package cadence is faster. | Pin package sources or test every upgrade in a lab first. |
| CentOS / CentOS Stream | Best-effort | Package availability can vary by stream and mirror. | Expect repo and PHP tuning. Validate before every production use. |
| Arch Linux / Manjaro | Best-effort | Package names and service defaults can drift quickly. | Treat as lab-first. Expect overrides. |
| Alpine Linux | Best-effort | Package and service model differs from systemd-first paths. | Expect OpenRC/service overrides and more manual validation. |
| Gentoo | Best-effort | Package atoms and service behavior vary by profile. | Expect package and service overrides. |

The common role validates the selected major release and the installed runtime
versions during convergence. Set `librenms_runtime_support_enabled: false` only
for a deliberate lab or vendor-supported exception; disabling it does not make
an unsupported combination production-ready.

The automated package matrix runs Ubuntu 22.04/24.04/26.04 plus Rocky Linux and
AlmaLinux 8/9/10 containers. It verifies the distro-sensitive package set,
service units and configuration paths, EL module streams, Galera package,
firewall/SELinux tooling, EL8 Python 3.11 bootstrap, and EL10 Valkey commands
and units. A separate SSH-based integration check uses the pinned controller to
bootstrap fresh Ubuntu 22.04/24.04/26.04, Rocky 8/9/10, and AlmaLinux 8/9/10 targets,
gather facts through the managed Python runtime, and exercise each target
package manager. Full systemd, VRRP, Galera, Sentinel, enforcing SELinux, and
storage behavior still requires the project playbooks on real VMs. The
maintained CI and examples target x86_64; other architectures are not a
declared production target.

The package smoke script also accepts exact `ID=rhel` targets. On subscribed
RHEL 8.10, 9.4, and 10.x hosts it installs the signed EPEL release package and
fails early unless CodeReady Builder is enabled. Public CI does not exercise
that source path because it cannot hold Red Hat subscription credentials. The
managed-runtime smoke script accepts `rhel:*`,
`registry.access.redhat.com/*`, and `registry.redhat.io/*` images when the
operator supplies registry access and licensing.

Run the exact RHEL package acceptance on each subscribed managed host from a
Linux controller before the first deployment and after an OS or repository
change. The script is deliberately executed on the target, so it sees the
real RHEL repositories and package metadata rather than a Rocky/Alma
substitute:

```bash
make platform-acceptance PLATFORM_ACCEPTANCE_CONFIRM=true

# Or limit the explicit acceptance run to a named inventory group/host:
make platform-acceptance PLATFORM_ACCEPTANCE_CONFIRM=true \
  PLATFORM_ACCEPTANCE_LIMIT=lnms1

# Equivalent direct Ansible invocation:
ansible librenms_nodes -i inventories/ha/hosts.yml -b \
  -m ansible.builtin.script \
  -a tests/platform/package-smoke.sh
```

The `make` target runs serially and refuses to run without the explicit
confirmation variable because package installation may start or restart
distribution services. It is an acceptance check, not a routine daily task.

For full HA, run this only after setting `librenms_rrd_mode: external`, a
reviewed `librenms_external_rrd_source` with `librenms_external_rrd_fstype:
nfs4`, and the same fixed `librenms_uid`/`librenms_gid` on every node. The
package acceptance does not replace the live HA readiness, reboot, maintenance,
Galera, Sentinel, SELinux, and NFS outage drills below.

The sample HA inventory includes an explicit `rhel_external_nfs` group profile.
Add every RHEL web/DB/Redis/LB node to that group to select external NFS/NFSv4
automatically; then set `librenms_external_rrd_source` in
`inventories/ha/group_vars/rhel_external_nfs.yml` to the reviewed export. The
source is intentionally empty in the repository, so a RHEL deployment fails
closed before mounting until the export and fixed UID/GID mapping are supplied.

The controller requires ansible-core 2.20 or newer. Ubuntu 26.04 uses Python
3.14 on the managed host, whose target support starts with ansible-core 2.20.
Run `make controller-bootstrap` to install the repository's hash-locked
ansible-core 2.21.2 toolchain under `.ansible/controller-venv`; Make targets
automatically select it.

RHEL-family 8, 9, and 10 cannot use this repository's in-node Gluster server
topology because the repositories managed by this project do not provide a
supported `glusterfs-server` package. For full HA, use
`librenms_rrd_mode: external` with a reviewed NFS/NFSv4 source and fixed shared
`librenms_uid`/`librenms_gid` values. Standalone local RRD mode remains valid
when shared HA storage is not required.

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
| Python | 3.9 through 3.14 | 3.14 | EL8 is bootstrapped onto managed Python 3.11; all target hosts receive the pinned LibreNMS runtime set (`PyMySQL`, `python-dotenv`, `redis`, `setuptools`, `psutil`, and `command_runner`); CI also installs the pinned controller toolchain on Python 3.14. |
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

For the declared RHEL-family production path, the role deliberately selects the
vendor MariaDB 10.11 stream (`librenms_redhat_mariadb_stream: "10.11"`) and
the corresponding `mariadb-server-galera` package. Site convergence now
verifies the installed RHEL-family server reports series 10.11 and fails before
configuration if a different stream is present. Newer RHEL 9 and RHEL 10 minor
releases also expose MariaDB 11.8, but this repository does not auto-select or certify that version.
Selecting 11.8 requires a separate, version-specific
package, Galera, upgrade, and rollback validation before it can be treated as
supported.

## Topology Support

| Topology | Support level | Notes |
| --- | --- | --- |
| Standalone LibreNMS | Primary | Single-node install with local database, local Redis/cache, and local RRD storage. Backups are still required. |
| Distributed LibreNMS app/poller nodes with external DB/Redis/storage | Primary | Good fit when database, Redis, or storage are managed outside this repo. |
| Full three-node HA with HAProxy, Keepalived, Galera, Redis/Valkey Sentinel, and shared RRD storage | Primary on primary distros | The main target. Ubuntu/Debian may use GlusterFS; RHEL-family 8/9/10 require externally managed NFS/NFSv4 storage. Requires regular drills and backups. |
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
| Live network paths | Web, Galera, Redis/Sentinel, and the selected shared RRD storage paths are reachable between expected peers. Gluster ports are checked only in Gluster mode; NFS/NFSv4 access is checked through the mounted RRD path in external mode. | `playbooks/doctor.yml -e librenms_doctor_network_tcp_checks_enabled=true` |
| Deployment convergence | Config and services converge without failed tasks. | `playbooks/cluster.yml` |
| HA status | VIP, HAProxy, Keepalived, Galera, Redis/Sentinel, the selected shared RRD mount, scheduler, dispatcher, and writable paths are healthy. Gluster health is included only in Gluster mode. | `playbooks/status.yml -e librenms_status_alert_fail_on_degraded=true` |
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
| One Gluster peer stopped (Gluster mode only) | Replicated volume should remain available if quorum and replica layout allow it. | RRD writes may slow while the storage layer heals. | RRD mount disappears from surviving app nodes. |
| External NFS/NFSv4 server or export unavailable | The cluster should report the shared RRD mount as degraded; it must not silently fall back to local RRD storage. | Graph writes and some maintenance tasks pause until the export is available again. | The mount is missing but HA status remains healthy, or local storage is used as an implicit replacement. |
| One whole node powered off hard | Surviving nodes should keep VIP, DB, Redis, and poller service available after detection windows. | Browser requests can wait on TCP timeout, Redis failover, or backend retry. | 2-3 minute outage after tuning and clean HA status. |
| Full cluster powered off and started again | Boot-time repair and `post-reboot.yml` should converge services and the selected shared RRD storage without a redeploy. | Several minutes of red validation while Galera, Redis, the selected storage, and dispatchers settle. | No Galera Primary, no Redis master, no shared RRD mount, or no active dispatcher after convergence windows. |

## Behavior Limits

The project can reduce downtime, but it cannot make every failure instant.

| Area | Limit | Practical mitigation |
| --- | --- | --- |
| Hard power-off detection | The surviving stack must wait for TCP, VRRP, HAProxy, Galera, Redis Sentinel, and client retry timers. | Use `maintenance-enter.yml` for planned work. Tune HAProxy checks and Redis Sentinel timers only after measuring. |
| Browser sessions | Existing requests can be pinned to a backend that disappears. | Keep HAProxy health checks fast and use application-safe retry behavior. |
| Redis Sentinel | Failover is quorum-based and intentionally not instantaneous. | Keep three Sentinels reachable, avoid stopping two Redis nodes, and run Redis failover drills. |
| Galera quorum | A three-node cluster tolerates one DB node loss, not arbitrary two-node loss. | Never power off a second Galera node until the first is Synced again. |
| Gluster quorum/heal (Gluster mode only) | Storage availability depends on replica and quorum behavior, not only this playbook. | Monitor Gluster heal state and keep backups outside the cluster. |
| External NFS/NFSv4 availability | The playbook can validate the mount and its writability, but it cannot repair an unavailable export, network path, or NFS server. | Use redundant, monitored storage and test remount/recovery behavior independently. Keep backups outside the export. |
| RRD graph gaps | Missed polling intervals cannot be recreated later. | Verify SNMP and dispatcher recovery quickly; accept that outage intervals remain gaps. |
| LibreNMS validation | Validation checks application state and can show stale dispatcher rows during node-loss tests. | Wait for dispatcher heartbeat cleanup or use `maintenance_nodes` for intentional offline nodes. |
| Best-effort distros | Family mappings may not match every package, service, or security policy. | Override variables and lab-test before production. |

## Operator-Reviewed by Design

These tasks intentionally require human review:

- Galera disaster bootstrap after a total outage.
- Gluster peer or brick recovery after storage failure.
- External NFS/NFSv4 export, server, or authorization changes.
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
