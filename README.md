# LibreNMS HA Ansible Deployment

Production-minded Ansible automation for **LibreNMS standalone, distributed polling, and full HA** deployments across multiple Linux families.

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

## README Languages

The English README is the canonical version. The links below point to full translated README copies for widely used world languages. If any translation lags behind, follow the English README.

| Language | Language | Language | Language | Language |
|---|---|---|---|---|
| [English](README.md) | [中文(简体)](docs/i18n/README.zh-CN.md) | [हिन्दी](docs/i18n/README.hi.md) | [Español](docs/i18n/README.es.md) | [Français](docs/i18n/README.fr.md) |
| [العربية](docs/i18n/README.ar.md) | [বাংলা](docs/i18n/README.bn.md) | [Português](docs/i18n/README.pt.md) | [Русский](docs/i18n/README.ru.md) | [اردو](docs/i18n/README.ur.md) |
| [Bahasa Indonesia](docs/i18n/README.id.md) | [Deutsch](docs/i18n/README.de.md) | [日本語](docs/i18n/README.ja.md) | [Naija Pidgin](docs/i18n/README.pcm.md) | [मराठी](docs/i18n/README.mr.md) |
| [తెలుగు](docs/i18n/README.te.md) | [Türkçe](docs/i18n/README.tr.md) | [தமிழ்](docs/i18n/README.ta.md) | [粵語](docs/i18n/README.yue.md) | [Tiếng Việt](docs/i18n/README.vi.md) |

Quick Start • Topology Modes • Support Matrix • Network and Access Matrix • Inventory Model • Variables • Add / Remove Nodes • Security • Contributing

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
4. **Experimental Dockerized HA bundle** for operators who want containerized LibreNMS, Galera, Redis Sentinel, and HAProxy examples
5. **Optional AWX controller** for GUI-based playbook execution, scheduling, RBAC, and run history

---

## What You Get

- modular Ansible roles instead of one giant shell script
- inventory-driven topology selection
- standalone or cluster deployments from the same project
- optional Galera and optional Redis Sentinel
- optional VIP and load-balancer layer
- optional local SNMP agent management
- support for SNMP **v1**, **v2c**, and **v3**
- optional experimental Dockerized HA example bundle for operators who prefer containerized service layers
- optional AWX controller deployment for teams that want GUI-driven operations
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
> By default, post-bootstrap tasks are applied automatically because
> `librenms_bootstrap_auto_complete: true` is the default. Finish the first
> application bootstrap with the web installer, then rerun the same playbook
> without editing inventory. Only use the older two-phase flow if you
> explicitly set `librenms_bootstrap_auto_complete: false`; in that mode,
> complete the installer first, then rerun with
> `librenms_bootstrap_completed: true`.

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
- [examples/docker-ha/README.md](examples/docker-ha/README.md)

---

## Repository Layout

```text
.
├── .github/workflows/lint.yml
├── Dockerfile
├── compose.yaml
├── docs/
│   ├── architecture.md
│   └── docker.md
├── examples/
│   └── docker-ha/
├── inventories/
│   ├── ha/
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
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

### Optional: use a Docker-based controller

If you do not want to install Ansible tooling directly on the controller host, this repo also includes a containerized controller workflow.

Build the image:

```bash
docker compose build ansible
```

Run lint inside Docker:

```bash
docker compose run --rm ansible make lint
```

Run the HA playbook inside Docker with your SSH keys mounted:

```bash
docker compose run --rm \
  -v "$HOME/.ssh:/root/.ssh:ro" \
  ansible \
  ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml
```

See also:
- [docs/docker.md](docs/docker.md)
- [examples/docker-ha/README.md](examples/docker-ha/README.md)

### Optional: deploy an AWX controller

If you want a GUI for running and scheduling these playbooks, add a dedicated VM to the `ansible_controller` inventory group and enable:

```yaml
awx_controller_enabled: true
```

Then run:

```bash
make awx-controller
```

The optional AWX role can install k3s on the controller VM or use an existing Kubernetes cluster. It is deliberately separate from the main LibreNMS deployment because AWX has its own Kubernetes, PostgreSQL, credential, backup, and upgrade lifecycle.

See [docs/awx-controller.md](docs/awx-controller.md).

### 2) Generate secrets

```bash
python3 scripts/generate-secrets.py > inventories/ha/group_vars/vault.yml
```

or for standalone:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

### 3) Pick an inventory

- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha/hosts.yml`

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
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml
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

Then rerun the same playbook. By default, no inventory change is required,
because `librenms_bootstrap_auto_complete: true` enables the post-bootstrap
`lnms config:set` tasks automatically.

If you explicitly want the older conservative two-phase flow, set:

```yaml
librenms_bootstrap_auto_complete: false
```

complete the installer, then rerun with:

```yaml
librenms_bootstrap_completed: true
```

---

## Network and Access Matrix

### Controller access and privilege model

- This repo uses Ansible push over SSH. Open `tcp/22` from the controller to every managed host in `librenms_nodes`, `librenms_db`, `librenms_redis`, `lb_nodes`, and `gluster_nodes`.
- Managed nodes do not need any dedicated inbound port opened to the Ansible controller. Stateful return traffic for the existing SSH session is enough.
- The SSH automation user needs a real shell plus root-equivalent privilege via `sudo`, because the playbooks install packages, write under `/etc`, manage services, mount GlusterFS, create system users, and manage ACLs.
- Passwordless `sudo` is recommended for unattended runs. If you intentionally keep a sudo password, use `--ask-become-pass` / `-K` or store `ansible_become_password` securely with Ansible Vault.
- SSH login passwords and sudo passwords are separate in Ansible. If SSH key authentication is not configured, also pass `--ask-pass` / `-k`; `--ask-become-pass` only answers the later sudo prompt after SSH has already connected.
- A typical sudoers entry for an automation account is:

```text
ansible ALL=(ALL) NOPASSWD: ALL
```

### Password-based SSH quick checks

Check SSH login only:

```bash
ansible -i inventories/ha/hosts.yml all -m ping -k
```

Check sudo/become after SSH login succeeds:

```bash
ansible -i inventories/ha/hosts.yml all -m command -a whoami -b -k -K
```

Run a playbook with both an SSH password and a sudo password:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml -k -K
```

If the SSH and sudo password are the same, enter the same value at both prompts. Password-based SSH requires `sshpass` on the controller, for example `sudo apt install sshpass` on Ubuntu/Debian. SSH keys plus passwordless sudo are still the recommended unattended production setup.

### Required ports and protocols

If a host has multiple roles, it needs the union of the rows that apply to those roles.

| Source | Destination | Protocol / Port | Required When | Purpose |
|---|---|---|---|---|
| Ansible controller | All managed hosts | TCP 22 | Always | SSH transport, fact gathering, module execution |
| Managed hosts | Ansible controller | No dedicated listener; reply traffic only | Always | Ansible is push-based |
| Ansible controller | Ansible Galaxy, GitHub, internal mirrors | TCP 443 | During bootstrap and updates | Collection installs and repo sync on the controller |
| AWX controller | All managed hosts | TCP 22 | When `awx_controller_enabled: true` and AWX runs jobs | SSH transport from AWX job execution to managed hosts |
| AWX controller | GitHub, Ansible Galaxy, container registries, OS mirrors | TCP 443 | When installing or updating AWX and job execution environments | k3s, AWX Operator, image pulls, project syncs, and collections |
| Operators / browsers | AWX controller, ingress, or load balancer | TCP 80 / 443 / selected NodePort | When `awx_controller_enabled: true` | AWX web UI and API |
| Managed hosts | OS mirrors, GitHub, Packagist, internal mirrors | TCP 80 / 443 | During bootstrap and updates | Package installs, LibreNMS git checkout, Composer dependencies |
| Managed hosts | DNS / NTP infrastructure | UDP/TCP 53, UDP 123 | Strongly recommended | Name resolution and clock sync for repos, clustering, and TLS |
| Users / browsers | VIP or web nodes | TCP 80 | Default deployment | LibreNMS Web UI through HAProxy or directly to nginx |
| Users / browsers | Reverse proxy / VIP | TCP 443 | Only if you add TLS outside the default config | HTTPS is recommended, but this repo does not configure TLS listeners by default |
| LB nodes | Web or full LibreNMS nodes | TCP 80 | When HAProxy fronts the Web UI | Proxy traffic and HTTP health checks |
| LibreNMS app nodes | DB VIP, LB nodes, or DB nodes | TCP 3306 | Any non-local DB mode | LibreNMS application database access |
| DB nodes | DB nodes | TCP 3306 | `librenms_db_mode: galera` | MariaDB client traffic and health checks inside the cluster |
| DB nodes | DB nodes | TCP 4444 | `librenms_db_mode: galera` with default `librenms_galera_sst_method: rsync` | Galera state snapshot transfer (SST) |
| DB nodes | DB nodes | TCP 4567 and UDP 4567 | `librenms_db_mode: galera` | Galera replication traffic |
| DB nodes | DB nodes | TCP 4568 | `librenms_db_mode: galera` | Galera incremental state transfer (IST) |
| LibreNMS app nodes | Redis Sentinel nodes | TCP 26379 | `librenms_redis_mode: sentinel` | LibreNMS discovers the active Redis master through Sentinel |
| Redis nodes | Redis nodes | TCP 6379 | `librenms_redis_mode: sentinel` | Redis replication and authenticated server traffic |
| Redis nodes | Redis nodes | TCP 26379 | `librenms_redis_mode: sentinel` | Sentinel quorum, monitoring, and failover coordination |
| LB nodes | LB nodes | IP protocol 112 (VRRP) | `librenms_vip_enabled: true` | Keepalived VIP advertisements; this is not TCP or UDP |
| Gluster clients and Gluster nodes | Gluster nodes | TCP 24007, 24008, 49152-49251 | `librenms_rrd_mode: glusterfs` | glusterd management, volume operations, and brick traffic |
| LibreNMS poller / app nodes | Monitored devices, and optionally the LibreNMS nodes themselves | UDP 161 | When polling via SNMP | SNMP polling traffic |
| Monitored devices | LibreNMS nodes | UDP 162 | Only if you separately deploy trap reception | SNMP trap reception is not configured by this repo by default |
| Operators | LB nodes | TCP 8404 | Only if `librenms_haproxy_stats_enabled: true` and you widen the bind beyond `127.0.0.1` | Optional HAProxy stats page |

### Firewall notes

- `librenms_db_bind_address` defaults to `0.0.0.0`, so restrict `3306/tcp` with host or network firewalls if you do not want broad exposure.
- Keep Galera, Redis, GlusterFS, and VRRP limited to the cluster management subnet. None of those services should be exposed to general client networks.
- Keepalived VRRP usually requires the `lb_nodes` to be on the same L2 segment or VLAN, with firewalls allowing protocol `112` and multicast to `224.0.0.18`.
- This repo listens on `80/tcp` for the Web UI by default. If you need native `443/tcp`, add TLS termination in front of the VIP or extend the nginx / HAProxy templates.
- When `librenms_manage_local_snmpd: true`, the nodes listen on `udp/161`. If you do not monitor the LibreNMS nodes themselves, you can keep that port restricted to your poller subnet.
- GlusterFS uses management ports plus dynamic brick ports. The documented `49152-49251/tcp` range is the practical default to allow between Gluster peers and Gluster clients.

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

### LibreNMS source version

```yaml
librenms_version: latest-stable     # latest stable tag; use master only for dev testing
```

`latest-stable` resolves the newest numeric release tag, such as `26.4.0`, from the
LibreNMS GitHub tags page during deployment. For repeatable production rebuilds,
pin this to an explicit released tag instead of tracking `master`.

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
librenms_vip_interface: ""        # empty = use the default IPv4 route interface
```

Set `librenms_vip_interface` only when you need to pin the VIP to a specific NIC. It must match an interface name from `ip -brief addr` on every `lb_nodes` host.

### Web health probes

```yaml
librenms_app_probe_path: /
librenms_app_probe_retries: 3
librenms_app_probe_delay: 3
```

Increase the retries or delay only if your LibreNMS web nodes routinely need more warm-up time after PHP-FPM or nginx restarts.

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
ansible-playbook -i inventories/ha/hosts.yml playbooks/add-node.yml
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
ansible-playbook -i inventories/ha/hosts.yml playbooks/remove-node.yml
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
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml
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

Lint with Docker instead:

```bash
docker compose build ansible
docker compose run --rm ansible make lint
```

---

## Contributing

Pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

## Security

Please read [SECURITY.md](SECURITY.md) for reporting guidance.

## License

MIT. See [LICENSE](LICENSE).
