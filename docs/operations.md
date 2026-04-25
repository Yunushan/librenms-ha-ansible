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

4. On the first install only, finish the LibreNMS web bootstrap at the VIP or
node URL, then rerun `cluster.yml`. This lets the playbook apply the
post-bootstrap distributed-poller, scheduler, Redis, and dispatcher settings.

5. Validate live firewall/listener reachability after services are installed:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/doctor.yml \
  --ask-become-pass \
  -e librenms_doctor_network_tcp_checks_enabled=true
```

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
reachable from a specific managed host instead.

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
selected modes: Gluster, MariaDB/Galera, Redis, Redis Sentinel, RRDCacheD,
HAProxy, and Keepalived. Galera configs include safe primary-component recovery
by default, which helps clean full-cluster restarts re-form without an operator
bootstrap when Galera has valid saved state. It does not force an unsafe Galera
bootstrap; if no `Primary` component forms, use `galera-recover.yml`.

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
ansible-playbook -i inventories/ha/hosts.yml playbooks/galera-recover.yml --ask-become-pass
```

If no node has `safe_to_bootstrap: 1`, collect `galera_recovery` evidence. This
stops MariaDB on reachable Galera nodes and reports the highest recovered
`seqno` candidate without bootstrapping:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/galera-recover.yml \
  --ask-become-pass \
  -e librenms_galera_recover_confirm=true
```

Bootstrap only the selected host reported by the playbook:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/galera-recover.yml \
  --ask-become-pass \
  -e librenms_galera_recover_confirm=true \
  -e librenms_galera_recover_bootstrap_host=lnms2
```

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

Validate a backup without restoring it:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/restore-test.yml \
  --ask-become-pass \
  -e librenms_restore_test_backup_dir=/var/backups/librenms-ha/<timestamp>
```

Restore should be treated as a maintenance event:

1. Stop LibreNMS workers and web traffic.
2. Restore database to one safe MariaDB/Galera node.
3. Restore config/RRD data only from the matching backup timestamp.
4. Run `cluster.yml`.
5. Run `validate.yml`.

Do not restore one Galera member with old data while the rest of the cluster is
running with newer writes.
