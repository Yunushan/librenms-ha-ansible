# Contributing

Thank you for improving this project.

## Ground rules

- keep changes idempotent
- prefer inventory-driven behavior over hard-coded hostnames
- document new variables in README and docs
- keep destructive actions behind explicit flags
- do not quietly expand support claims without testing notes

## Before opening a pull request

1. run `yamllint .`
2. run `ansible-lint`
3. update relevant docs
4. explain any distro-specific package or service assumptions in the PR

## Style

- use clear variable names
- keep Jinja logic readable
- put reusable defaults in role defaults or vars files
- add comments where the operational tradeoff matters
