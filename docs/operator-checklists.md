# LibreNMS HA Operator Checklists

Use these checklists during planned maintenance, hard power-off tests, full
cluster restarts, and post-change validation. They are intentionally procedural:
copy the relevant section into a ticket or change record and check each item as
you go.

The detailed explanation for each workflow is in
[operations.md](operations.md). If you only need to choose the right command,
use [command-map.md](command-map.md). Failure-mode behavior is summarized in
[failure-scenarios.md](failure-scenarios.md).

## Common Pre-Flight

Run this before any maintenance, failover test, upgrade, or storage/network
change.

- [ ] Confirm the Ansible inventory matches the real cluster.
- [ ] Confirm only the intentionally unavailable hosts are listed in
  `maintenance_nodes`.
- [ ] Confirm no previous node is still rejoining Galera, Redis, or Gluster.
- [ ] Confirm time sync is healthy on every node.
- [ ] Confirm you have console or hypervisor access for every node.
- [ ] Confirm the latest backup location is known and accessible.

```bash
make doctor-live PLAYBOOK_FLAGS=--ask-become-pass
make status-strict PLAYBOOK_FLAGS=--ask-become-pass
make backup PLAYBOOK_FLAGS=--ask-become-pass
make validate PLAYBOOK_FLAGS=--ask-become-pass
```

Pass criteria:

- `doctor-live` reports no route or TCP reachability failures.
- `status-strict` reports no degraded HA state.
- `backup` completes and records a backup directory.
- `validate` is clean before touching the cluster.

## Planned Single-Node Maintenance

Use this for an intentional shutdown, OS patching, package work, VM work, or a
rolling major OS upgrade on one node.

- [ ] Run the common pre-flight checklist.
- [ ] Choose exactly one target node.
- [ ] Drain the target node.

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/maintenance-enter.yml \
  --ask-become-pass \
  -e librenms_maintenance_target=lnms1 \
  -e librenms_maintenance_confirm=true
```

- [ ] Add the target to `maintenance_nodes` while it is intentionally down.

```yaml
maintenance_nodes:
  hosts:
    lnms1:
```

- [ ] Power off, patch, upgrade, or repair the target node.
- [ ] Power the node back on and wait for SSH.
- [ ] Remove the target from `maintenance_nodes`.
- [ ] Rejoin the target node.

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/maintenance-exit.yml \
  --ask-become-pass \
  -e librenms_maintenance_target=lnms1 \
  -e librenms_maintenance_confirm=true
ansible-playbook -i inventories/ha/hosts.yml playbooks/post-reboot.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml --ask-become-pass
```

Pass criteria:

- The VIP is reachable.
- Galera reports a primary component and synced reachable DB nodes.
- Redis Sentinel reports one writable master.
- Gluster is mounted and RRDCacheD is reachable.
- LibreNMS validation is green.
- LibreNMS device pages resume graph updates after the next poll cycle.

Do not begin maintenance on another Galera, Redis, or Gluster member until this
checklist passes.

## Hard Power-Off Test

Use this only in a maintenance window or lab. A hard power-off is intentionally
rougher than `maintenance-enter.yml`: the failed node cannot withdraw the VIP,
close client TCP sessions, flush Redis/Sentinel state, or leave Galera cleanly.

- [ ] Run the common pre-flight checklist.
- [ ] Choose one target node.
- [ ] Add the target to `maintenance_nodes` if you want validation and status
  checks to treat the absence as planned during the test.
- [ ] Power off the target through the hypervisor or physical power control.
- [ ] Wait for HA checks and client ARP/TCP sessions to settle.

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/status.yml \
  --ask-become-pass \
  -e librenms_status_alert_fail_on_degraded=true
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml --ask-become-pass
```

Pass criteria while the target is down:

- The VIP remains reachable on a surviving load balancer.
- Login and normal LibreNMS page loads work through the VIP.
- Redis Sentinel has promoted or retained exactly one writable master.
- Galera remains `Primary` on the surviving database members.
- The poller check ignores only the intentionally powered-off node.

Recovery:

- [ ] Power the target node back on.
- [ ] Wait for SSH.
- [ ] Remove the target from `maintenance_nodes`.
- [ ] Run convergence and validation.

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/post-reboot.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml --ask-become-pass
```

Expected temporary behavior:

- The VIP can pause briefly while VRRP and client ARP caches converge.
- Redis write checks may retry during Sentinel failover.
- Poller rows and graphs may lag until the next poller registration and poll
  cycle.

## Full Cluster Restart

Use this after hypervisor maintenance, lab power testing, or a controlled full
shutdown.

- [ ] Run the common pre-flight checklist if the cluster is still online.
- [ ] Stop external traffic or notify users of the outage.
- [ ] Shut down nodes cleanly where possible.
- [ ] Start at least two HA nodes before judging cluster health.
- [ ] Wait for SSH on all expected online nodes.
- [ ] Run the post-reboot convergence playbook before rerunning the full
  deployment.

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/post-reboot.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/status.yml \
  --ask-become-pass \
  -e librenms_status_alert_fail_on_degraded=true
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml --ask-become-pass
```

Pass criteria:

- Runtime gates report that DB, Redis, and RRD storage are usable.
- Scheduler and dispatcher services are active where expected.
- The VIP is reachable and owned by one load balancer.
- Galera, Redis Sentinel, Gluster, HAProxy, and Keepalived are healthy.
- LibreNMS validation is green.

Run `cluster.yml` only after this checklist if convergence reports drift that
cannot self-repair, or if inventory/role code changed while the cluster was
down.

## Failed Validation Triage

Use this when `validate.yml`, `status.yml`, `post-reboot.yml`, or a failover
test fails.

- [ ] Stop making additional changes.
- [ ] Collect diagnostics before restarting services again.

```bash
make diagnostics PLAYBOOK_FLAGS=--ask-become-pass
```

- [ ] Read the failed section first: database, poller, Redis, RRD, scheduler,
  or user/filesystem.
- [ ] Compare the failed node list against `maintenance_nodes`.
- [ ] Check whether the failure is a real service failure or a convergence lag.
- [ ] Fix one layer at a time.
- [ ] Rerun `status-strict`, then `validate`.

```bash
make status-strict PLAYBOOK_FLAGS=--ask-become-pass
make validate PLAYBOOK_FLAGS=--ask-become-pass
```

Do not rerun `cluster.yml` blindly before collecting diagnostics. Repeated
service restarts can hide the state that explains the original failure.
