# Security Policy

## Supported branches

This repository is intended to track the current main branch.

## Reporting a vulnerability

Please do not open public issues for sensitive vulnerabilities. Use GitHub's
[private vulnerability reporting form](https://github.com/Yunushan/librenms-ha-ansible/security/advisories/new)
instead.

Include a minimal reproduction, impact, affected roles, and any suggested
mitigation. Do not include credentials, private keys, or production data.

## Operational security notes

- store secrets in Ansible Vault, not plain group vars
- do not expose LibreNMS setup or HTTP endpoints publicly without TLS
- test failover and recovery before production rollout
- keep GitHub secret-scanning push protection, Dependabot alerts and security
  updates, and CodeQL default setup enabled
- protect `main` with required CI checks, linear history, resolved review
  conversations, and force-push/deletion protection
