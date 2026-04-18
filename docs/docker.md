# Docker Support

This repository supports two separate Docker use cases:

1. running the **Ansible controller toolchain inside Docker**
2. using the **experimental Dockerized HA example bundle** under [examples/docker-ha](../examples/docker-ha/README.md)

## 1) Dockerized Controller

The controller-side Docker support is for:

- linting
- collection installation baked into the image
- running `ansible-playbook` from a containerized controller
- keeping the host clean of local Ansible / Python tooling

It does **not** change the existing Ansible playbooks into container-orchestration playbooks.

## Included Files

- `Dockerfile`
- `compose.yaml`

## Build the Controller Image

```bash
docker compose build ansible
```

## Lint from Docker

```bash
docker compose run --rm ansible make lint
```

## Open an Interactive Shell

```bash
docker compose run --rm ansible bash
```

## Run Playbooks from Docker

The container needs SSH keys and known-host data to reach your managed nodes.

### Linux / macOS

```bash
docker compose run --rm \
  -v "$HOME/.ssh:/root/.ssh:ro" \
  ansible \
  ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml
```

### Windows PowerShell

```powershell
docker compose run --rm `
  -v "${env:USERPROFILE}\.ssh:/root/.ssh:ro" `
  ansible `
  ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml
```

## Notes

- `ansible.cfg` is loaded from `/workspace/ansible.cfg`.
- The repo is bind-mounted into `/workspace`.
- Ansible collections are installed in the image under `/usr/share/ansible/collections`.
- If you change `requirements.yml`, rebuild the image.
- If your controller relies on SSH agent forwarding instead of direct key files, add your own `docker compose run` flags or override file.

## 2) Experimental Dockerized HA Bundle

If you want containerized LibreNMS service examples instead of host-package deployment, use:

- [examples/docker-ha/README.md](../examples/docker-ha/README.md)

That bundle includes Compose examples for:

- LibreNMS web and dispatcher containers
- MariaDB Galera containers
- Redis Sentinel containers
- HAProxy

It is intentionally documented as **experimental** and **operator-driven**. Shared RRD storage, VIP failover, TLS termination, and production image pinning still need deliberate infrastructure choices.
