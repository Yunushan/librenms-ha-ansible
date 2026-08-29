# Podman LibreNMS HA Profile

This optional profile runs the same reviewed Compose service definitions as the
Docker profile through Podman's Compose provider. It is isolated from the
package-based Ansible deployment and must be selected explicitly.

Prepare one `.env` file in each selected directory under
`examples/docker-ha/`, use approved immutable image references, and verify
shared RRD storage, Galera bootstrap ownership, Redis Sentinel quorum, backups,
and the frontend failover design before production use.

Preflight and lifecycle commands are exposed by the root Makefile:

```bash
make podman-ha \
  CONTAINER_PLATFORM_LIMIT=podman-host-1 \
  CONTAINER_PLATFORM_ACTION=preflight

make podman-ha \
  CONTAINER_PLATFORM_LIMIT=podman-host-1 \
  CONTAINER_PLATFORM_ACTION=deploy \
  CONTAINER_PLATFORM_CONFIRM=true
```

The target expects `podman compose` by default. Set
`ANSIBLE_EXTRA_ARGS="-e librenms_container_compose_command=['podman-compose']"`
when the host uses the standalone `podman-compose` provider instead.
