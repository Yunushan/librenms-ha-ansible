# MariaDB 10.11 to 12.3 Galera Upgrade

This runbook upgrades an existing three-node LibreNMS Galera cluster from
MariaDB 10.11 to MariaDB 12.3 without replacing `/var/lib/mysql`. It is a
controlled rolling migration, not a normal `site.yml` convergence operation.

MariaDB requires rolling Galera upgrades to move through each supported major
or LTS series. Use this sequence:

```text
10.11 -> 11.4 -> 11.8 -> 12.3
```

Do not set the inventory directly to `12.3` while 10.11 is installed and then
run `make site`. The role intentionally rejects that mismatch.

## Safety Properties

- Only one Galera node is upgraded at a time.
- The other two nodes must remain `Primary`, `ready`, and `Synced`.
- A node is not returned to HA rotation until it has rejoined and passed
  validation.
- The existing database directory is retained. Never delete or recreate
  `/var/lib/mysql` during this procedure.
- A verified database backup outside the three-node cluster is required.

This procedure minimizes service interruption, but it cannot guarantee zero
interruption during an unexpected second-node failure. Schedule a maintenance
window and keep a tested restore path available.

## Preconditions

Before scheduling the final `12.3` hop, verify that the exact package candidate
is listed as Stable/GA in the official MariaDB release schedule. Stop when the
candidate is Preview, Beta, or RC, or when the series overview and release page
disagree about its maturity. Rehearse the complete upgrade against a restored
copy of the production backup before changing the first production node.

Run from the Ansible controller:

```bash
cd /home/ansible/librenms-ha-ansible
git pull --ff-only
make status-strict
make validate
```

Confirm every database member reports one three-node Primary component:

```bash
ansible librenms_db -i inventories/ha/hosts.yml -b -m shell -a \
  "mysql -Nse \"SHOW GLOBAL STATUS WHERE Variable_name IN ('wsrep_cluster_size','wsrep_cluster_status','wsrep_connected','wsrep_ready','wsrep_local_state_comment');\""
```

Expected on all three nodes:

```text
wsrep_cluster_size        3
wsrep_cluster_status      Primary
wsrep_connected           ON
wsrep_ready               ON
wsrep_local_state_comment Synced
```

Stop if any node differs. Diagnose and repair the current 10.11 cluster before
starting a version migration.

Converge the current release once before the migration so every member has the
managed rolling-maintenance drain and a persistent GCache large enough for the
site's maintenance window:

```bash
make site
ansible librenms_db -i inventories/ha/hosts.yml -b -m shell -a \
  "grep -E 'gcache.recover=yes|gcache.size=' /etc/mysql/mariadb.conf.d/60-galera.cnf; df -h /var/lib/mysql"
```

The repository default is `librenms_galera_gcache_size: 2G` per member. Increase
it before the migration when the peak Galera write rate multiplied by the
longest expected single-node maintenance window exceeds 2 GiB. Keep additional
free space for the database itself. A rolling cross-version rejoin depends on
IST; do not treat SST as an acceptable fallback while versions are mixed.

Record the current package and Galera provider versions:

```bash
ansible librenms_db -i inventories/ha/hosts.yml -b -m shell -a \
  "mariadb --version; dpkg-query -W -f='\${Package} \${Version}\\n' mariadb-server galera-4"
```

Confirm no member is configured for the crash-like InnoDB shutdown mode. A
major upgrade must not stop with `innodb_fast_shutdown=2`:

```bash
ansible librenms_db -i inventories/ha/hosts.yml -b -m shell -a \
  "mysql -Nse 'SELECT @@GLOBAL.innodb_fast_shutdown;'"
```

Values `0` or `1` are acceptable. Set `1` on any node reporting `2` and verify
it before that node is stopped:

```bash
ansible <node> -i inventories/ha/hosts.yml -b -m shell -a \
  "mysql -e 'SET GLOBAL innodb_fast_shutdown=1;'"
```

## Back Up and Prove Restore

Create a fresh database/config backup:

```bash
make backup
```

Find the generated backup directory on the configured backup host, then test
the exact backup:

```bash
make restore-test RESTORE_TEST_BACKUP_DIR=/var/backups/librenms-ha/<run-id>
```

Copy the backup, manifest, and checksums to storage outside lnms1/lnms2/lnms3.
Do not continue until the restore test and off-cluster copy both succeed.

## Pin the MariaDB Repository Script

Download the official repository setup script on the controller or another
review workstation, inspect it, and calculate its SHA-256 digest:

```bash
curl -fsSLo /tmp/mariadb_repo_setup \
  https://r.mariadb.com/downloads/mariadb_repo_setup
sha256sum /tmp/mariadb_repo_setup
```

Use the reviewed script with the same digest on every node. Do not copy a
checksum from this document because the vendor script may change.

## Rolling Upgrade Procedure

Complete all three nodes for one target series before moving to the next
series. For each target in `11.4`, `11.8`, and `12.3`, process the nodes in this
order unless an approved site runbook specifies another order:

```text
lnms3, lnms2, lnms1
```

Keeping the current VIP/bootstrap-preference node until last reduces unrelated
control-plane movement. Replace `<node>` and `<target-series>` in the commands
below.

Pause LibreNMS automatic application updates on all three nodes for the entire
database migration. This prevents the 03:00 `daily.sh` run from changing PHP
dependencies or the database schema while Galera members run mixed versions:

```bash
ansible librenms_nodes -i inventories/ha/hosts.yml -b \
  -m ansible.builtin.systemd \
  -a "name=librenms-daily.timer state=stopped"
```

Keep the timers stopped until the final 12.3 validation succeeds. The
per-node maintenance workflow also stops the target's timer, but it does not
protect the other two nodes for the full migration window.

### 1. Drain one node

From the controller:

```bash
make maintenance-enter MAINTENANCE_TARGET=<node>
```

The maintenance playbook withdraws that node from web/VIP service, stops local
LibreNMS workers and data services, and verifies the remaining Galera members
stay Primary.

Verify the two remaining nodes before package work:

```bash
ansible 'librenms_db:!<node>' -i inventories/ha/hosts.yml -b -m shell -a \
  "mysql -Nse \"SHOW GLOBAL STATUS WHERE Variable_name IN ('wsrep_cluster_size','wsrep_cluster_status','wsrep_ready','wsrep_local_state_comment');\""
```

The remaining cluster size must be `2`, with `Primary`, `ON`, and `Synced`.

### 2. Configure the target repositories on the drained node

Copy the reviewed repository script to the node and verify its checksum. Then
run it for only the current hop:

```bash
ansible <node> -i inventories/ha/hosts.yml -b -m copy -a \
  "src=/tmp/mariadb_repo_setup dest=/usr/local/sbin/mariadb_repo_setup owner=root group=root mode=0755"

ansible <node> -i inventories/ha/hosts.yml -b -m shell -a \
  "echo '<sha256>  /usr/local/sbin/mariadb_repo_setup' | sha256sum -c -"

ansible <node> -i inventories/ha/hosts.yml -b -m command -a \
  "/usr/local/sbin/mariadb_repo_setup --mariadb-server-version=mariadb-<target-series> --skip-maxscale --skip-tools"
```

Before the `12.3` hop, also configure the separately published official Galera
package source from <https://mariadb.com/galera-downloads/>. MariaDB 12.3
removed `galera-4` from the server repository, while Galera publishes its own
Ubuntu 22.04/24.04 repositories and targeted packages. Review and pin that
repository's signing key and source using the same change-control process as
the server repository. Do not rely on an older Ubuntu archive package merely
because APT can resolve the name; this project requires `galera-4` 26.4.26 or
newer for the 12.3 hop.

Refresh APT metadata and prove that the target server and compatible Galera
provider resolve before removing or changing any installed package:

```bash
ansible <node> -i inventories/ha/hosts.yml -b -m shell -a \
  "apt-get update && apt-cache policy mariadb-server mariadb-client mariadb-backup galera-4"
```

The MariaDB packages must show candidates from the intended target server
repository. For 12.3, `galera-4` must show a candidate from the separately
approved Galera source and must be version 26.4.26 or newer. Stop if it is
missing, older, or held on an unreviewed provider version.

### 3. Upgrade packages and rejoin Galera

`maintenance-enter` has already stopped MariaDB on the drained node. The
`innodb_fast_shutdown` value was checked, and corrected when necessary, before
entering maintenance. On the drained node:

```bash
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  mariadb-server mariadb-client mariadb-backup galera-4
dpkg-query -W -f='${Package} ${Version}\n' mariadb-server galera-4
sudo systemctl start mariadb
```

Debian package scripts may start MariaDB during installation. The node remains
withdrawn from web, worker, and HAProxy database service throughout this step;
the explicit `systemctl start` is idempotent and ensures the rejoin has begun.

Wait for the node to rejoin instead of bootstrapping a new cluster:

```bash
for attempt in $(seq 1 60); do
  state=$(sudo mysql -Nse \
    "SELECT CONCAT_WS('/',
      (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='WSREP_CLUSTER_STATUS'),
      (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='WSREP_READY'),
      (SELECT VARIABLE_VALUE FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME='WSREP_LOCAL_STATE_COMMENT'));" \
    2>/dev/null || true)
  [ "$state" = "Primary/ON/Synced" ] && break
  sleep 5
done
[ "$state" = "Primary/ON/Synced" ]
```

Verify the rejoin used IST and did not begin SST while this node and its donors
run different MariaDB series:

```bash
sudo journalctl -u mariadb --since '30 minutes ago' --no-pager | \
  egrep -i 'IST received|IST.*complete|SST|State transfer'
```

Do not continue to the next node if an SST starts during a mixed-version hop.
Stop the node, retain the healthy two-node Primary component, collect
diagnostics, and review GCache sizing and vendor compatibility before retrying.

Run the system-table upgrade only after the node is synced:

```bash
sudo mariadb-upgrade --skip-write-binlog
```

If the command reports that the server is already upgraded, record that result
and continue. Do not use `--force` unless the MariaDB release instructions for
that exact hop require it.

### 4. Validate and return the node

Check the upgraded node:

```bash
mariadb --version
sudo mysql -Nse \
  "SHOW GLOBAL STATUS WHERE Variable_name IN ('wsrep_cluster_size','wsrep_cluster_status','wsrep_connected','wsrep_ready','wsrep_local_state_comment');"
```

The node must report the target series and a three-node
`Primary/ON/ON/Synced` cluster before it returns to service.

From the controller:

```bash
make maintenance-exit MAINTENANCE_TARGET=<node> \
  ANSIBLE_EXTRA_ARGS='-e librenms_maintenance_resume_daily_timer=false'
make status-strict
```

The override returns the node to polling and web service but deliberately
keeps its 03:00 application-update timer stopped until the migration finishes.

Stop immediately if rejoin, SST/IST, validation, or package installation fails.
Collect diagnostics before retrying:

```bash
make diagnostics
```

Do not upgrade the next node until the current node is fully synced.

## Commit the Final 12.3 Inventory State

Only after all three nodes run 12.3, set the final repository selection in
`inventories/ha/group_vars/all.yml`:

```yaml
librenms_mariadb_repository_mode: upstream
librenms_mariadb_upstream_series: "12.3"
librenms_mariadb_upstream_repo_setup_checksum: sha256:<reviewed-64-hex-digest>
```

Then converge and validate:

```bash
make site
make status-strict
make validate
make production-readiness
```

Re-enable the automatic updater only after all validation commands succeed:

```bash
ansible librenms_nodes -i inventories/ha/hosts.yml -b \
  -m ansible.builtin.systemd \
  -a "name=librenms-daily.timer enabled=true state=started"
```

Normal convergence now sees installed series `12.3` matching the requested
series. It manages the repository and packages but does not replace the data
directory.

## Rollback Boundary

Do not downgrade an upgraded MariaDB data directory in place. If a hop cannot
be completed safely, stop the rollout and choose one of these reviewed paths:

1. Repair/rejoin the failed node while the two-node Primary component remains
   authoritative.
2. Rebuild only the failed node from a clean package install and let Galera
   provision it from the healthy Primary component.
3. For a cluster-wide failure, restore the verified off-cluster backup into a
   clean cluster using the documented restore procedure.

Never copy an older `/var/lib/mysql` over a node that may contain newer writes,
and never run `galera_new_cluster` during a normal rolling upgrade.

## Vendor References

- [MariaDB general upgrade information](https://mariadb.com/docs/server/server-management/install-and-upgrade-mariadb/upgrading/mariadb-community-server-upgrade-paths/general-upgrade-information)
- [Upgrading between major MariaDB versions](https://mariadb.com/docs/server/server-management/install-and-upgrade-mariadb/upgrading/upgrading-between-major-mariadb-versions)
- [MariaDB 12.3 changes and improvements](https://mariadb.com/docs/release-notes/community-server/12.3/mariadb-12.3-changes-and-improvements)
- [MariaDB Community Server release schedule](https://mariadb.com/docs/release-notes/community-server/all-releases)
- [Galera Cluster 26.4.26 release notes and packages](https://mariadb.com/docs/release-notes/galera-cluster/26.4/26.4.26)
- [`mariadb-upgrade` reference](https://mariadb.com/docs/server/clients-and-utilities/deployment-tools/mariadb-upgrade)
