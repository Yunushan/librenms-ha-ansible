# Maintainer Release Checklist

Use this checklist before merging large operational changes, cutting a tag, or
handing a new revision to an existing LibreNMS HA cluster. The goal is to keep
repo quality and operational safety tied together.

## Scope Review

- [ ] The change is inventory-driven and does not hard-code local hostnames,
  IPs, credentials, or device names.
- [ ] Destructive or disruptive actions require an explicit confirmation
  variable.
- [ ] Recovery workflows avoid automatic bootstrap or forced service changes
  unless the operator supplied a clear target and confirmation.
- [ ] New defaults are conservative for an already-running HA cluster.
- [ ] Any new service, timer, port, path, or credential is documented.

## Local Checks

Run the Python-only checks first. These work without Ansible installed:

```bash
python scripts/ci-python-smoke.py
```

Then run the full local gate from a Linux, WSL, Docker, or controller
environment with Ansible available:

```bash
make ci
```

If Make is not available, run the equivalent checks directly:

```bash
python scripts/ci-python-smoke.py
yamllint .
python scripts/ci-ansible-syntax-check.py
ansible-lint
```

## Inventory Examples

- [ ] `inventories/ha/hosts.yml` still validates with placeholders.
- [ ] `inventories/standalone/hosts.yml` still validates with placeholders.
- [ ] New variables have commented examples in `inventories/ha/group_vars/all.yml`
  when operators are expected to tune them.
- [ ] Example values do not imply unsupported production defaults.
- [ ] `maintenance_nodes`, `new_nodes`, and `decommission_nodes` examples remain
  safe to copy.

## Documentation

- [ ] README links to any new playbook, role, or operational workflow.
- [ ] `docs/command-map.md` tells operators which command to run for the new
  task or symptom.
- [ ] `docs/operator-checklists.md` has checklist coverage for any new
  maintenance or recovery workflow.
- [ ] `docs/failure-scenarios.md` covers new failure modes or changed behavior.
- [ ] `docs/support-matrix.md` is updated if distro, package, or service support
  changed.
- [ ] `CHANGELOG.md` has an operator-facing summary.

Check local Markdown links:

```bash
python scripts/ci-check-markdown-links.py
```

## Operational Safety

- [ ] Full-cluster restart behavior is tested or documented for any change that
  affects systemd units, timers, Redis, Galera, Gluster, HAProxy, Keepalived, or
  LibreNMS workers.
- [ ] One-node planned maintenance remains possible through
  `maintenance-enter.yml` and `maintenance-exit.yml`.
- [ ] A hard power-off of one node is either tolerated or explicitly documented
  as unsupported for the changed layer.
- [ ] `status.yml` reports degraded state for new HA drift or runtime problems.
- [ ] `diagnostics.yml` captures enough evidence for new service layers or
  failure modes.
- [ ] `validate.yml` failures distinguish planned maintenance from unexpected
  outage where practical.

## Release Notes

- [ ] `CHANGELOG.md` includes added, changed, and operator notes.
- [ ] Major upgrade or migration steps are written as commands, not prose-only
  advice.
- [ ] Any required manual step is called out before the operator reaches the
  risky command.
- [ ] Known limitations are documented instead of hidden in code comments.

## Final Gate

Before tagging or merging, run:

```bash
python scripts/ci-python-smoke.py
python scripts/ci-check-markdown-links.py
git diff --check
```

From an Ansible-capable controller, also run:

```bash
python scripts/ci-ansible-syntax-check.py
ansible-lint
```

For a production-facing release, run these against a lab HA inventory before
announcing readiness:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/doctor.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/post-reboot.yml --ask-become-pass
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml --ask-become-pass
```
