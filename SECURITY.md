# Security Policy

## Supported branches

This repository is intended to track the current main branch.

## Reporting a vulnerability

Please do not open public issues for sensitive vulnerabilities.

Instead:
1. prepare a minimal reproduction
2. describe the impact and likely affected roles
3. share the report privately with the maintainer

## Operational security notes

- store secrets in Ansible Vault, not plain group vars
- do not expose LibreNMS setup or HTTP endpoints publicly without TLS
- test failover and recovery before production rollout
