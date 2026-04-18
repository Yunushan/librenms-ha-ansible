# Experimental Dockerized LibreNMS HA

This directory adds an **optional Dockerized HA deployment model** for operators who want to run the main LibreNMS service layer in containers instead of installing packages directly on the LibreNMS nodes.

It is intentionally kept separate from the existing Ansible roles:

- the existing playbooks remain the recommended path for package-based host deployments
- this example bundle is an operator-driven Docker Compose pattern
- shared RRD storage and VIP handling still need infrastructure planning outside the app containers

## What This Bundle Covers

- LibreNMS web and dispatcher containers
- MariaDB Galera container examples
- Redis Sentinel container examples
- HAProxy container example for the web tier

## What Still Needs Operator Choice

- shared persistent storage for `/data/rrd`
- VIP ownership and failover strategy
- TLS termination
- backup and restore workflows
- image version pinning for production

## Suggested Topology

- `lnms1`, `lnms2`, `lnms3`
- each node runs the LibreNMS web container and one dispatcher container
- each node runs one Galera node container
- each node runs one Redis Sentinel node container
- one or two load-balancer nodes run HAProxy
- RRD data is mounted from shared storage such as GlusterFS, NFS, CephFS, or another replicated filesystem

## Directory Layout

- `librenms/`
- `mariadb-galera/`
- `redis-sentinel/`
- `haproxy/`

Each subdirectory contains a `compose.yml` and an `.env.example` or config template.

## Boot Order

1. Prepare shared storage for LibreNMS data and RRDs.
2. Bootstrap the first Galera node once with `--wsrep-new-cluster`, then bring up the remaining Galera nodes from the normal `compose.yml`.
3. Bring up the Redis Sentinel stack on all Redis nodes.
4. Bring up LibreNMS containers on each application node.
5. Bring up HAProxy in front of the LibreNMS web nodes.
6. Complete the first LibreNMS web bootstrap, then pin image tags and back up the data volumes.

## Per-Node Notes

- Each LibreNMS node needs its own `DISPATCHER_NODE_ID`.
- Each Galera node needs its own `WSREP_NODE_NAME` and `WSREP_NODE_ADDRESS`.
- On the Redis master node, keep `REDIS_REPLICATION_ARGS=` empty.
- On Redis replicas, set `REDIS_REPLICATION_ARGS=--replicaof <master-ip> 6379`.
- On the first Galera bootstrap node, start once with `docker compose run --rm mariadb-galera --wsrep-new-cluster`, then return to the normal compose definition.
- In the LibreNMS app env file, point `DB_HOST` at a database VIP, proxy, or a chosen Galera node.
- The HAProxy example assumes LibreNMS web containers listen on `tcp/8000`, which matches the official LibreNMS container defaults.

## Reality Check

This is an **experimental support bundle**, not a drop-in replacement for the existing host-package automation. It exists so users can choose a containerized service model if they want one, but it should be lab-tested before production.
