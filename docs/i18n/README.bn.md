# LibreNMS HA Ansible Deployment

একাধিক Linux পরিবারে LibreNMS-এর **standalone, distributed polling, এবং full HA** deployment-এর জন্য production-oriented Ansible automation।

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> নোট
> English README-ই canonical version। এই ফাইলটি সহজ onboarding-এর জন্য full translated copy। কোথাও পার্থক্য থাকলে [README.md](../../README.md) অনুসরণ করুন।

## Network and Access Matrix

For the exact controller-to-node ports, cluster east-west traffic, and sudo requirements, see the canonical English section [Network and Access Matrix](../../README.md#network-and-access-matrix).

## এই প্রজেক্ট কেন / Why This Exists

একটি server-এ LibreNMS চালানো সহজ, কিন্তু নিচের এক বা একাধিক জিনিস লাগলেই operation দ্রুত জটিল হয়ে যায়:

- একাধিক LibreNMS web বা poller node
- Redis Sentinel
- Galera
- shared RRD storage
- Web UI এবং database load balancer-এর সামনে VIP
- host failure-এর পরে repeatable rebuild
- standalone ও HA দুটোই সামলাতে পারে এমন এক repo

এই repo একটি Ansible project দেয় যা deploy করতে পারে:

1. **all-in-one standalone LibreNMS**
2. **distributed pollers এবং shared services সহ LibreNMS**
3. **full HA LibreNMS** with MariaDB Galera, Redis Sentinel, HAProxy + Keepalived, এবং GlusterFS-backed RRD storage

---

## কী পাবেন / What You Get

- giant shell script-এর বদলে modular Ansible roles
- inventory-driven topology selection
- একই project থেকে standalone বা cluster deployment
- optional Galera এবং optional Redis Sentinel
- optional VIP ও load balancer layer
- optional local SNMP agent management
- SNMP **v1**, **v2c**, এবং **v3** support
- LibreNMS node add/remove workflow
- GitHub-ready repo structure with MIT license, lint workflow, CONTRIBUTING, SECURITY, example inventories, and secret generator

---

## Topology Modes / টপোলজি মোড

### 1) Standalone
একটি host সবকিছু চালায়।

lab, ছোট environment, এবং backup-সহ single-node production-এর জন্য ভাল।

### 2) DB Cluster ছাড়া Cluster
একাধিক LibreNMS node ব্যবহার করুন, কিন্তু existing external DB / Redis / storage stack-এ point করুন।

managed MariaDB/Redis environment এবং যারা সব HA component নিজে host না করে poller scale চান তাদের জন্য উপযুক্ত।

### 3) Full HA
ব্যবহার করুন:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

এটি serious internal monitoring platform এবং Galera / Redis / Gluster recovery বোঝেন এমন operator-দের জন্য।

> গুরুত্বপূর্ণ
> এই project platform এবং LibreNMS file/service layout automate করে। প্রথম app bootstrap ইচ্ছে করে conservative রাখা হয়েছে। আগে web installer দিয়ে প্রথম bootstrap শেষ করুন, তারপর `librenms_bootstrap_completed: true` সেট করে playbook আবার চালান।

---

## Support Matrix / সাপোর্ট ম্যাট্রিক্স

এই repo চাওয়া distribution-গুলো support করার জন্য তৈরি, তবে দুই স্তরে:

| Distro | Level | Notes |
|---|---|---|
| Ubuntu | Primary | LibreNMS official docs-এর সাথে সবচেয়ে বেশি মেলে |
| Debian | Primary | LibreNMS official docs-এর সাথে সবচেয়ে বেশি মেলে |
| Linux Mint | প্রায় Primary | Debian-family logic |
| AlmaLinux | Strong best-effort | RedHat-family logic |
| Rocky Linux | Strong best-effort | RedHat-family logic |
| Fedora | Strong best-effort | RedHat-family logic |
| CentOS / CentOS Stream | Best-effort | PHP availability অনুযায়ী repo tuning লাগতে পারে |
| Arch Linux | Best-effort | family mapping আছে; lab-এ package name verify করুন |
| Manjaro Linux | Best-effort | Arch-family logic |
| Alpine Linux | Best-effort | OpenRC ও package differences-এর জন্য override লাগতে পারে |
| Gentoo | Best-effort | package এবং service differences-এর জন্য override লাগতে পারে |

### Reality Check

LibreNMS upstream docs এখন **Ubuntu 24.04**, **Ubuntu 22.04**, **Debian 12**, **Debian 13**, এবং **CentOS 8**-এর install example দেয়। এই repo family mapping দিয়ে তার চেয়ে বেশি যায়, কিন্তু non-primary distro production-এর আগে lab-এ test করা উচিত।

দেখুন:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Repository Layout / রিপোজিটরি গঠন

```text
.
├── .github/workflows/lint.yml
├── docs/
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

## Quick Start / দ্রুত শুরু

1. Repo clone করুন এবং collections install করুন:

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

2. Secret generate করুন:

```bash
python3 scripts/generate-secrets.py > inventories/ha/group_vars/vault.yml
```

অথবা standalone-এর জন্য:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

3. Inventory নির্বাচন করুন:
- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha/hosts.yml`

4. Host IP, SSH user, `librenms_fqdn`, `librenms_app_key`, DB / Redis / VRRP secrets, VIP details, এবং Gluster brick settings পূরণ করুন।

5. Deployment চালান:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

অথবা:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml
```

6. `/install`-এ প্রথম LibreNMS bootstrap শেষ করুন, তারপর সেট করুন:

```yaml
librenms_bootstrap_completed: true
```

এবং একই playbook আবার চালান।

---

## Inventory Model / ইনভেন্টরি মডেল

এই repo hard-coded assumptions-এর বদলে inventory groups ব্যবহার করে।

- `librenms_nodes`: application nodes
- `librenms_primary`: primary post-bootstrap tasks-এর জন্য একটি node
- `librenms_web`: Web UI serve করা nodes
- `librenms_db`: DB বা Galera nodes
- `librenms_redis`: Redis / Sentinel nodes
- `lb_nodes`: HAProxy / Keepalived nodes
- `gluster_nodes`: shared RRD storage nodes
- `new_nodes`: add করা হচ্ছে এমন nodes
- `decommission_nodes`: remove করা হচ্ছে এমন nodes

---

## সবচেয়ে গুরুত্বপূর্ণ variables / Variables That Matter Most

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

## Node যোগ করা / Add a Node

Host-কে `librenms_nodes`, `librenms_web` বা `librenms_poller` profile-এ যোগ করুন, `new_nodes`-এ রাখুন, unique `librenms_node_id` সেট করুন, তারপর চালান:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/add-node.yml
```

এই playbook `site.yml` reuse করে, নতুন host configure করে, load balancer backend reconcile করে, এবং দরকার হলে Redis / Galera / app configs আবার render করে।

---

## Node সরানো / Remove a Node

Host-কে active groups থেকে বের করুন, `decommission_nodes`-এ রাখুন, তারপর চালান:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/remove-node.yml
```

এটি surviving cluster-কে updated inventory-এর সাথে sync করে এবং removed node-এ services disable বা cleanup করে।

> গুরুত্বপূর্ণ
> Gluster-backed RRD layer থেকে storage node সরানো casual operation নয়। Repo ইচ্ছে করেই এটিকে operator-reviewed workflow হিসেবে রাখে।

---

## SNMP Support / SNMP সাপোর্ট

- `SNMPv1`: community-based; legacy hardware-এর জন্য কাজে লাগে।
- `SNMPv2c`: community-based এবং পুরনো device বা simple rollout-এ এখনো common।
- `SNMPv3`: recommended; repo `snmpd` configure করতে পারে, SNMPv3 user তৈরি করতে পারে, এবং bootstrap-এর পরে SNMP version order set করতে পারে।

---

## Security Notes / সিকিউরিটি নোট

- Secrets-কে `group_vars/vault.yml`-এ রাখুন এবং **Ansible Vault** দিয়ে encrypt করুন
- generated vault file commit করবেন না
- public বা semi-public exposure-এর আগে LibreNMS-এর সামনে HTTPS ব্যবহার করুন
- Galera full-cluster recovery এবং Gluster membership changes-কে explicit operator task হিসেবে ধরুন
- failover নিয়মিত test করুন

দেখুন:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Known Boundaries / জানা সীমা

### যেগুলো সহজে automate করা যায়
- package install
- repo checkout
- nginx / php-fpm config
- local MariaDB mode
- initial Galera join pattern
- Redis / Sentinel config
- HAProxy / Keepalived config
- LibreNMS app file deployment
- SNMP agent config
- application node add বা remove করা

### যেগুলো operator review চায়
- total outage-এর পরে Galera disaster bootstrap
- বড় failure-এর পরে Gluster peer / brick recovery
- storage cluster membership থেকে destructive node removal
- best-effort distro-তে distro-specific package fixes
- RedHat-family systems-এ SELinux hardening fine-tuning

---

## Verification / যাচাই

Validation playbook চালান:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml
```

অথবা standalone-এর জন্য:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

এটি LibreNMS validator, Galera status, Redis Sentinel state, এবং Gluster volume status-এর practical checks চালায়।

---

## Development / ডেভেলপমেন্ট

Local lint চালান:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Contributing / অবদান

Pull request স্বাগতম। আগে [CONTRIBUTING.md](../../CONTRIBUTING.md) পড়ুন।

## Security / সিকিউরিটি

Reporting guidance-এর জন্য [SECURITY.md](../../SECURITY.md) পড়ুন।

## License / লাইসেন্স

MIT. [LICENSE](../../LICENSE) দেখুন।
