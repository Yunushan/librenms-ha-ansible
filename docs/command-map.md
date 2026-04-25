# LibreNMS HA Command Map

Use this map when deciding which playbook or Make target to run. The default
rule is simple: observe first, collect evidence second, and redeploy only when
there is actual configuration drift or an intentional change to apply.

For step-by-step procedures, use [operator-checklists.md](operator-checklists.md).
For detailed explanations, use [operations.md](operations.md). For symptoms and
triage, use [failure-scenarios.md](failure-scenarios.md).

## Task Map

| Situation | Run First | Make Target | Use When | Avoid |
|---|---|---|---|---|
| Pre-maintenance readiness | `playbooks/doctor.yml`, `playbooks/status.yml`, `playbooks/backup.yml`, `playbooks/validate.yml` | `make pre-maintenance` | Before shutdowns, upgrades, network work, or failover drills | Starting node work while validation is already red |
| Quick HA snapshot | `playbooks/status.yml` | `make status` or `make status-strict` | You need VIP, Galera, Redis, Gluster, dispatcher, scheduler, and drift state | Treating status as a repair action |
| Full validation | `playbooks/validate.yml` | `make validate` | After deployment, maintenance exit, post-reboot convergence, or a fix | Running it repeatedly without collecting diagnostics after a failure |
| First deployment or real config change | `playbooks/cluster.yml` | `make cluster` | Inventory, templates, package state, or role code changed | Using it as the first response to an outage |
| Full cluster powered off and back on | `playbooks/post-reboot.yml` | `make post-reboot` or `make post-restart` | Nodes returned and you need convergence checks without redeploying | Running `cluster.yml` before seeing whether boot repair converged |
| Planned one-node shutdown | `playbooks/maintenance-enter.yml` | `make maintenance-enter MAINTENANCE_TARGET=lnms1` | You can drain the node before powering it off | Hard power-off without marking planned absence |
| Planned node rejoin | `playbooks/maintenance-exit.yml` | `make maintenance-exit MAINTENANCE_TARGET=lnms1` | A maintained node is back and should rejoin HA service rotation | Manually starting services in random order |
| Hard power-off drill | `playbooks/status.yml`, then `playbooks/validate.yml` | `make status-strict`, then `make validate` | One node was forcefully powered off for HA testing | Expecting zero client-visible pause from ARP/TCP/session timeout behavior |
| Controlled failover drill | `playbooks/ha-failover-test.yml` | `make failover-drill` | Pre-flight checks and backup are clean | Running data-layer cases without a maintenance window |
| Failed validation or unstable behavior | `playbooks/diagnostics.yml` | `make diagnostics` | Before restarting services again or rerunning broad recovery | Losing evidence by repeated service restarts |
| No Galera `Primary` component | `playbooks/galera-recover.yml` | `make galera-recover` | Galera cannot form a primary component after outage | Random bootstrap, `safe_to_bootstrap` edits without recovered-position evidence |
| Backup verification | `playbooks/restore-test.yml` | `make restore-test RESTORE_TEST_BACKUP_DIR=/path` | Before relying on a backup for upgrade or recovery | Assuming backup archives are valid without read testing |
| Live firewall/listener checks | `playbooks/doctor.yml -e librenms_doctor_network_tcp_checks_enabled=true` | `make doctor-live` | Services are installed and you need real TCP reachability checks | Running before services exist and treating listener failures as firewall failures |
| AWX baseline setup | `playbooks/awx-bootstrap.yml` | `make awx-bootstrap` | AWX is reachable and you want baseline project, inventory, and templates | Treating AWX as required for CLI operation |
| Python-only local smoke check | `scripts/ci-python-smoke.py` | `make python-smoke` | You need docs, YAML, inventory, and helper-script checks without Ansible installed | Treating it as a replacement for `ansible-playbook --syntax-check` |

## Symptom Map

| Symptom | First Command | Likely Layer | Next Step |
|---|---|---|---|
| VIP loads slowly after one node is powered off | `make status-strict PLAYBOOK_FLAGS=--ask-become-pass` | Keepalived, HAProxy health checks, ARP/client TCP timeout, Redis/Galera convergence | Check VIP owner, backend state, Redis master, Galera primary; then run `validate.yml` |
| LibreNMS `/validate` says poller is not running during a planned outage | `make status PLAYBOOK_FLAGS=--ask-become-pass` | Dispatcher registration or missing `maintenance_nodes` entry | Mark intentionally down node in `maintenance_nodes`, then rerun status/validate |
| Redis write check retries then passes | `make status PLAYBOOK_FLAGS=--ask-become-pass` | Sentinel failover convergence | Accept during controlled failover if final status is healthy |
| Redis write check finally fails | `make diagnostics PLAYBOOK_FLAGS=--ask-become-pass` | Sentinel quorum, Redis master, app Redis config, firewall | Collect diagnostics, then fix Sentinel/Redis before restarting LibreNMS workers |
| Database page intermittently fails | `make status-strict PLAYBOOK_FLAGS=--ask-become-pass` | HAProxy DB backend, Galera state, schema drift, firewall | Check Galera backend states and validation schema; collect diagnostics if unstable |
| Graphs stop updating after outage | `make validate PLAYBOOK_FLAGS=--ask-become-pass` | Dispatcher, RRDCacheD, Gluster mount, SNMP reachability | Confirm dispatcher rows, RRD mount, RRDCacheD, and SNMPv3 credentials |
| Full cluster restart came back with red scheduler/dispatcher checks | `make post-reboot PLAYBOOK_FLAGS=--ask-become-pass` | Runtime dependency gate or boot-time service ordering | Let convergence finish; run `cluster.yml` only if drift remains |
| Galera has no primary after full outage | `make galera-recover PLAYBOOK_FLAGS=--ask-become-pass` | Galera bootstrap safety | Follow guarded recovery evidence and explicit bootstrap-host confirmation |
| You are unsure what changed during an incident | `make diagnostics PLAYBOOK_FLAGS=--ask-become-pass` | Unknown | Preserve current state before applying fixes |

## Command Rules

- Prefer `status.yml` for read-only HA state.
- Prefer `diagnostics.yml` before a second repair attempt.
- Prefer `post-reboot.yml` after full power-on or service convergence events.
- Prefer `maintenance-enter.yml` and `maintenance-exit.yml` for planned one-node work.
- Use `cluster.yml` for deployment and configuration convergence, not as the first incident-response command.
- Use `galera-recover.yml` only when Galera has no `Primary` component.

## Windows Controller Notes

`make syntax-check` and playbook execution require `ansible-playbook`. On a
Windows workstation, run Ansible from WSL, a Linux control node, or the project
Docker image. The Python-only smoke check can run directly on Windows:

```bash
python scripts/ci-python-smoke.py
```
