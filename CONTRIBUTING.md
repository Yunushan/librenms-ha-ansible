# Contributing

Thank you for improving this project.

## Ground rules

- keep changes idempotent
- prefer inventory-driven behavior over hard-coded hostnames
- document new variables in README and docs
- keep destructive actions behind explicit flags
- do not quietly expand support claims without testing notes

## Before opening a pull request

Use the issue templates when reporting bugs, HA failures, or LibreNMS
validation failures. They ask for the minimum context needed to reproduce
operator problems: topology, command, failed task, node state, and relevant
diagnostics.

1. run `python scripts/ci-python-smoke.py` from Windows, or
   `python3 scripts/ci-python-smoke.py` from Linux/WSL
2. run `yamllint .`
3. run `ansible-lint`
4. run `python scripts/ci-ansible-syntax-check.py` or
   `python3 scripts/ci-ansible-syntax-check.py` from a controller with
   `ansible-playbook`
5. update relevant docs
6. explain any distro-specific package or service assumptions in the PR

You can install the same local guardrails as pre-commit hooks:

```bash
pre-commit install
pre-commit run --all-files
```

The local `python-smoke` hook does not require Ansible. The yamllint and
ansible-lint hooks still require their normal Python packages and Ansible
dependencies.

Before merging large operational changes or tagging a release, use
[docs/release-checklist.md](docs/release-checklist.md).

## Style

- use clear variable names
- keep Jinja logic readable
- put reusable defaults in role defaults or vars files
- add comments where the operational tradeoff matters
