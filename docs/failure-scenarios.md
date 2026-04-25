# Failure Scenario Runbook

Use this guide during incidents and HA drills. It is intentionally symptom
driven: identify what failed, collect evidence, then run the smallest recovery
workflow that matches the failure.

## First Response Rules

1. Do not rerun `cluster.yml` as the first reaction to an outage.
2. Run `status.yml` to identify the degraded layer.
3. Run `diagnostics.yml` before repeated recovery attempts.
4. If a node is intentionally down, put it in `maintenance_nodes` before
   expecting validation to treat it as planned absence.
5. Do not power off a second Galera, Redis, or Gluster member until the first
   member is healthy again.

Fast evidence collection:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/status.yml \
  --ask-become-pass \
  -e librenms_status_alert_fail_on_degraded=true
ansible-playbook -i inventories/ha/hosts.yml playbooks/diagnostics.yml --ask-become-pass
```

## Scenario Index

| Symptom | First check | Usual next step |
| --- | --- | --- |
| VIP loads slowly after one node is powered off | VIP owner, HAProxy backends, Redis master, Galera Primary | Let detection windows settle, then tune with evidence or use `maintenance-enter.yml` for planned work |
| `validate.php` says no active dispatcher or poller not running | `librenms.service`, Redis master, `poller_cluster` rows | Wait for dispatcher recovery or restart only LibreNMS workers after Redis/DB are healthy |
| Redis write check retries or fails | Sentinel master agreement and writable Redis master | Fix Sentinel quorum/master before troubleshooting LibreNMS |
| Galera has no Primary component | `galera-recover.yml` evidence mode | Confirm one safe bootstrap host only after evidence |
| Full cluster boot has red validation | `post-reboot.yml` | Recover Galera/Redis/Gluster only if convergence fails |
| Graphs have gaps after outage | SNMPv3 from surviving poller, dispatcher status, RRD mount | Accept missed intervals; fix continuing polling/storage gaps |
| Database connection errors or intermittent schema/time validation | HAProxy DB backend state, Galera sync, DB/PHP time | Fix stale/down DB backend or time drift before app validation |

## One Node Hard Power-Off

A hard power-off is harsher than `systemctl stop` or `maintenance-enter.yml`.
The failed node cannot release VIP ownership, close TCP sessions, flush
Redis/Sentinel config, leave Galera cleanly, or stop LibreNMS workers cleanly.

Expected transient behavior:

- Keepalived moves the VIP after VRRP detection.
- HAProxy marks the failed web, DB, and RRD backends down after health checks.
- Redis Sentinel may need an election window if the powered-off node was master.
- Galera should remain Primary if two DB members are still reachable.
- Existing browser requests may wait for TCP/backend retries.

Controller checks:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/status.yml \
  --ask-become-pass \
  -e librenms_status_alert_fail_on_degraded=true
ansible-playbook -i inventories/ha/hosts.yml playbooks/diagnostics.yml --ask-become-pass
```

On surviving load balancers:

```bash
ip -o addr show | grep '192.168.1.120'
systemctl status keepalived
systemctl status haproxy
journalctl -u haproxy -n 120 --no-pager
```

If the node will stay down during the test, add it to inventory:

```yaml
maintenance_nodes:
  hosts:
    lnms1:
```

Then rerun `status.yml` or `validate.yml`. Remove the node from
`maintenance_nodes` before rejoining it.

## VIP or Web UI Takes Minutes to Load

This is not the target behavior after tuning, but it can happen while the stack
waits on a dead backend, Redis failover, Galera connection timeout, RRD storage,
or SNMP work.

Measure before changing timers:

```bash
curl -sS -o /dev/null -w '%{time_connect} %{time_starttransfer} %{time_total} %{http_code}\n' \
  http://192.168.1.120/login
```

Check the likely blockers:

```bash
systemctl status haproxy
journalctl -u haproxy -n 120 --no-pager
systemctl status redis-sentinel
redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
systemctl status mariadb
mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -Nse \
  "SHOW GLOBAL STATUS WHERE Variable_name IN ('wsrep_cluster_status','wsrep_ready');"
systemctl status rrdcached
systemctl status librenms
```

Common interpretations:

- Slow `time_connect`: VIP owner, routing, ARP, firewall, or HAProxy listener.
- Fast connect but slow `time_starttransfer`: PHP app waiting on DB, Redis,
  RRD, or SNMP.
- HAProxy still routes to a dead backend: health check interval or backend
  check type needs tuning.
- Redis master changed recently: wait for Sentinel convergence, then retest.
- Galera not Primary/Synced: fix database before app validation.

## Redis Master Failover or Write Check Fails

Retries during an intentional Redis master failover can be normal. A final
failure is not normal because LibreNMS queues, locks, sessions, and cache writes
depend on Redis.

Check every reachable Redis/Sentinel node:

```bash
systemctl status redis-server
systemctl status redis-sentinel
redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
redis-cli -p 26379 SENTINEL masters
redis-cli -p 26379 SENTINEL slaves mymaster
```

Then check the reported master:

```bash
redis-cli -h <redis-master-ip> -p 6379 PING
redis-cli -h <redis-master-ip> -p 6379 SET librenms:manual-health ok EX 30
redis-cli -h <redis-master-ip> -p 6379 GET librenms:manual-health
```

Expected state:

- Reachable Sentinels agree on one master.
- Exactly one Redis node accepts writes as master.
- Replicas follow the elected master.

If Sentinels disagree, fix Redis/Sentinel first. Restarting LibreNMS workers
while Sentinel has no stable master only recreates queue timeout errors.

## Galera Has No Primary Component

Do not randomly bootstrap a Galera node. Use the guarded recovery workflow.

Evidence-only run:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/galera-recover.yml --ask-become-pass
```

If the playbook says no safe bootstrap host can be selected, collect stopped
MariaDB recovery evidence:

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

After recovery:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/post-reboot.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml --ask-become-pass
```

## Poller Validation Says No Active Dispatcher

LibreNMS validation checks application state, not only Linux service state.
During node-loss tests, stale `poller_cluster` rows can stay visible until a
surviving dispatcher updates or stale rows age out.

Check the application workers:

```bash
systemctl status librenms
journalctl -u librenms -n 120 --no-pager
```

Check Redis before restarting workers:

```bash
redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
redis-cli -h <redis-master-ip> -p 6379 PING
```

Check the DB rows from a node that can reach MariaDB:

```bash
mysql -Nse "SELECT node_id,poller_name,last_report,master FROM librenms.poller_cluster ORDER BY last_report DESC;"
```

Expected state:

- At least one surviving dispatcher reports recently.
- Redis accepts queue and lock operations.
- The DB frontend is reachable through HAProxy.

If Redis or DB is unhealthy, fix that first. If Redis and DB are healthy but the
dispatcher is stale, restart `librenms.service` on one surviving app node and
watch the journal.

## Full Cluster Power-On

After all nodes were powered off, do not run a full redeploy first. Let
boot-time repair units and runtime gates converge, then run:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/post-reboot.yml --ask-become-pass
```

If it passes, run:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml --ask-become-pass
```

Run `cluster.yml` only if:

- inventory, templates, package state, or role defaults changed while the
  cluster was down;
- `post-reboot.yml` reports drift that cannot self-repair;
- a service unit/config is missing or wrong.

If Galera has no Primary, use `galera-recover.yml`. If Redis has no writable
master, fix Sentinel/Redis before validating LibreNMS.

## SNMPv3 Graph Gaps

Gaps during an outage are expected. RRD cannot recreate samples that were not
collected. New graph data should appear after polling resumes.

If gaps continue after validation is clean, test from a surviving poller:

```bash
snmpwalk -v3 -l authPriv -u <user> -a SHA -A '<auth-pass>' \
  -x AES -X '<priv-pass>' <node-ip> sysUpTime.0
```

Also check:

```bash
systemctl status librenms
systemctl status rrdcached
mount | grep librenms
```

Interpretation:

- SNMPv3 fails from all pollers: credentials, device ACL, firewall, or SNMP
  engine/user issue.
- SNMPv3 works but graphs do not update: dispatcher, Redis queue, RRDCacheD, or
  RRD storage path.
- Only the powered-off monitored node has gaps: expected for that outage
  interval.

## Database Schema, Time, or Intermittent DB Validation Errors

If validation alternates between OK and failure, HAProxy may be routing to a
stale or unhealthy DB backend, or DB/PHP time may differ.

Check Galera state on DB nodes:

```bash
mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -Nse \
  "SHOW GLOBAL STATUS WHERE Variable_name IN ('wsrep_cluster_status','wsrep_ready','wsrep_local_state_comment');"
```

Check DB frontend routing:

```bash
systemctl status haproxy
journalctl -u haproxy -n 120 --no-pager
```

Check time:

```bash
timedatectl
mysql -Nse "SELECT NOW(), @@global.time_zone, @@session.time_zone;"
```

Expected state:

- Every DB backend in HAProxy is reachable only when Galera is Primary/Synced.
- PHP and MySQL time are aligned.
- Schema validation is consistent regardless of backend.

If only one backend returns stale schema or time, fix that DB member before
letting HAProxy route application traffic to it.

## When To Run Each Playbook

| Situation | Playbook |
| --- | --- |
| Need a read-only HA snapshot | `status.yml` |
| Need incident evidence | `diagnostics.yml` |
| Full cluster just powered on | `post-reboot.yml` |
| Planned one-node shutdown | `maintenance-enter.yml` |
| Planned node has returned | `maintenance-exit.yml` |
| Galera has no Primary | `galera-recover.yml` |
| Inventory/config/package role changes | `cluster.yml` |
| Confirm app and HA after changes | `validate.yml` |

Prefer the narrowest playbook that matches the failure. `cluster.yml` is for
convergence after intentional changes, not a general incident hammer.
