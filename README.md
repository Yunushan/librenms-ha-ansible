# LibreNMS Ansible Deployment

Production-minded Ansible automation for **LibreNMS standalone, distributed polling, and full HA** deployments across multiple Linux families.

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

Quick Start • Topology Modes • Support Matrix • Inventory Model • Variables • Add / Remove Nodes • Security • Contributing

---

## Why This Exists

LibreNMS is easy to get running on one server, but it becomes operationally messy as soon as you want one or more of these:

- multiple LibreNMS web or poller nodes
- Redis Sentinel
- Galera
- shared RRD storage
- a VIP in front of the Web UI and database load balancer
- repeatable rebuilds after a host failure
- one repo that can handle both standalone and HA

This repository gives you one Ansible project that can deploy:

1. **Standalone all-in-one LibreNMS**
2. **Distributed poller / shared-service LibreNMS**
3. **Full HA LibreNMS** with:
   - multiple web or full nodes
   - MariaDB Galera
   - Redis Sentinel
   - HAProxy + Keepalived
   - GlusterFS-backed RRD storage

---

## What You Get

- modular Ansible roles instead of one giant shell script
- inventory-driven topology selection
- standalone or cluster deployments from the same project
- optional Galera and optional Redis Sentinel
- optional VIP and load-balancer layer
- optional local SNMP agent management
- support for SNMP **v1**, **v2c**, and **v3**
- workflows for **adding** and **removing** LibreNMS nodes
- GitHub-ready repo structure with:
  - MIT license
  - lint workflow
  - CONTRIBUTING and SECURITY docs
  - example inventories
  - helper secret generator

---

## Topology Modes

### 1) Standalone
Use one host for everything.

Good for:
- labs
- smaller environments
- single-node production with backups

### 2) Cluster without DB cluster
Use multiple LibreNMS nodes but point them to an existing external DB / Redis / storage stack.

Good for:
- environments with managed MariaDB or Redis
- users who want poller scale without self-hosting every HA component

### 3) Full HA
Use:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

Good for:
- serious internal monitoring platforms
- environments that need web and poller survivability
- operators who already understand Galera / Redis / Gluster recovery

> Important  
> This project automates the platform and the LibreNMS filesystem and service layout. The initial app bootstrap is still intentionally conservative. Finish the first application bootstrap with the web installer, then rerun the playbook with `librenms_bootstrap_completed: true` to apply post-bootstrap settings cleanly.

---

## Support Matrix

This repository is built to support the distributions you asked for, but it does so in two tiers:

| Distro | Tier | Notes |
|---|---|---|
| Ubuntu | Primary | Best fit with upstream LibreNMS docs |
| Debian | Primary | Best fit with upstream LibreNMS docs |
| Linux Mint | Primary-ish | Uses Debian-family logic |
| AlmaLinux | Strong best-effort | RedHat-family logic |
| Rocky Linux | Strong best-effort | RedHat-family logic |
| Fedora | Strong best-effort | RedHat-family logic |
| CentOS / CentOS Stream | Best-effort | May need repo tuning depending on PHP availability |
| Arch Linux | Best-effort | Family mapping included, verify package names in lab |
| Manjaro Linux | Best-effort | Uses Arch-family logic |
| Alpine Linux | Best-effort | OpenRC / package differences may need overrides |
| Gentoo | Best-effort | Package atom and service differences may need overrides |

### Reality check

Upstream LibreNMS documentation currently provides package/install examples for **Ubuntu 24.04**, **Ubuntu 22.04**, **Debian 12**, **Debian 13**, and **CentOS 8**. This repo extends beyond that with override-friendly family mappings, but you should lab-test non-primary distros before production.

See also:
- [docs/support-matrix.md](docs/support-matrix.md)
- [docs/architecture.md](docs/architecture.md)

---

## Repository Layout

```text
.
├── .github/workflows/lint.yml
├── docs/
├── inventories/
│   ├── ha-3node/
│   └── standalone/
├── playbooks/
│   ├── site.yml
│   ├── cluster.yml
│   ├── standalone.yml
│   ├── add-node.yml
│   ├── remove-node.yml
│   └── validate.yml
├── roles/
│   ├── common/
│   ├── mariadb/
│   ├── galera/
│   ├── redis_sentinel/
│   ├── glusterfs_rrd/
│   ├── haproxy_keepalived/
│   ├── librenms_app/
│   ├── snmpd/
│   ├── remove_node/
│   └── validate/
├── scripts/generate-secrets.py
├── ansible.cfg
├── requirements.yml
└── README.md
```

---

## Quick Start

### 1) Clone and install collections

```bash
git clone https://github.com/your-org/librenms-ansible.git
cd librenms-ansible
ansible-galaxy collection install -r requirements.yml
```

### 2) Generate secrets

```bash
python3 scripts/generate-secrets.py > inventories/ha-3node/group_vars/vault.yml
```

or for standalone:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

### 3) Pick an inventory

- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha-3node/hosts.yml`

### 4) Edit the inventory and group vars

At minimum, set:

- host IPs and SSH user
- `librenms_fqdn`
- `librenms_app_key`
- DB / Redis / VRRP secrets
- VIP details for HA
- Gluster brick settings for HA

### 5) Run the deployment

Standalone:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

HA / clustered:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/cluster.yml
```

### 6) Complete the first LibreNMS bootstrap

Open the site and finish the first app bootstrap:

```text
http://librenms.example.com/install
```

or on standalone:

```text
http://<your-hostname-or-ip>/install
```

Then set:

```yaml
librenms_bootstrap_completed: true
```

and rerun the same playbook. That enables the post-bootstrap `lnms config:set` tasks cleanly.

---

## Inventory Model

This repo uses inventory groups instead of hard-coded assumptions.

### Core groups

- `librenms_nodes` — application nodes
- `librenms_primary` — one node used for primary post-bootstrap config tasks
- `librenms_web` — nodes serving the Web UI
- `librenms_db` — DB or Galera nodes
- `librenms_redis` — Redis / Sentinel nodes
- `lb_nodes` — HAProxy / Keepalived nodes
- `gluster_nodes` — shared RRD storage nodes

### Lifecycle groups

- `new_nodes` — nodes you are adding
- `decommission_nodes` — nodes being removed

---

## Variables That Matter Most

### Installation mode

```yaml
librenms_mode: standalone           # standalone | cluster | ha
librenms_install_profile: full      # full | web | poller
```

### Database mode

```yaml
librenms_db_mode: local             # local | external | galera
librenms_db_host: ""
librenms_db_name: librenms
librenms_db_user: librenms
librenms_db_password: CHANGE_ME
```

### Redis mode

```yaml
librenms_redis_mode: local          # local | external | sentinel
librenms_redis_password: CHANGE_ME
librenms_redis_sentinel_password: CHANGE_ME
librenms_redis_master_host: lnms1
```

### RRD storage mode

```yaml
librenms_rrd_mode: local            # local | glusterfs | external
```

### VIP / HAProxy / Keepalived

```yaml
librenms_vip_enabled: true
librenms_vip_ip: 10.10.10.10
librenms_vip_cidr: 24
librenms_vip_interface: ens18
```

### SNMP

```yaml
librenms_snmp_versions_enabled:
  - v1
  - v2c
  - v3

librenms_snmp_v2c_community: CHANGEME

librenms_snmp_v3_users:
  - username: lnmsv3
    auth_protocol: SHA
    auth_password: CHANGE_ME_AUTH
    priv_protocol: AES
    priv_password: CHANGE_ME_PRIV
    access: ro
```

---

## Add a Node

### Add a new LibreNMS application node

1. Add the host to:
   - `librenms_nodes`
   - `librenms_web` or `librenms_poller`-style usage through `librenms_install_profile`
   - `new_nodes`
2. Give it a unique `librenms_node_id`
3. Rerun:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/add-node.yml
```

The playbook reuses `site.yml`, which:
- configures the new host
- reconciles load balancer backends
- re-renders Redis / Galera / app configs where needed

> Tip  
> For a **web/poller node**, this is the safest scaling path.  
> For a **Galera**, **Redis**, or **Gluster** membership change, test the workflow in a lab first and read [docs/architecture.md](docs/architecture.md). Storage membership changes are intentionally more conservative than web node changes.

---

## Remove a Node

1. Move the host out of the active groups (`librenms_nodes`, `librenms_web`, `librenms_db`, `librenms_redis`, `lb_nodes`, `gluster_nodes`)
2. Put it in `decommission_nodes`
3. Run:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/remove-node.yml
```

This does two things:
- reconciles the surviving cluster with the updated inventory
- disables and optionally cleans up services on the removed node

> Important  
> Removing a storage node from a Gluster-backed RRD layer is not treated as a casual operation. The repo leaves that as an operator-reviewed workflow on purpose.

---

## SNMP Support

This repo supports three SNMP modes:

### SNMPv1
Community-based. Useful only when you must support legacy hardware.

### SNMPv2c
Community-based and still common for older devices or simple rollouts.

### SNMPv3
Recommended where devices support it. This repo can:
- configure local `snmpd`
- create SNMPv3 users
- set LibreNMS SNMP version order after bootstrap

> Note  
> On the local agent side, SNMPv1 and SNMPv2c both use community-based agent configuration. The difference mainly matters when LibreNMS talks to monitored devices.

---

## Security Notes

- Put secrets in `group_vars/vault.yml` and encrypt with **Ansible Vault**
- Do not commit generated vault files
- Use HTTPS in front of LibreNMS before public or semi-public exposure
- Treat Galera full-cluster recovery and Gluster membership changes as explicit operator tasks
- Test failover regularly

See:
- [SECURITY.md](SECURITY.md)
- [docs/architecture.md](docs/architecture.md)

---

## Known Boundaries

This project is intentionally honest about the hard parts.

### Fully comfortable to automate
- package install
- repo checkout
- nginx / php-fpm config
- MariaDB local mode
- Galera initial node join pattern
- Redis / Sentinel config
- HAProxy / Keepalived config
- LibreNMS app file deployment
- SNMP agent config
- add/remove **application** nodes

### Operator-reviewed by design
- Galera disaster bootstrap after total outage
- Gluster peer / brick recovery after a bad failure
- destructive node removal from storage cluster membership
- distro-specific package corrections on best-effort distros
- SELinux hardening fine-tuning on RedHat-family systems

---

## Verification

Run the validation playbook:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/validate.yml
```

or for standalone:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

It runs a practical set of checks against:
- LibreNMS validator
- Galera status
- Redis Sentinel state
- Gluster volume status

---

## Development

Lint locally:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Contributing

Pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## Security

Please read [SECURITY.md](SECURITY.md) for reporting guidance.

## License

MIT. See [LICENSE](LICENSE).
