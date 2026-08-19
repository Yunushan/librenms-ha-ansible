# Fast runtime repair

`make site` is the full convergence path. It deliberately revalidates and
reconfigures every HA layer, so it is not an appropriate first response to a
stuck systemd job, an unavailable RRD mount, or a dispatcher that stopped
checking in.

Use the bounded repair path for those runtime failures:

```sh
cd /home/ansible/librenms-ha-ansible
make repair-ask-become-pass FAST_REPAIR_CONFIRM=true FAST_REPAIR_LIMIT=lnms3
```

The ask-become target gives Ansible's SSH and sudo prompt up to 60 seconds by
default. The repair also waits through transient systemd manager stalls for
up to 12 bounded probes. If it still
reports `Timeout waiting for privilege escalation prompt`, the repair has not
run: SSH succeeded but `ansible` could not become root on that host. Check the
host without changing anything:

```sh
make repair-check FAST_REPAIR_LIMIT=lnms3
```

On the affected host, verify the `ansible` account can use sudo and that its
sudo policy is valid. Run `sudo -v` interactively as `ansible`, then check the
policy with `sudo -l`; do not put the sudo password in inventory or Git. If
the three nodes use different sudo passwords, `--ask-become-pass` cannot use
one password for all of them; use per-host vaulted credentials or standardize
the sudo policy. A passwordless sudo policy is also suitable for an
automation-only account. After fixing `lnms3`, rerun the bounded repair.

You can override the timeout for a slow but healthy sudo/PAM path:

```sh
make repair-ask-become-pass FAST_REPAIR_CONFIRM=true FAST_REPAIR_LIMIT=lnms3 FAST_REPAIR_BECOME_TIMEOUT=120
```

If privilege escalation succeeds but the repair reports that systemd is not
responsive, inspect the host instead of starting the full site playbook:

```sh
ssh -tt ansible@<lnms3-ip> 'sudo systemctl is-system-running; sudo systemctl list-jobs --no-pager'
```

After systemd responds again, rerun the bounded repair. The repair never
bootstraps Galera or restarts a healthy MariaDB service.

After repairing one node, verify it, then repair the remaining nodes one at a
time:

```sh
make repair-ask-become-pass FAST_REPAIR_CONFIRM=true FAST_REPAIR_LIMIT=lnms1
make repair-ask-become-pass FAST_REPAIR_CONFIRM=true FAST_REPAIR_LIMIT=lnms2
```

To repair all nodes serially:

```sh
make repair-ask-become-pass FAST_REPAIR_CONFIRM=true
```

The target uses Ansible `raw`, so it can still run when a managed host has a
broken `ansible_python_interpreter`. It has bounded systemd, mount, and probe
operations and reports a failure instead of waiting indefinitely.

The repair path may:

- cancel stale LibreNMS maintenance jobs;
- stop only stuck LibreNMS runtime jobs, wait for systemd to confirm they are
  inactive, and use bounded `SIGTERM`/`SIGKILL` escalation against only the
  unresolved service cgroup before resetting its failed state;
- enable and start inactive web, PHP-FPM, Redis/Sentinel, HAProxy, Keepalived,
  Gluster, rrdcached, and LibreNMS timer units;
- start Redis/Sentinel and rrdcached before `librenms.service`, whose runtime
  gate depends on those services;
- verify a local Galera member is `Primary|Synced`, repair its bounded
  readiness listener when necessary, reconcile stale runtime files to the
  configured local Galera endpoint, and run the deployed runtime gate before
  queuing `librenms.service`; this avoids database VIP transitions for
  co-located web/database nodes and prevents a failed endpoint from leaving
  the service stuck in `activating`;
- atomically update only the `DB_HOST` assignments in `.env`, the runtime wait
  helper, and the dispatcher recovery helper when local Galera preference is
  enabled; older runtime-wait helpers receive the missing compatibility
  setting after `DB_HOST` while fast repair's direct `Primary|Synced` check
  remains authoritative, duplicate settings fail closed, and an explicit
  `librenms_db_host` remains authoritative;
- clear the stale Laravel configuration cache and gracefully reload active
  PHP-FPM services only after the replacement local database path passes its
  authenticated runtime gate;
- report bounded readiness-agent, configured database path, HAProxy, unit,
  journal, and runtime-gate diagnostics when an application service still
  cannot start;
- repair the configured RRD mount using the existing `/etc/fstab` entry,
  including a lazy detach of the exact stale mountpoint and a bounded
  create/read/delete probe as the `librenms` user;
- verify local Galera state with bounded retries without changing it. A
  transient SQL/socket or Galera state response is retried before the repair
  is reported failed.

If shared RRD recovery fails, the repair reports bounded Gluster and mount
diagnostics and leaves `librenms.service`, `rrdcached`, and LibreNMS
maintenance timers stopped. This prevents them from writing to the local
mountpoint directory while the shared filesystem is unavailable.

It never stops a healthy MariaDB service, bootstraps Galera, edits
`grastate.dat`, runs database migrations, runs `daily.sh`, updates LibreNMS,
or deletes an RRD/Gluster directory. A Galera `Primary|Synced` failure still
requires the separate, operator-confirmed `galera-recover` procedure.

Do not start a second repair while one is running. If a previous `make site`
process is still attached to the terminal, press `Ctrl+C` first. Review the
repair output and then use `make status-strict` or `make doctor-live` after
the nodes are reachable again. To ensure strict status does not run after a
failed repair, chain the commands:

```sh
make repair-ask-become-pass FAST_REPAIR_CONFIRM=true FAST_REPAIR_LIMIT=lnms2 && \
  make status-strict PLAYBOOK_FLAGS=--ask-become-pass
```
