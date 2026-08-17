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
default. If it still
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
- stop only stuck LibreNMS runtime jobs and reset their failed state;
- start inactive web, PHP-FPM, Redis/Sentinel, HAProxy, Keepalived, Gluster,
  rrdcached, and LibreNMS timer units;
- repair the configured RRD mount using the existing `/etc/fstab` entry,
  including a lazy detach of the exact stale mountpoint;
- verify local Galera state without changing it.

It never stops a healthy MariaDB service, bootstraps Galera, edits
`grastate.dat`, runs database migrations, runs `daily.sh`, updates LibreNMS,
or deletes an RRD/Gluster directory. A Galera `Primary|Synced` failure still
requires the separate, operator-confirmed `galera-recover` procedure.

Do not start a second repair while one is running. If a previous `make site`
process is still attached to the terminal, press `Ctrl+C` first. Review the
repair output and then use `make status-strict` or `make doctor-live` after
the nodes are reachable again.
