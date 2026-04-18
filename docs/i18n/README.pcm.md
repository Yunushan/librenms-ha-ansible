# LibreNMS HA Ansible Deployment

Na production-minded Ansible automation wey fit deploy LibreNMS for **standalone, distributed polling, and full HA** setup across plenty Linux families.

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> Note
> English README na the canonical version. This file na full translated copy to make onboarding easier. If anything no match, follow [README.md](../../README.md).

## Why This Project Dey / Why This Exists

LibreNMS easy to run for one server, but operations go quickly rough once you need one or more of these things:

- many LibreNMS web or poller nodes
- Redis Sentinel
- Galera
- shared RRD storage
- VIP wey sit for front of Web UI and database load balancer
- repeatable rebuild after host failure
- one repo wey fit handle both standalone and HA

This repo give you one Ansible project wey fit deploy:

1. **all-in-one standalone LibreNMS**
2. **LibreNMS with distributed pollers and shared services**
3. **full HA LibreNMS** with MariaDB Galera, Redis Sentinel, HAProxy + Keepalived, and GlusterFS-backed RRD storage

---

## Wetin You Get / What You Get

- modular Ansible roles instead of one giant shell script
- inventory-driven topology selection
- standalone or cluster deployment from the same project
- optional Galera and optional Redis Sentinel
- optional VIP and load balancer layer
- optional local SNMP agent management
- SNMP **v1**, **v2c**, and **v3** support
- workflow to add and remove LibreNMS nodes
- GitHub-ready repo structure with MIT license, lint workflow, CONTRIBUTING, SECURITY, example inventories, and secret generator

---

## Topology Modes / Topology Modes

### 1) Standalone
One host fit run everything.

E good for labs, smaller environments, and single-node production with backup.

### 2) Cluster Without DB Cluster
Use many LibreNMS nodes but point them to existing external DB / Redis / storage stack.

E good for environments wey already get managed MariaDB or Redis, and for people wey want poller scale without self-hosting every HA component.

### 3) Full HA
Use:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

E good for serious internal monitoring platforms and operators wey already understand Galera / Redis / Gluster recovery.

> Important
> This project automate the platform and LibreNMS file/service layout. The first app bootstrap still dey intentionally conservative. Finish the first bootstrap with the web installer, then rerun the playbook with `librenms_bootstrap_completed: true`.

---

## Support Matrix / Support Matrix

This repo build to support the distros you want, but e do am in two levels:

| Distro | Level | Notes |
|---|---|---|
| Ubuntu | Primary | Best match with LibreNMS official docs |
| Debian | Primary | Best match with LibreNMS official docs |
| Linux Mint | Almost primary | Uses Debian-family logic |
| AlmaLinux | Strong best-effort | RedHat-family logic |
| Rocky Linux | Strong best-effort | RedHat-family logic |
| Fedora | Strong best-effort | RedHat-family logic |
| CentOS / CentOS Stream | Best-effort | Fit need repo tuning depending on PHP availability |
| Arch Linux | Best-effort | Family mapping dey; verify package names for lab |
| Manjaro Linux | Best-effort | Uses Arch-family logic |
| Alpine Linux | Best-effort | OpenRC and package differences fit need overrides |
| Gentoo | Best-effort | Package and service differences fit need overrides |

### Reality Check

LibreNMS upstream docs right now get install examples for **Ubuntu 24.04**, **Ubuntu 22.04**, **Debian 12**, **Debian 13**, and **CentOS 8**. This repo go further with family mappings wey easy to override, but you still suppose test non-primary distros for lab before production.

See:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Repository Layout / Repository Layout

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

## Quick Start / Quick Start

1. Clone the repo and install collections:

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

2. Generate secrets:

```bash
python3 scripts/generate-secrets.py > inventories/ha-3node/group_vars/vault.yml
```

or for standalone:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

3. Pick inventory:
- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha-3node/hosts.yml`

4. Fill host IPs, SSH user, `librenms_fqdn`, `librenms_app_key`, DB / Redis / VRRP secrets, VIP details, and Gluster brick settings.

5. Run deployment:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

or:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/cluster.yml
```

6. Finish first LibreNMS bootstrap for `/install`, then set:

```yaml
librenms_bootstrap_completed: true
```

and rerun the same playbook.

---

## Inventory Model / Inventory Model

This repo use inventory groups instead of hard-coded assumptions.

- `librenms_nodes`: application nodes
- `librenms_primary`: one node for primary post-bootstrap tasks
- `librenms_web`: nodes wey serve Web UI
- `librenms_db`: DB or Galera nodes
- `librenms_redis`: Redis / Sentinel nodes
- `lb_nodes`: HAProxy / Keepalived nodes
- `gluster_nodes`: shared RRD storage nodes
- `new_nodes`: nodes wey you dey add
- `decommission_nodes`: nodes wey you dey remove

---

## Variables Wey Matter Pass / Variables That Matter Most

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

## Add Node / Add a Node

Put the host for `librenms_nodes`, `librenms_web` or `librenms_poller` profile, add am to `new_nodes`, set unique `librenms_node_id`, then run:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/add-node.yml
```

The playbook go reuse `site.yml`, configure the new host, reconcile load balancer backends, and re-render Redis / Galera / app configs where e need am.

---

## Remove Node / Remove a Node

Comot the host from active groups, put am for `decommission_nodes`, then run:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/remove-node.yml
```

This one go sync the surviving cluster with the updated inventory and disable or clean up services for the removed node.

> Important
> To remove storage node from Gluster-backed RRD layer no be casual operation. The repo leave am as operator-reviewed workflow on purpose.

---

## SNMP Support / SNMP Support

- `SNMPv1`: community-based; useful if you must support legacy hardware.
- `SNMPv2c`: community-based and still common for older devices or simple rollouts.
- `SNMPv3`: recommended; repo fit configure `snmpd`, create SNMPv3 users, and set SNMP version order after bootstrap.

---

## Security Notes / Security Notes

- Put secrets for `group_vars/vault.yml` and encrypt am with **Ansible Vault**
- No commit generated vault files
- Use HTTPS in front of LibreNMS before public or semi-public exposure
- Treat Galera full-cluster recovery and Gluster membership changes as explicit operator tasks
- Test failover regularly

See:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Known Boundaries / Known Boundaries

### Things wey easy to automate
- package install
- repo checkout
- nginx / php-fpm config
- local MariaDB mode
- initial Galera join pattern
- Redis / Sentinel config
- HAProxy / Keepalived config
- LibreNMS app file deployment
- SNMP agent config
- add or remove application nodes

### Things wey still need operator review
- Galera disaster bootstrap after total outage
- Gluster peer / brick recovery after serious failure
- destructive node removal from storage cluster membership
- distro-specific package fixes for best-effort distros
- SELinux hardening fine-tuning for RedHat-family systems

---

## Verification / Verification

Run validation playbook:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/validate.yml
```

or for standalone:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

E go run practical checks for LibreNMS validator, Galera status, Redis Sentinel state, and Gluster volume status.

---

## Development / Development

Run lint locally:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Contributing / Contributing

Pull requests dey welcome. Read [CONTRIBUTING.md](../../CONTRIBUTING.md) first.

## Security / Security

Read [SECURITY.md](../../SECURITY.md) for reporting guidance.

## License / License

MIT. See [LICENSE](../../LICENSE).
