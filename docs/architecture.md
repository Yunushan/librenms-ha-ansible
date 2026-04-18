# Architecture and Operating Model

## Design goals

This repository supports three practical patterns:

1. **Standalone**
2. **Clustered app nodes with external shared services**
3. **Full HA**

## Full HA reference topology

```text
             VIP / FQDN
         librenms.example.com
                  |
         HAProxy + Keepalived
      ┌───────────┼───────────┐
      │           │           │
    lnms1       lnms2       lnms3
      │           │           │
      ├── LibreNMS Web / Poller / Dispatcher
      ├── MariaDB Galera
      ├── Redis + Sentinel
      ├── GlusterFS brick
      └── Nginx + PHP-FPM
```

## Inventory groups

- `librenms_nodes`: app nodes
- `librenms_primary`: one node for one-time post-bootstrap config tasks
- `librenms_db`: database hosts
- `librenms_redis`: redis and sentinel hosts
- `lb_nodes`: haproxy / keepalived hosts
- `gluster_nodes`: shared RRD storage hosts

## Operating advice

### Safe to automate aggressively

- app nodes joining the cluster
- nginx / php-fpm changes
- new web or poller nodes
- haproxy backend updates
- redis replica or sentinel config changes

### Automate, but treat carefully

- initial galera cluster bootstrap
- initial gluster volume creation

### Keep operator-reviewed

- total galera cluster recovery after all nodes are down
- gluster split-brain recovery
- destructive brick removal
- topology changes on best-effort distros without lab verification

## Full HA expectations

For full HA, this repo expects:

- at least **3 DB nodes** for Galera
- at least **3 Redis nodes** for Sentinel quorum
- shared RRD storage through GlusterFS or another external storage layer
- a consistent `APP_KEY` on every LibreNMS node
- a unique `NODE_ID` on every LibreNMS node

## About adding and removing nodes

### App node
Low-risk and inventory-driven.

### DB node
Supported as a planned change, but test carefully.

### Redis node
Supported as a planned change, but test carefully.

### Gluster node
Not treated as a casual operation. Rebalance and brick removal remain operator-reviewed.
