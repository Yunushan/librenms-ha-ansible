# LibreNMS HA Operations Runbook

Use this runbook for planned maintenance, failover drills, and post-outage
recovery. The goal is to keep checks repeatable and avoid changing several
layers at once.

## Routine Command Order

Before planned maintenance:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/doctor.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/backup.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml --ask-become-pass
```

After changes or a node reboot:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml --ask-become-pass
```

Before trusting failover behavior:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/ha-failover-test.yml \
  --ask-become-pass \
  -e librenms_failover_test_confirm=true
```

## Planned Single-Node Maintenance

1. Confirm `validate.yml` is clean.
2. If the node owns the VIP, move it away first:

```bash
sudo systemctl stop keepalived
```

3. Wait until another load balancer owns the VIP:

```bash
ip -o addr show | grep '<VIP>/<CIDR>'
```

4. Reboot or maintain only that one node.
5. After it returns, run `cluster.yml`, then `validate.yml`.

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

After all nodes return:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml --ask-become-pass
```

If Galera has no `Primary` component, do not randomly bootstrap a node. Use the
Galera recovery guidance emitted by the playbook and bootstrap only the safest
node.

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

Restore should be treated as a maintenance event:

1. Stop LibreNMS workers and web traffic.
2. Restore database to one safe MariaDB/Galera node.
3. Restore config/RRD data only from the matching backup timestamp.
4. Run `cluster.yml`.
5. Run `validate.yml`.

Do not restore one Galera member with old data while the rest of the cluster is
running with newer writes.
