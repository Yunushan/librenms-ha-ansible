## Summary

- 

## Change Type

- [ ] Bug fix
- [ ] HA behavior or recovery change
- [ ] New feature or playbook
- [ ] Documentation only
- [ ] CI or developer tooling
- [ ] Inventory example or defaults change

## Operational Impact

- [ ] No runtime behavior change
- [ ] May restart services
- [ ] May affect HA failover behavior
- [ ] May affect Galera, Redis Sentinel, GlusterFS, or RRD storage
- [ ] Requires operator action after upgrade

## Validation

- [ ] `python scripts/ci-python-smoke.py`
- [ ] `yamllint .`
- [ ] `ansible-lint`
- [ ] `python scripts/ci-ansible-syntax-check.py`
- [ ] Lab run against standalone inventory
- [ ] Lab run against HA inventory
- [ ] Not run; explain below

## Operator Notes

Describe any migration steps, expected downtime, maintenance-node handling,
or rollback considerations.

## Checklist

- [ ] Variables are inventory-driven and documented.
- [ ] Destructive actions require explicit confirmation or flags.
- [ ] HA changes handle intentionally unavailable maintenance nodes.
- [ ] User-facing docs or runbooks were updated.
- [ ] `CHANGELOG.md` was updated for operator-facing changes.

