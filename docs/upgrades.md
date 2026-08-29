# Upgrade Workflows

This repository provides guarded upgrade entry points for operating-system
release preflight, Nginx repository/version selection, MariaDB package
selection, and PHP stream selection. It does not turn a normal `site.yml` run into an unattended major
upgrade: a major OS upgrade can reboot a host, and a Galera major-version
change needs a tested backup and rollback plan.

## Operating-System Releases

The supported in-place transition matrix is:

| Current family | Supported transition |
| --- | --- |
| Ubuntu | 22 -> 24 and 24 -> 26 |
| Debian | 12 -> 13 |
| RHEL, Rocky, or AlmaLinux | 8 -> 9 and 9 -> 10 |

The workflow must be limited to exactly one host. It validates the current
release and target transition, but the distribution vendor remains responsible
for the actual release upgrade. No task in this workflow reboots a host.

First enter maintenance and complete an off-host backup. Then run the
read-only preflight from the Linux Ansible controller:

Keep the target reachable and out of the inventory `maintenance_nodes` group
while running this workflow; the upgrade playbooks exclude that group. If the
node is listed there because it is offline, remove it from the group and
restore reachability before starting the preflight.

```bash
make os-upgrade-preflight \
  OS_UPGRADE_LIMIT=lnms1 \
  OS_UPGRADE_TARGET_DISTRIBUTION=Ubuntu \
  OS_UPGRADE_TARGET_MAJOR=26 \
  PLAYBOOK_FLAGS=--ask-become-pass
```

For an EL-family node, use the actual vendor family and major being targeted,
for example `Rocky` and `9`, or `RHEL` and `10`. The role maps supported EL
aliases to one Red Hat-family transition policy and rejects cross-family or
skipped-release changes.

After the preflight output and the vendor's rollback procedure have been
reviewed, the optional execution entry point can run one explicitly supplied
vendor command:

```bash
make os-upgrade-node \
  OS_UPGRADE_LIMIT=lnms1 \
  OS_UPGRADE_TARGET_DISTRIBUTION=Ubuntu \
  OS_UPGRADE_TARGET_MAJOR=26 \
  OS_UPGRADE_CONFIRM=true \
  OS_UPGRADE_EXECUTE=true \
  OS_UPGRADE_COMMAND='vendor-reviewed-command' \
  PLAYBOOK_FLAGS=--ask-become-pass
```

Use the vendor-supported release tool from a console or an approved
non-interactive wrapper. For example, Ubuntu's `do-release-upgrade` and the
RHEL-family `leapp` workflow have their own interactive, reboot, repository,
and rollback requirements; this role does not replace those requirements.
`OS_UPGRADE_COMMAND` is intentionally operator-supplied and is not stored in
the repository.

After the vendor upgrade and operator-controlled reboot, wait for SSH and run:

```bash
make maintenance-exit MAINTENANCE_TARGET=lnms1 \
  PLAYBOOK_FLAGS=--ask-become-pass
make cluster PLAYBOOK_FLAGS=--ask-become-pass
make post-reboot PLAYBOOK_FLAGS=--ask-become-pass
make status-strict PLAYBOOK_FLAGS=--ask-become-pass
make validate PLAYBOOK_FLAGS=--ask-become-pass
```

Proceed one node at a time. Do not start the next node until Galera is `Primary/Synced`, Redis Sentinel
has a single writable master, the RRD storage is healthy, the load-balancer
VIP is owned by a live node, and validation is clean. Run the same sequence in
a lab before using a new OS release in production.

## Nginx Repository and Version Selection

The default is the distribution package stream:

```yaml
librenms_nginx_repository_mode: distro
librenms_nginx_channel: distro
librenms_nginx_package_state: present
librenms_nginx_package_version: ""
```

This works through the Debian/Ubuntu and RHEL-family package mappings. To use
the official Nginx repository, select `stable` or `mainline`, enable reviewed
extra repositories, and pin the signing-key fingerprint before running
convergence:

```yaml
librenms_enable_extra_repos: true
librenms_nginx_repository_mode: official
librenms_nginx_channel: stable       # or mainline
librenms_nginx_package_state: latest # or present
librenms_nginx_package_version: ""
librenms_nginx_expected_series: "1.31" # optional runtime guard
librenms_nginx_official_repository_key_fingerprint: "<reviewed-40-hex-fingerprint>"
```

The role verifies the downloaded key before enabling the repository. Do not
copy a fingerprint from an untrusted source or leave it empty. Verify that
Nginx publishes the selected channel for the exact OS release and architecture
first; the repository does not promise that every future OS/repository
combination exists.

For an exact package-manager version, set `librenms_nginx_package_version` and
leave `librenms_nginx_package_state: present`. Debian/Ubuntu use the APT
version syntax; EL uses the RPM version-release syntax. The exact value must
be available in the selected repository on every node before convergence.

## MariaDB Package Selection

MariaDB selection is separate from an in-place major upgrade:

```yaml
# Distribution-managed stream, safest default.
librenms_mariadb_selection_mode: distro

# Latest package inside the configured distro repository or stream.
librenms_mariadb_selection_mode: latest

# Explicit Community-repository series on Debian-family hosts.
librenms_mariadb_selection_mode: specific
librenms_mariadb_selected_series: "11.8"
```

Supported explicit Community-repository series are `11.4`, `11.8`, and
`12.3`. `lts` selects `librenms_mariadb_lts_series`, which defaults to `11.8`.
On Debian-family hosts, `specific` and `lts` enable the project-managed
MariaDB repository path and require the operator to provide the immutable
SHA-256 checksum for `mariadb_repo_setup`. On RHEL, Rocky, and AlmaLinux,
selection uses the distribution's MariaDB module/stream map where the vendor
provides one. EL8 is restricted to the validated `10.11` stream; EL9 supports
the mapped `10.11` and `11.8` streams. EL10 uses its native package stream and
the role validates the installed series; it does not silently switch an EL10
MariaDB major without a separately reviewed repository and Galera contract.

For an upstream Debian-family selection, configure the repository setup
checksum and, for `latest`, the stream to update within:

```yaml
librenms_mariadb_repository_mode: upstream
librenms_mariadb_selection_mode: latest
librenms_mariadb_upstream_series: "11.8"
librenms_mariadb_upstream_repo_setup_checksum: "sha256:<reviewed-64-hex-digest>"
```

The `latest` mode updates packages inside the selected repository or vendor
stream. It is not permission to cross a MariaDB major series. Normal
convergence checks the installed series and stops before an unsafe major
change. EL `specific`/`lts` selections also require
`librenms_enable_extra_repos: true` so the selected module stream is actually
configured and verified. For Galera, use the version-specific rolling runbook and upgrade one
member at a time:

```bash
make mariadb-upgrade-preflight \
  MARIADB_UPGRADE_LIMIT=lnms1 \
  PLAYBOOK_FLAGS=--ask-become-pass
```

This preflight is read-only. It does not stop MariaDB, change Galera state,
run `mariadb-upgrade`, modify packages, or write `/var/lib/mysql`. For the
existing 10.11 to 12.3 Galera path, follow
[mariadb-10.11-to-12.3.md](mariadb-10.11-to-12.3.md), including the required
backup, package/provider checks, maintenance drain, and rollback decision.

Do not set a new major series in the inventory and run `make site` against an
existing Galera cluster. A major upgrade is a maintenance operation, not a
package refresh.

## Bounded Runtime Package Refresh

For an existing node that only needs newer Nginx, PHP, or packages within its
currently installed MariaDB series, use the package-only workflow. It does not
run `site.yml`, change the operating-system release, switch a MariaDB major
series, bootstrap Galera, or reboot the node.

Enter maintenance for exactly one node first. The workflow requires the marker
created by `maintenance-enter.yml`, refreshes only the selected components, and
checks the active service, PHP-FPM socket, Nginx configuration, and Galera
state where applicable:

Do not add the target to the inventory `maintenance_nodes` group while it is
reachable. That group is excluded from the runtime-upgrade playbook; the
maintenance marker is the control that authorizes this bounded package
operation.

```bash
make maintenance-enter \
  MAINTENANCE_TARGET=lnms2 \
  PLAYBOOK_FLAGS=--ask-become-pass

make runtime-upgrade-ask-become-pass \
  RUNTIME_UPGRADE_LIMIT=lnms2 \
  RUNTIME_UPGRADE_COMPONENTS=php \
  RUNTIME_UPGRADE_CONFIRM=true
```

`RUNTIME_UPGRADE_COMPONENTS` accepts `nginx`, `php`, and `mariadb` as a
comma-separated list. The default is `nginx,php`; MariaDB requires a second
explicit acknowledgement:

```bash
make runtime-upgrade-ask-become-pass \
  RUNTIME_UPGRADE_LIMIT=lnms2 \
  RUNTIME_UPGRADE_COMPONENTS=mariadb \
  RUNTIME_UPGRADE_CONFIRM=true \
  RUNTIME_UPGRADE_MARIADB_CONFIRM=true
```

MariaDB refreshes are same-series only. A requested `specific` or `lts` series
must already match the installed server series; a major change belongs in the
version-specific rolling Galera runbook. Configure Nginx stable/mainline,
exact package versions, or PHP specific/latest selectors in inventory before
the run. Repository-backed selections still require the signed repository and
reviewed key/checksum settings described above.

For PHP, `specific` selects a versioned Debian/Ubuntu package stream or the
reviewed Remi stream on EL8/9:

```yaml
librenms_php_selection_mode: specific
librenms_php_version: "8.5"
```

Ubuntu 22 uses the managed versioned PHP PPA stream (8.3 by default) even in
`latest` mode. Ubuntu 24/26 and EL10 use their native package stream unless an
explicit supported repository path is configured. Exact PHP selection is
intentionally rejected on EL10 because this role does not implement a safe
native stream switch there.

After each node is healthy, rejoin it and verify the cluster before touching
the next node:

```bash
make maintenance-exit MAINTENANCE_TARGET=lnms2 \
  PLAYBOOK_FLAGS=--ask-become-pass
make status-strict PLAYBOOK_FLAGS=--ask-become-pass
make validate PLAYBOOK_FLAGS=--ask-become-pass
```

Do not use this workflow for a PHP or MariaDB major transition that the
selected distribution stream cannot provide. Preflight the repository and
version first, and keep one node out of service until all checks pass.

## Scope and Safety

The upgrade entry points are deliberately explicit:

- `os-upgrade-preflight` is read-only and requires one target host and a
  supported adjacent release transition.
- `os-upgrade-node` requires an explicit confirmation, command, target, and
  single-host limit; it never reboots automatically.
- `mariadb-upgrade-preflight` is read-only and requires one database host.
- `runtime-upgrade` and `runtime-upgrade-ask-become-pass` require one node in
  maintenance and an explicit confirmation; they perform package-only runtime
  refreshes with post-change health checks.
- Nginx repository changes require a selected channel and a pinned signing-key
  fingerprint.
- PHP exact 8.4/8.5 selection on EL8/9 requires an explicitly reviewed Remi
  release package; EL10 remains native-stream only in this role.
- Normal HA convergence still owns service configuration and health checks,
  but it does not perform a distribution release upgrade or Galera major
  upgrade.
