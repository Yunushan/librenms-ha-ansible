# LibreNMS HA Operations Runbook

Use this runbook for planned maintenance, failover drills, and post-outage
recovery. The goal is to keep checks repeatable and avoid changing several
layers at once.

If operators will run these procedures from AWX, build the Job Templates and
Workflow Job Templates from [awx-controller.md](awx-controller.md) first. It
maps the command-line runbook to safe GUI launches, surveys, schedules, and
RBAC boundaries.

Before treating a deployment as production-ready, review
[support-matrix.md](support-matrix.md). It defines distro tiers, required
readiness gates, expected HA behavior during node loss, and the limits that
still require operator review.

During an incident or drill, use [failure-scenarios.md](failure-scenarios.md)
for symptom-driven triage before rerunning broader convergence playbooks.

When you only need to choose the right command, use
[command-map.md](command-map.md).

For ticket-friendly step lists, use
[operator-checklists.md](operator-checklists.md) alongside this runbook.

## Production Readiness Command Sequence

Use this order for HA work. Stop at the first failure, fix that layer, then
restart from the same stage. Avoid running recovery playbooks as a reflex;
`galera-recover.yml` is only for a cluster with no Galera `Primary` component.

### Declare the Production Profile

Before certifying an HA deployment, set the explicit production-profile flag in
`inventories/ha/group_vars/all.yml`. It does not alter services by itself; it
makes `production-readiness.yml` reject a deployment that lacks VIP TLS or the
reviewed source-restricted UFW policy:

```yaml
librenms_production_profile: true
librenms_manage_host_firewall: true
librenms_host_firewall_management_sources:
  - 10.4.92.0/24
librenms_host_firewall_cluster_sources:
  - 10.2.7.0/24
librenms_haproxy_tls_enabled: true
librenms_backup_offsite_enabled: true
librenms_backup_offsite_required: true
librenms_backup_offsite_rsync_target: backup@backup.example:/srv/backups/librenms
```

Keep the flag `false` for labs, migration work, and any environment where those
network and certificate decisions have not yet been reviewed. The readiness
gate already requires encrypted or externally validated secrets, a working
offsite DB/config backup, a restore verification, and recent failover evidence
for HA mode.

### First HA deployment

1. Validate inventory and local YAML before touching the nodes:

```bash
python3 scripts/validate-inventory.py \
  --inventory inventories/ha/hosts.yml \
  --group-vars inventories/ha/group_vars/all.yml
python3 scripts/ci-parse-yaml.py
```

2. Run preflight checks. This verifies inventory shape, OS support, disk,
memory, time sync, VIP configuration, and routed HA paths:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/doctor.yml --ask-become-pass
```

3. Deploy or re-converge the cluster:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml --ask-become-pass
```

The site deployment is fail-fast across the active inventory. If one host
fails, Ansible stops the remaining site plays instead of continuing with a
partially converged database, Redis, or load-balancer set. Fix the reported
host, confirm its service state, and rerun the same command; later quorum
errors from surviving hosts should not be treated as an independent failure.

4. On the first install only, finish the LibreNMS web bootstrap at the VIP or
node URL, then rerun `cluster.yml`. This lets the playbook apply the
post-bootstrap distributed-poller, scheduler, Redis, and dispatcher settings.

5. Validate live firewall/listener reachability after services are installed:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/doctor.yml \
  --ask-become-pass \
  -e librenms_doctor_network_tcp_checks_enabled=true
```

For a managed host firewall, explicitly set the management and trusted-cluster
CIDRs in \`inventories/ha/group_vars/all.yml\`, review them with an SSH session
that originates from the management CIDR, then apply the policy one node at a
time:

```yaml
librenms_manage_host_firewall: true
librenms_host_firewall_management_sources:
  - 10.4.92.0/24
librenms_host_firewall_cluster_sources:
  - 10.2.7.0/24
librenms_host_firewall_web_sources:
  - 10.4.92.0/24
librenms_host_firewall_syslog_sources:
  - 10.3.24.0/24
```

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/firewall.yml \
  --ask-become-pass
```

The firewall role is disabled by default, permits SSH before UFW is enabled,
allows all traffic from only the trusted HA CIDRs, and then applies a deny-by-
default inbound policy. It refuses to run without explicit management and
cluster sources, so it cannot infer a network policy or silently risk an SSH
lockout. Add \`librenms_host_firewall_snmp_sources\` when local SNMP agents are
managed. When host-firewall management is enabled, the broad legacy syslog and
Gluster firewall helpers are automatically disabled in favor of this restricted
policy.

### Production secret source

HA production-readiness checks require an encrypted Ansible Vault file by
default. The default path is
`inventories/ha/group_vars/vault.yml`, which should contain the generated
application, database, Redis, Sentinel, and VRRP secrets:

```bash
python3 scripts/generate-secrets.py > inventories/ha/group_vars/vault.yml
ansible-vault encrypt inventories/ha/group_vars/vault.yml
```

For secrets injected by AWX or another external system, deliberately select
the external mode and identify the provider and credential reference. The
reference is recorded only as configuration metadata; secret values are never
written to readiness evidence or task output. External mode also requires a
fixed-argument provider command that can run successfully on the Ansible
controller. The command output and environment are redacted, so it should
perform a non-mutating provider lookup without echoing the secret.

```yaml
librenms_production_readiness_secret_source: external
librenms_production_readiness_external_secret_provider: AWX credential
librenms_production_readiness_external_secret_reference: LibreNMS HA secrets
librenms_production_readiness_external_secret_validation_command:
  - vault
  - kv
  - get
  - -field=version
  - secret/librenms-ha
```

Set `librenms_production_readiness_require_encrypted_vault: false` only for a
documented exception. It disables this certification gate, not the normal
Ansible Vault or external-secret mechanism.

6. Check HA state and then the application:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/status.yml \
  --ask-become-pass \
  -e librenms_status_alert_fail_on_degraded=true
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml --ask-become-pass
```

7. Take and validate the first backup:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/backup.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/restore-test.yml \
  --ask-become-pass \
  -e librenms_restore_test_backup_dir=/var/backups/librenms-ha/<timestamp>
```

For an unattended controller job, explicitly enable managed latest-backup
selection instead of hard-coding a timestamp. It only selects direct child
directories from the configured backup category:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/restore-test.yml \
  --ask-become-pass \
  -e librenms_restore_test_select_latest=true \
  -e librenms_restore_test_backup_category=daily
```

The optional AWX schedule described in
[awx-controller.md](awx-controller.md#managed-restore-test-schedule) uses this
same guarded mode and is disabled by default.

For a recurring, approved maintenance window, AWX can also create a disabled-by-
default monthly [failover-drill schedule](awx-controller.md#managed-failover-drill-schedule).
It explicitly confirms the disruptive role, so enable it only after choosing
the test cases, maintenance budget, and an operator responsible for reviewing
the result.

8. Run the production gate after the offsite backup target is configured. It
performs one additional daily-category backup to prove the remote copy, checks
manifest SHA-256 values and archives, imports the database dump into a
disposable database, and removes that database afterward:

```bash
ansible-playbook -i inventories/ha/hosts.yml \
  playbooks/production-readiness.yml --ask-become-pass
```

### Existing cluster before planned maintenance

Run this sequence before a node shutdown, package work, network changes, or a
controlled failover test:

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

Equivalent Make targets are available. Use `PLAYBOOK_FLAGS=--ask-become-pass`
when your managed nodes require sudo password prompts:

```bash
make pre-maintenance PLAYBOOK_FLAGS=--ask-become-pass
make docker-pre-maintenance PLAYBOOK_FLAGS=--ask-become-pass
```

### After a config or role change

Use this when inventory, templates, role defaults, packages, or service files
changed:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/post-reboot.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml --ask-become-pass
```

Equivalent Make targets:

```bash
make post-change PLAYBOOK_FLAGS=--ask-become-pass
make docker-post-change PLAYBOOK_FLAGS=--ask-become-pass
```

During serialized Galera convergence, the node-drain helper gives active
LibreNMS workers `librenms_galera_web_drain_unit_stop_timeout` seconds to stop
cleanly. If a worker remains stuck, the helper sends TERM and then KILL only to
that unit's cgroup. An unsuccessful stop rolls the traffic drain back before
the playbook fails. The timeout and
`librenms_galera_web_drain_unit_kill_grace` may be raised for unusually long
polling jobs, but should remain bounded.

The database backend is first given `librenms_galera_backend_drain_timeout`
seconds to drain naturally. If persistent application sessions remain during
this planned operation, the helper disconnects only those non-system sessions
and verifies the result for
`librenms_galera_backend_force_disconnect_timeout` seconds. Set
`librenms_galera_backend_force_disconnect_clients: false` to fail closed
instead. Empty and unauthenticated connection-setup probes are not treated as
established workload sessions. This planned-maintenance behavior does not
enable HAProxy's broad `on-marked-down shutdown-sessions` policy for transient
health-check failures.

### After a full cluster restart

When all nodes were powered off and then started again, do not run a full
redeploy first. Let the boot-time repair units and runtime gates converge, then
run:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/post-reboot.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/status.yml \
  --ask-become-pass \
  -e librenms_status_alert_fail_on_degraded=true
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml --ask-become-pass
```

Run `cluster.yml` only if `post-reboot.yml` shows drift that cannot self-repair
or if you changed inventory or role code while the cluster was down.

Equivalent Make targets:

```bash
make post-restart PLAYBOOK_FLAGS=--ask-become-pass
make docker-post-restart PLAYBOOK_FLAGS=--ask-become-pass
```

### Before trusting failover behavior

Run failover tests only after `doctor.yml`, `status.yml`, backup, and
`validate.yml` are clean.

The default failover test covers one web backend and the Keepalived VIP:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/ha-failover-test.yml \
  --ask-become-pass \
  -e librenms_failover_test_confirm=true
```

For a broader service drill, choose the cases explicitly:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/ha-failover-test.yml \
  --ask-become-pass \
  -e librenms_failover_test_confirm=true \
  -e '{"librenms_failover_test_cases":["web_backend","keepalived_vip","haproxy_service","dispatcher_service"]}'
```

Reserve the data-layer cases for a maintenance window with a current backup:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/backup.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/ha-failover-test.yml \
  --ask-become-pass \
  -e librenms_failover_test_confirm=true \
  -e '{"librenms_failover_test_cases":["redis_master","galera_node"]}'
```

The Redis case only passes after every configured Sentinel reports the same
new master and that master accepts a write. The Galera case first requires all
members to be `Primary/Synced`, verifies the survivors remain synced at the
reduced cluster size, then requires the restored node to rejoin
`Primary/Synced` at the full size and proves a fresh SQL request through the
HAProxy database VIP. A timeout is a failed recovery proof, not a successful
drill with a slow backend.

After every restored drill, the role retries the VIP application probe and runs
`validate.php` on an active LibreNMS node. It requires healthy database, Redis,
dispatcher, and rrdcached dependencies before reporting success. Successful
drills also create a compact, secret-free evidence record on the Ansible
controller at `/var/lib/librenms-ha/failover-evidence/`, retained for 90 days.
Each new record has a root-readable SHA-256 sidecar. Production readiness
rejects a missing, malformed, or mismatched checksum by default, so run a new
confirmed drill after enabling this version if older evidence has no sidecar.
Configure `librenms_failover_test_evidence_dir`,
`librenms_failover_test_evidence_retention_days`, or set
`librenms_failover_test_write_evidence: false` to follow controller storage
policy. Failed runs retain their detailed evidence in the Ansible or AWX job
output and do not create a passing record.

On HA deployments, the daily update wrapper also requires the local PHP runtime
database health endpoint to return HTTP 200 before it removes its drain marker.
This is the same deep check used by HAProxy, so a node whose web workers cannot
query MariaDB stays out of rotation while the wrapper attempts its local
cache/PHP-FPM recovery.

The full production readiness gate also writes a separate secret-free passing
record, SHA-256 sidecar, and authenticated HMAC-SHA256 sidecar to
/var/lib/librenms-ha/production-readiness-evidence/ on the Ansible controller
and retains them for 365 days. Both sidecars are verified immediately after
they are written. The HMAC uses the existing app key without printing it, so a
record and ordinary checksum changed together cannot be accepted by an actor
who can modify evidence storage but cannot access the application secret. The
record contains the completed time, topology, and which live verification
scopes passed; it does not contain credentials, private keys, or backup paths.
Configure
librenms_production_readiness_evidence_dir,
librenms_production_readiness_evidence_retention_days, or set
librenms_production_readiness_write_evidence: false to follow controller
storage policy. Set
`librenms_production_readiness_evidence_integrity_enabled: false` or
`librenms_production_readiness_evidence_hmac_enabled: false` only when an
external immutable evidence store provides equivalent integrity protection.
AWX also receives the result through job statistics.

The readiness run installs a root-only controller verifier at
`/usr/local/sbin/librenms-production-readiness-evidence-verify`. To validate
the newest retained record later without exposing the app key, run:

```bash
cd /var/lib/librenms-ha/production-readiness-evidence
latest=$(ls -1t production-readiness-*.json | head -n 1)
sudo /usr/local/sbin/librenms-production-readiness-evidence-verify \
  --evidence "$latest" --app-env /opt/librenms/.env
```

In HA mode, that gate also requires a successful controller-side failover drill
record no older than 30 days by default. The drill must cover at least
`web_backend` and `keepalived_vip`; set
`librenms_production_readiness_required_failover_cases` to require additional
cases such as `redis_master` or `galera_node`. The record is also bound to the
current HA mode and VIP, so evidence copied from another environment cannot
satisfy this gate. It must include a measured recovery time no greater than the
900-second default objective; set
`librenms_production_readiness_max_failover_recovery_seconds` only after
reviewing the service recovery-time objective. This is deliberately fail-closed:
current service health does not prove that a VIP transition works.

The gate also verifies that the managed `librenms-backup-daily.timer` is active,
has a future invocation, and that its most recent service execution is not in a
failed state. This protects the ongoing recovery-point objective after the
one-time backup and restore verification completes. Set
`librenms_production_readiness_require_scheduled_daily_backup: false` only for
a reviewed deployment that uses an independently managed backup scheduler.

The disposable database restore verification is also timed and must complete
within 1,800 seconds by default. The resulting duration and objective are kept
in the controller-side readiness evidence. Set
`librenms_production_readiness_max_database_restore_seconds` to the approved
database recovery-time objective for the deployment.

The gate runs Doctor's live route and TCP matrix before it writes its passing
record. A failed Galera, Redis, GlusterFS, or load-balancer path therefore
cannot leave a misleading production-readiness evidence file behind.

`site.yml` and `syslog.yml` apply HAProxy and Keepalived configuration with
`serial: 1`. This deliberately rolls changes across load-balancer nodes so a
template, certificate, or syslog-listener change cannot reload every HAProxy
instance and restart every Keepalived instance simultaneously.

Use `librenms_failover_test_haproxy_host`,
`librenms_failover_test_dispatcher_host`,
`librenms_failover_test_redis_query_host`, and
`librenms_failover_test_galera_host` when you need to target a specific node.

Equivalent Make targets:

```bash
make failover-drill PLAYBOOK_FLAGS=--ask-become-pass
make docker-failover-drill PLAYBOOK_FLAGS=--ask-become-pass
```

### Status alerts

When you need a compact HA snapshot:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/status.yml --ask-become-pass
```

The report includes runtime drift checks for expected active/enabled systemd
units, LibreNMS writable path ownership, and maintenance nodes that are still
running HA or application services. These checks are included in degraded status
and in webhook payloads.

To make `status.yml` fail a scheduled job when HA is degraded:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/status.yml \
  --ask-become-pass \
  -e librenms_status_alert_fail_on_degraded=true
```

To send a webhook when degradation is detected, set these in inventory or pass
them from AWX/job credentials:

```yaml
librenms_status_alerts_enabled: true
librenms_status_alert_webhook_url: https://hooks.example.com/librenms-ha
librenms_status_alert_webhook_headers:
  Authorization: "Bearer CHANGE_ME"
```

Webhook delivery is delegated to the Ansible controller by default. Set
`librenms_status_alert_webhook_delegate` only if the webhook endpoint is
reachable from a specific managed host instead. HA production-readiness runs
require this channel by default: the webhook URL must use HTTPS, certificate
validation must remain enabled, and `librenms_status_alerts_enabled` must be
true. Set `librenms_production_readiness_require_status_alert_routing: false`
only for a documented exception while an external alerting route is being
established.

### Diagnostics bundles

When a validation, status, failover, maintenance, or post-reboot check fails,
collect a diagnostics bundle before rerunning recovery steps:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/diagnostics.yml --ask-become-pass
```

The Make wrappers are:

```bash
make diagnostics PLAYBOOK_FLAGS=--ask-become-pass
make docker-diagnostics PLAYBOOK_FLAGS=--ask-become-pass
```

The playbook writes per-host archives to `diagnostics/<run-id>/` on the
controller. It tolerates unreachable hosts and captures the surviving nodes'
view of HAProxy, Keepalived, Galera, Redis/Sentinel, Gluster, LibreNMS workers,
`validate.php`, journals, and selected sanitized configs.

Common incident overrides:

```yaml
librenms_diagnostics_log_lines: 1000
librenms_diagnostics_journal_lines: 500
librenms_diagnostics_keep_remote: true
librenms_diagnostics_fetch: false
```

Use `librenms_diagnostics_keep_remote: true` when the controller cannot fetch
artifacts reliably. Config snippets redact obvious passwords and tokens, but
logs can still contain sensitive operational data, so store bundles like an
incident record.

### LibreNMS application updates

The role manages LibreNMS' normal `daily.sh` maintenance through
`librenms-daily.timer`. By default the timer runs at 03:00 in each host's local
timezone, uses LibreNMS' `release` update channel, and allows LibreNMS to update
to the latest stable release:

```yaml
librenms_version: latest-stable
librenms_update_channel: release
librenms_update_enabled: true
librenms_daily_timer_on_calendar: "*-*-* 03:00:00"
librenms_daily_timer_randomized_delay: 1800
librenms_daily_self_heal_enabled: true
librenms_manage_scheduled_backups: true
librenms_backup_pre_upgrade_enabled: true
librenms_backup_pre_upgrade_required: true
```

The timer starts at 03:00 local time with up to 30 minutes of jitter by default.
In HA mode, every run first takes a shared RRD filesystem `flock` before performing
any Git repair, backup, update, schema work, or cache refresh. This is
deliberately not implemented with only MariaDB `GET_LOCK()`: named locks are
local to one Galera member and therefore are not a cluster-wide mutex behind a
round-robin database proxy. Only one node can maintain code, dependencies,
schema, and generated caches at a time. A node that cannot acquire the lock
before
`librenms_daily_global_lock_timeout` skips that trigger without creating a false
daily-update failure. Daily maintenance is executed through a self-heal wrapper
that runs LibreNMS as the `librenms` user, checks PHP autoload health afterward,
and repairs incomplete `vendor/` installs by rerunning LibreNMS' Composer
wrapper, clearing Laravel caches, and restarting PHP-FPM.

HA mode also uses a deterministic canary by default: the first active web node
in inventory is the canary, and all other nodes wait for its same-day healthy
completion record on the shared RRD filesystem before they can start their own
maintenance. In Gluster mode this is the Gluster-backed RRD path; in external
mode it is the mounted NFS/NFSv4 RRD path.
The record is written only after the canary's post-update runtime probe has
passed, then waits five minutes by default before followers continue. If the
canary fails or never becomes healthy, followers skip their unattended update
instead of propagating the release failure. The relevant settings are
`librenms_daily_canary_host`, `librenms_daily_canary_stabilization_seconds`,
`librenms_daily_canary_wait_timeout`, and
`librenms_daily_canary_wait_delay`. Set
`LIBRENMS_DAILY_CANARY_BYPASS=true` only for a deliberate manual maintenance
run that has already been approved.

While a node holds the HA maintenance lock, the outer maintenance wrapper
creates a short-lived local drain marker. Nginx returns `503` for that node's
HAProxy health-check path, so HAProxy removes only the updating backend before
its Git repair, pre-upgrade backup, code update, cache refresh, PHP-FPM restart,
or Composer self-heal. The wrapper removes the marker only from its final exit
trap, allowing the node to rejoin after the full transaction has completed. The
systemd unit also removes the marker in `ExecStopPost`, so a forced stop or
timeout cannot leave the node drained. Set
`librenms_daily_ha_drain_enabled: false` only for a
deliberate non-HA maintenance workflow.

The wrapper also serializes local runs with a `flock` lock. Before `daily.sh`
starts, it skips cleanly if another `librenms`-owned Git, Composer, or daily
process is already active. If no such process is active, it removes stale
LibreNMS `.git/*.lock` files, prunes deleted upstream refs, and fetches current
tags. If `daily.sh` still reports a Git/ref lock update failure, the wrapper
repairs Git metadata and retries `daily.sh` once. Real upstream/network errors
can still fail and alert, but stale local Git state should not require manual
cleanup.

After each `daily.sh` run, the wrapper clears Laravel caches and restarts
PHP-FPM by default, then probes the local LibreNMS application endpoint using
the same accepted HTTP status policy as deployment verification. If the first
probe fails, it repeats the cache clear and restarts PHP-FPM and nginx once
before retrying. The HA drain marker remains present throughout those checks,
so HAProxy does not send user traffic to a node whose post-update application
health has not recovered. This prevents web requests from holding stale generated
cache or opcache references after an update, such as missing
`bootstrap/cache/routes-v*.php` files. If `daily.sh` exits non-zero after these
repairs but the wrapper confirms LibreNMS autoload health, the service exits
successfully for known Git/release-fetch failures by default. This prevents
transient update warnings from becoming persistent "Daily update failed" UI
notifications while still failing SQL schema, Composer, database, or broken
autoload states. For that same healthy repaired case, the wrapper removes the
matching recent `daily.sh` failure notification for the local node, leaving
unrelated or real failure notifications untouched. A later successful healthy
daily run also clears a matching stale notification from a previous run. The
default cleanup window is 30 days and is controlled by
`librenms_daily_self_heal_notification_cleanup_days`.

`playbooks/production-readiness.yml` verifies that the maintenance-lock path is
mounted from the selected shared RRD filesystem and launches a short simultaneous
lock probe from every active web node. Exactly one node must acquire the lock. A
failure here blocks a production declaration because automatic updates could
otherwise overlap. Gluster-specific health is checked only in Gluster mode;
external mode validates the NFS/NFSv4 mount and write path instead.

The backup wrapper serializes scheduled and pre-upgrade backups on their
coordinator host. A pre-upgrade backup waits for an existing local backup up to
`librenms_backup_lock_timeout` instead of failing immediately and producing a
false daily-update alert.

Before the wrapper runs `daily.sh`, it creates a local pre-upgrade DB/config
backup with `librenms-ha-backup pre-upgrade`. The update stops if that backup
fails while `librenms_backup_pre_upgrade_required` is true. This protects the
automatic update path from continuing into code or schema changes without a
fresh rollback artifact. Routine scheduled backups are also managed by
`site.yml`: daily backups at 02:30 and weekly backups on Sunday at 02:00 on
`librenms_backup_scheduled_host`.

For production, copy every backup to storage outside the LibreNMS cluster. The
built-in rsync transport is opt-in and can make a failed remote copy stop both
scheduled and pre-upgrade backup workflows:

```yaml
librenms_backup_offsite_enabled: true
librenms_backup_offsite_required: true
librenms_backup_offsite_rsync_target: backup@backup.example:/srv/backups/librenms
librenms_backup_offsite_rsync_options:
  - "-e"
  - "ssh -i /root/.ssh/librenms_backup -o BatchMode=yes"
```

The target is the backup root, not an individual run directory. Create and
protect its `daily`, `weekly`, and `pre-upgrade` directories on the backup
system before enabling required offsite copies. The backup wrapper writes each
run below the matching category, for example
`/srv/backups/librenms/daily/2026-07-21T030000Z/`.

The target must be an independently managed backup host or storage gateway with
the destination base directory already created. Test restoration with
`playbooks/restore-test.yml`; a successful copy is not a restore verification.
After every rsync copy, the wrapper reads the remote backup manifest and runs
a checksum comparison between local and offsite artifacts. A required offsite
backup fails when either immediate verification fails.

Before a production go-live, run the explicit configuration gate:

```bash
make production-readiness PLAYBOOK_FLAGS=--ask-become-pass
```

It requires non-placeholder secrets, a pinned MariaDB repository script when
upstream packages are selected, the shared HA daily maintenance lock, an off-cluster
backup target, non-wildcard MariaDB binding, the minimum HA node counts, and
active runtime services. It then runs live checks for a fully synced Galera
component, every HAProxy Galera readiness agent, repeated fresh database
connections through the database VIP from every LibreNMS node, Redis Sentinel
quorum plus a short-lived cache write, `validate.php` on every LibreNMS node,
one clean matching LibreNMS Git revision on every application node, PHP-FPM and
the LibreNMS application through the VIP,
and the full TCP network matrix. In HA mode it also creates one normal `daily`
backup on the scheduled backup host, so the required offsite rsync transfer is
proven before go-live. It verifies database/config SHA-256 checksums and
archives, then imports the database dump into a disposable database that is
removed after the check. That
run applies the configured daily retention policy.

HA deployments use a dedicated PHP runtime health route for each web backend by
default. It performs a small fresh database query and returns only `200 ok` or
`503 unavailable`; it does not expose credentials or exception details. If a
PHP-FPM worker has lost its MariaDB connection, or an update leaves one node with
broken Composer dependencies or a Laravel boot error, HAProxy marks that backend
down before it can continue returning intermittent browser `500` responses.
The static `/about` check remains available by setting
`librenms_haproxy_web_runtime_check_enabled: false`.
`production-readiness.yml` also probes that same runtime endpoint directly on
every active application node, so a pass proves that no backend is merely hidden
behind a healthy VIP peer.

In Gluster-backed HA mode, the LibreNMS web validation page can sample an RRD
while `rrdcached` is actively writing it and report `RRD ERROR: could not lock
RRD`. The web validation JSON filter suppresses only that transient lock class
by default so the UI does not flap red during normal polling. Other RRD parse
errors remain visible. The full RRD Check is optional and recursively inspects
every RRD file. Its web request uses a separate 15-minute HAProxy/nginx timeout
so a large Gluster volume does not return a generic backend-fetch error at the
normal 180-second application timeout. Adjust
`librenms_web_validation_rrd_check_timeout` if the dataset needs longer.

Disable automatic code updates while keeping daily maintenance tasks with:

```yaml
librenms_update_enabled: false
```

Disable the automatic Git metadata repair while keeping the wrapper with:

```yaml
librenms_daily_self_heal_git_lock_cleanup: false
librenms_daily_self_heal_git_metadata_repair: false
librenms_daily_self_heal_git_retry_after_repair: false
librenms_daily_self_heal_clear_laravel_cache_after_daily: false
librenms_daily_self_heal_treat_healthy_update_failure_as_success: false
librenms_daily_self_heal_clear_healthy_update_failure_notification: false
librenms_daily_self_heal_notification_cleanup_days: 30
```

For a controlled version pin, set `librenms_version` to an explicit released tag
and rerun `playbooks/site.yml` after a backup and validation gate.

### Network map auto-repair

Network map repair is part of normal convergence on the primary LibreNMS node.
The playbook checks link totals, matched remote devices, and matched remote
ports in the LibreNMS database. When topology data is missing or unmatched, it
sets MAC/XDP fallback, refreshes topology discovery, runs the poller, and then
reports the before/after counts.

Useful controls:

```yaml
librenms_network_map_auto_repair: true
librenms_network_map_auto_repair_run_poller: true
librenms_network_map_auto_enable_mac_fallback: true
librenms_network_map_fallback_items:
  - mac
  - xdp
```

If the map still cannot correlate neighbors, the run output lists unmatched
remote hostnames and the first link rows so you can add or monitor the missing
devices instead of running SQL by hand.

### Rolling major OS upgrades

Major OS release upgrades are not automated by this repo. For Ubuntu, Debian,
and other distros, use the vendor-supported upgrade path on one node at a time,
then use Ansible to re-converge the node and prove the cluster is healthy.

For each node:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/maintenance-enter.yml \
  --ask-become-pass \
  -e librenms_maintenance_target=lnms1 \
  -e librenms_maintenance_confirm=true

# Run the distro-supported OS upgrade on lnms1, then reboot that node.

ansible-playbook -i inventories/ha/hosts.yml playbooks/maintenance-exit.yml \
  --ask-become-pass \
  -e librenms_maintenance_target=lnms1 \
  -e librenms_maintenance_confirm=true
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/post-reboot.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml --ask-become-pass
```

The exit half also has a wrapper for the repeated rejoin and validation steps:

```bash
make upgrade-node-exit MAINTENANCE_TARGET=lnms1 PLAYBOOK_FLAGS=--ask-become-pass
make docker-upgrade-node-exit MAINTENANCE_TARGET=lnms1 PLAYBOOK_FLAGS=--ask-become-pass
```

Do not start the next node until Galera is `Primary/Synced`, Redis Sentinel has
one writable master, Gluster is healthy, the VIP is owned by a live load
balancer, and LibreNMS validation is clean. For non-primary distros, run the
same process in a lab before production.

## Planned Single-Node Maintenance

1. Confirm `validate.yml` is clean.
2. Drain the target node with the maintenance playbook:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/maintenance-enter.yml \
  --ask-become-pass \
  -e librenms_maintenance_target=lnms1 \
  -e librenms_maintenance_confirm=true
```

The playbook moves the VIP away when needed, stops the target web backend and
LibreNMS workers, gracefully triggers Redis/Galera failover for the target when
applicable, and verifies the remaining HA layer before you power the node off.

3. Add the node to `maintenance_nodes` while it is intentionally unavailable:

```yaml
maintenance_nodes:
  hosts:
    lnms1:
```

4. Reboot or maintain only that one node.
5. After it returns, remove it from `maintenance_nodes`.
6. Rejoin it:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/maintenance-exit.yml \
  --ask-become-pass \
  -e librenms_maintenance_target=lnms1 \
  -e librenms_maintenance_confirm=true
```

7. Run `validate.yml`.

Do not power off a second Galera/Redis/Gluster member until the previous member
has fully rejoined and validation is clean.

## Hard Power-Off Failover Expectations

A hard power-off is not the same as stopping a service. The failed node cannot
withdraw the VIP, close TCP sessions, flush Redis/Sentinel config, or leave
Galera cleanly.

Expected behavior in a healthy LAN:

- VIP moves in a few seconds, normally close to the Keepalived advert interval
  plus detection time.
- HAProxy removes failed web/database/RRDCached backends after its health-check
  fall count.
- Existing browser requests can still wait for TCP timeout if they were already
  pinned to the failed VIP owner or a failed backend.

Two to three minutes of first-page delay is not normal for the HA layer. Check:

- which node owns the VIP with `ip -o addr show`
- whether HAProxy is listening on the VIP on the new owner
- whether the client ARP cache still points to the dead node
- whether the web request is hanging on database, Redis, RRD, or SNMP work
- whether Galera still has a `Primary` component
- whether Redis Sentinel has elected one writable master

## Full Cluster Restart

For a clean full shutdown, power off application traffic first, then database
and storage members. For startup, bring up at least two nodes before judging HA
health.

On systemd hosts, the role installs boot-time repair helpers for common drift
after a cold start. The LibreNMS dispatcher, scheduler, and daily maintenance
services wait for the DB frontend, Redis runtime path, and Gluster-backed RRD
mount before starting. Startup repair also re-enables the expected timers and
restores ownership on writable LibreNMS paths.

Startup repair also resets failed state and starts the expected HA units for the
selected modes: Gluster, Redis, Redis Sentinel, RRDCacheD, HAProxy, and
Keepalived. MariaDB/Galera is handled by a separate peer-aware path: a stopped
member is started immediately only when at least one remote member proves
`Primary`, `wsrep_ready=ON`, and `Synced`; a running but unready member must fail
the configured number of checks first. Every attempt has a bounded convergence
window and a cooldown that is recorded before systemd is invoked, including for
failed attempts. Galera configs include safe primary-component recovery by
default, which helps clean full-cluster restarts re-form when Galera has valid
saved state. Startup repair never creates a new Primary component, edits Galera
state files, or forces an unsafe bootstrap; if no `Primary` component forms, use
`galera-recover.yml`.

The startup repair timer also watches recent `librenms.log` output for a fresh
`MySQL server has gone away` / SQLSTATE `2006` error. In HA mode it also records
database frontend readiness on every run. After an observed `unready` to
`ready` transition, or after a fresh SQLSTATE `2006` while the frontend is
healthy, it gracefully reloads managed PHP-FPM workers once so stale database
connections cannot survive the failover. The reload is enabled by default only
for managed HA PHP-FPM, requires a fresh successful DB probe, and applies
`librenms_startup_repair_db_gone_away_php_fpm_cooldown` between attempts. A
cooldown-limited or failed reload remains pending and is retried by a later
timer run instead of being incorrectly marked handled.

This closes the persistent-worker recovery gap, but no proxy can replay a
MySQL transaction that was already in flight when its Galera member failed. A
single request can still fail at the exact failover boundary; HAProxy removes
the unhealthy backend and the application tier repairs itself automatically.
The role deliberately does not bootstrap a completely unavailable Galera
cluster without operator confirmation because doing so could create
split-brain or data loss.

HAProxy suppresses routine per-connection logs on its internal database
frontend by default while retaining process and backend state events. This
prevents a database outage from producing gigabytes of connection records. For
remote syslog, rsyslog uses a bounded disk-assisted action queue and a 30-second
resume interval, so an unavailable LibreNMS database sink is buffered instead
of spawning a failing PHP process every second. Tune
`librenms_syslog_action_queue_max_disk_space` for the expected message rate and
outage window. The queue is isolated under `/var/spool/rsyslog/librenms`.
Successful socket-activated Galera readiness-agent lifecycle messages are
filtered before local storage and forwarding, but agent failures remain
visible. This queue cannot add delivery acknowledgement to UDP senders.

After all nodes return, check the self-healing units before rerunning Ansible:

```bash
systemctl status librenms-ha-startup-repair.timer
systemctl status librenms-dispatcher-ha-recover.timer
systemctl status librenms.service
systemctl status librenms-scheduler.timer
```

From the controller, `post-reboot.yml` waits for the cluster to converge and
then runs the HA status checks in fail mode:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/post-reboot.yml --ask-become-pass
```

For shared RRD storage, post-reboot convergence now gates RRDCacheD on an
accessible, writable mount. In Gluster mode it runs the startup repair, then
boundedly detaches an inaccessible stale client mount, restores the managed
mount definition, remounts it with a per-attempt timeout, and repairs write
permissions before RRDCacheD can start. If recovery is not safe or does not
converge, RRDCacheD remains stopped and the play fails with `findmnt`, path,
service, and Gluster diagnostics instead of allowing writes to the local
mountpoint directory.

The final HA status collection runs as a separate play. If one node cannot
converge, Ansible still inspects it during the status pass so the report contains
its actual service and cluster state instead of cascading `unknown` values.

For each active LibreNMS node, it reports whether the runtime gate can reach
the database frontend, Redis runtime path, and RRD mount. It also reports the
startup repair timer, dispatcher recovery timer, and current dispatcher rows in
the LibreNMS database. Treat `runtime=ready` and at least one active dispatcher
database row as the basic signal that the app layer has recovered after boot.

After all nodes return, `post-reboot.yml` is the first command to run. It does
not redeploy config; it waits for services, Galera, Redis Sentinel, Gluster, the
VIP, and dispatcher registrations to settle. If it passes and no inventory or
role changes were made, the cluster recovered from boot order without needing a
full `cluster.yml` run.

Run `cluster.yml` before validation when you changed inventory, templates,
package state, or role defaults:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml --ask-become-pass
```

If Galera has no `Primary` component, do not randomly bootstrap a node. Use the
guarded recovery workflow:

```bash
make galera-recover-ask-become-pass
```

Use `make galera-recover` when passwordless sudo is configured. Without recovery
variables, both targets run evidence mode only and exit without stopping MariaDB
or changing Galera state.

If no node has `safe_to_bootstrap: 1`, collect `galera_recovery` evidence. This
stops MariaDB on reachable Galera nodes and reports the highest recovered
`seqno` candidate without bootstrapping:

```bash
make galera-recover-ask-become-pass GALERA_RECOVER_CONFIRM=true
```

site.yml also fails closed in this state after the first successful cluster
bootstrap. It never chooses the configured database host merely because it is
first in inventory. Keep librenms_galera_auto_recover_unsafe_bootstrap false
unless an operator has approved a narrowly scoped exception; the default
recovery tie-breaker is manual.

Bootstrap only the selected host reported by the playbook:

```bash
make galera-recover-ask-become-pass \
  GALERA_RECOVER_CONFIRM=true \
  GALERA_RECOVER_BOOTSTRAP_HOST=lnms2
```

When recovered positions tie, the named host is accepted only if it is one of
the highest-seqno candidates printed by the preceding run. The playbook rejects
an arbitrary or lower-seqno host.

After recovery, run `post-reboot.yml`, then `validate.yml`.

## Poller Validation During Node Loss

LibreNMS validation checks the application state, not just Linux service state.
If a node is powered off, stale dispatcher rows can remain visible until the
surviving dispatcher updates or prunes them.

During a node-loss test, validation should pass once at least one surviving
dispatcher is active and has reported recently. If it fails with no active
dispatcher nodes:

```bash
systemctl status librenms
journalctl -u librenms -n 80 --no-pager
```

Then check Redis, because dispatcher queues and locks depend on Redis:

```bash
redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
redis-cli -h <redis-master-ip> -p 6379 PING
```

## Redis Sentinel Checks

The Redis master write check may retry during failover. A retry that eventually
passes is acceptable during a controlled failover. A final failure means the
application may have queue and lock timeouts.

Check every Redis node:

```bash
systemctl status redis-server
systemctl status redis-sentinel
redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
```

All reachable Sentinels should agree on one master. Exactly one Redis node should
accept writes as master.

During normal `site.yml` convergence, a transient Sentinel split is treated as a
recoverable state. The role queries the complete active `librenms_redis` inventory
group, points replicas at `librenms_redis_master_host`, resets and flushes Sentinel
state, and retries the quorum and write checks. It still fails closed if the
configured quorum cannot be restored, or if `librenms_redis_sentinel_enforce_configured_master`
is disabled. Do not lower `librenms_redis_quorum` to hide an unreachable node;
repair the node or explicitly move it to the inventory's maintenance/decommission
list first.

If a playbook appears stuck on `Restart Redis service`, check whether Redis is
waiting on a shutdown snapshot:

```bash
ansible librenms_nodes -i inventories/ha/hosts.yml -b -m shell -a \
  "systemctl show redis-server -p ActiveState -p SubState -p MainPID --no-pager; systemctl status redis-server --no-pager -l | head -30"
```

`deactivating (stop-sigterm)` with `Saving the final RDB snapshot`, or
`activating (start)` with `Redis is loading...` from an old multi-GB `dump.rdb`,
is not a normal short restart. The default role disables Redis RDB/AOF
persistence, removes stale persistence files when persistence is disabled, and
sets bounded systemd start/stop timeouts so future maintenance cannot hang on a
large runtime cache snapshot. The role also clears an already-stuck Redis stop
job when `librenms_redis_clear_stuck_stop_job: true`.

If you need to clear one host by hand before pulling the fixed playbook, run:

```bash
ansible lnms1 -i inventories/ha/hosts.yml -b -m shell -a \
  "systemctl kill -s SIGKILL redis-server || true; sleep 3; systemctl reset-failed redis-server; systemctl start redis-server"
```

This can drop Redis cache/session state on that node, but Sentinel and LibreNMS
will rebuild runtime data. Browser sessions may need to log in again.

## SNMPv3 Graph Gaps

SNMPv3 polling can show gaps after a node outage if the dispatcher was down,
Redis queues were unavailable, or the monitored node itself was off. Once
polling resumes, new graph data should appear from that point forward. Missing
historical samples are expected; RRD does not invent data for missed intervals.

If graph gaps continue after validation is clean, test SNMPv3 directly from a
surviving poller:

```bash
snmpwalk -v3 -l authPriv -u <user> -a SHA -A '<auth-pass>' \
  -x AES -X '<priv-pass>' <node-ip> sysUpTime.0
```

## Backups and Restore Discipline

`backup.yml` creates database/config backups under
`/var/backups/librenms-ha/<timestamp>/`. Copy at least one recent backup outside
the cluster before OS upgrades or schema work.

`site.yml` also installs scheduled DB/config backups and automatic-update
guardrails:

- daily backups: `/var/backups/librenms-ha/daily/<timestamp>/`, 7 retained
- weekly backups: `/var/backups/librenms-ha/weekly/<timestamp>/`, 4 retained
- pre-upgrade backups:
  `/var/backups/librenms-ha/pre-upgrade/<timestamp>/`, 5 retained

Daily and weekly backups run on `librenms_backup_scheduled_host`, which defaults
to the Galera bootstrap host. Pre-upgrade backups run locally on each node
before that node's `librenms-daily.service` executes LibreNMS `daily.sh`.

Trigger a scheduled backup manually:

```bash
ansible lnms1 -i inventories/ha/hosts.yml -b -m shell -a \
  "systemctl start librenms-backup-daily.service"
```

Trigger the same pre-upgrade guard manually:

```bash
ansible librenms_nodes -i inventories/ha/hosts.yml -b -m shell -a \
  "/usr/local/sbin/librenms-ha-backup pre-upgrade"
```

Validate a backup by checking its manifest SHA-256 values and archives before
importing its database dump into a disposable database. The disposable
database is removed after the test; the
live LibreNMS database is not modified:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/restore-test.yml \
  --ask-become-pass \
  -e librenms_restore_test_backup_dir=/var/backups/librenms-ha/<timestamp>
```

For an external database, store
`librenms_restore_test_external_database_login_user` and
`librenms_restore_test_external_database_login_password` in Ansible Vault. The
account must be able to create, import, and drop the disposable database.

Restore tests require checksum manifests by default. Make a fresh backup if a
legacy manifest has no digests; use `librenms_restore_test_require_checksums=false`
only for a deliberate one-time legacy check.

Restore should be treated as a maintenance event:

1. Stop LibreNMS workers and web traffic.
2. Restore database to one safe MariaDB/Galera node.
3. Restore config/RRD data only from the matching backup timestamp.
4. Run `cluster.yml`.
5. Run `validate.yml`.

Do not restore one Galera member with old data while the rest of the cluster is
running with newer writes.

## MariaDB Series Selection

The default `librenms_mariadb_repository_mode: distro` uses the operating
system's MariaDB packages. On Ubuntu 24.04 this is the MariaDB 10.11 series.
LibreNMS automatic updates never change MariaDB packages or database series.

For a fresh deployment, the project can configure the official MariaDB Community
repository for an explicit series on Debian-family hosts. The supported local
series are `11.4`, `11.8`, and `12.3`. Pin the exact setup script hash obtained
from the approved MariaDB release source:

```yaml
librenms_mariadb_repository_mode: upstream
librenms_mariadb_upstream_series: "12.3" # 11.4, 11.8, or 12.3
librenms_mariadb_upstream_repo_setup_checksum: sha256:REPLACE_WITH_64_HEX_CHARACTERS
```

`site.yml` refuses an installed major-series change. A production Galera upgrade
must use a separate reviewed procedure with a tested off-cluster restore,
maintenance window, node-by-node package upgrade, and `Primary/Synced` health
gate after every node. MariaDB 12.3 is accepted for Debian-family Galera
deployments only when `galera-4` is supplied by the separate official Galera
package source. The 12.3 server repository itself no longer carries that
package, and the role rejects an older provider.

The upstream repository mode is Debian-family only. On RedHat and other
non-Debian families, use the distribution package mapping or provide a tested
site-specific package/repository override; this role does not pretend that
MariaDB Community's Debian repository applies to those systems.

Do not change the inventory to `12.3` and run `site.yml` against an existing
10.11 cluster. Follow the guarded
[MariaDB 10.11 to 12.3 Galera upgrade runbook](mariadb-10.11-to-12.3.md).
Rolling Galera upgrades must visit 11.4, then 11.8, then 12.3; a direct jump is
only supported with a full-cluster shutdown and planned application downtime.
