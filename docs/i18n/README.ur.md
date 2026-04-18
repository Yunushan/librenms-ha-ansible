# LibreNMS HA Ansible Deployment

یہ کئی Linux خاندانوں پر LibreNMS کے **standalone، distributed polling، اور full HA** deployment کے لیے production-oriented Ansible automation ہے۔

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> نوٹ
> English README canonical version ہے۔ یہ فائل آسان onboarding کے لیے مکمل translated copy ہے۔ اگر کہیں فرق ہو تو [README.md](../../README.md) کو follow کریں۔

## یہ پروجیکٹ کیوں ہے / Why This Exists

LibreNMS کو ایک server پر چلانا آسان ہے، لیکن جیسے ہی آپ کو درج ذیل چیزوں میں سے ایک یا زیادہ درکار ہوں، operations تیزی سے پیچیدہ ہو جاتے ہیں:

- کئی LibreNMS web یا poller nodes
- Redis Sentinel
- Galera
- shared RRD storage
- Web UI اور database load balancer کے سامنے VIP
- host failure کے بعد repeatable rebuild
- standalone اور HA دونوں کو سنبھالنے والا ایک repo

یہ repo ایک ہی Ansible project دیتا ہے جو deploy کر سکتا ہے:

1. **all-in-one standalone LibreNMS**
2. **distributed pollers اور shared services والا LibreNMS**
3. **full HA LibreNMS** with MariaDB Galera, Redis Sentinel, HAProxy + Keepalived, اور GlusterFS-backed RRD storage

---

## آپ کو کیا ملتا ہے / What You Get

- ایک بڑے shell script کے بجائے modular Ansible roles
- inventory-driven topology selection
- اسی project سے standalone یا cluster deployment
- optional Galera اور optional Redis Sentinel
- optional VIP اور load balancer layer
- optional local SNMP agent management
- SNMP **v1**، **v2c**، اور **v3** support
- LibreNMS nodes کو add اور remove کرنے کے workflow
- GitHub-ready repo structure with MIT license, lint workflow, CONTRIBUTING, SECURITY, example inventories, اور secret generator

---

## Topology Modes / ٹوپولوجی موڈز

### 1) Standalone
ایک host سب کچھ چلاتا ہے۔

labs، چھوٹے environments، اور backups والے single-node production کے لیے مناسب۔

### 2) DB Cluster کے بغیر Cluster
کئی LibreNMS nodes استعمال کریں، مگر انہیں existing external DB / Redis / storage stack سے جوڑیں۔

یہ managed MariaDB/Redis والے environments اور ان users کے لیے بہتر ہے جو poller scale چاہتے ہیں مگر سارے HA components خود host نہیں کرنا چاہتے۔

### 3) Full HA
استعمال کریں:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

یہ serious internal monitoring platforms اور Galera / Redis / Gluster recovery سمجھنے والے operators کے لیے ہے۔

> اہم
> یہ project platform اور LibreNMS file/service layout کو automate کرتا ہے۔ Initial app bootstrap جان بوجھ کر conservative رکھا گیا ہے۔ پہلے web installer سے پہلا bootstrap مکمل کریں، پھر `librenms_bootstrap_completed: true` کے ساتھ playbook دوبارہ چلائیں۔

---

## Support Matrix / سپورٹ میٹرکس

یہ repo مطلوبہ distributions کو support کرنے کے لیے بنایا گیا ہے، مگر دو سطحوں میں:

| Distro | Level | Notes |
|---|---|---|
| Ubuntu | Primary | LibreNMS official docs کے سب سے قریب |
| Debian | Primary | LibreNMS official docs کے سب سے قریب |
| Linux Mint | تقریباً Primary | Debian-family logic |
| AlmaLinux | Strong best-effort | RedHat-family logic |
| Rocky Linux | Strong best-effort | RedHat-family logic |
| Fedora | Strong best-effort | RedHat-family logic |
| CentOS / CentOS Stream | Best-effort | PHP availability کے مطابق repo tuning لگ سکتی ہے |
| Arch Linux | Best-effort | family mapping شامل ہے؛ package names lab میں verify کریں |
| Manjaro Linux | Best-effort | Arch-family logic |
| Alpine Linux | Best-effort | OpenRC اور package differences کے لیے override لگ سکتے ہیں |
| Gentoo | Best-effort | package اور service differences کے لیے override لگ سکتے ہیں |

### Reality Check

LibreNMS upstream docs ابھی **Ubuntu 24.04**، **Ubuntu 22.04**، **Debian 12**، **Debian 13**، اور **CentOS 8** کے install examples دیتی ہیں۔ یہ repo family mappings کے ذریعے اس سے آگے جاتا ہے، لیکن non-primary distros کو production سے پہلے lab میں test کرنا چاہیے۔

دیکھیں:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Repository Layout / ریپوزٹری ساخت

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

## Quick Start / فوری آغاز

1. Repo clone کریں اور collections install کریں:

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

2. Secrets generate کریں:

```bash
python3 scripts/generate-secrets.py > inventories/ha-3node/group_vars/vault.yml
```

یا standalone کے لیے:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

3. Inventory منتخب کریں:
- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha-3node/hosts.yml`

4. Host IPs، SSH user، `librenms_fqdn`، `librenms_app_key`، DB / Redis / VRRP secrets، VIP details، اور Gluster brick settings بھریں۔

5. Deployment چلائیں:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

یا:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/cluster.yml
```

6. `/install` پر پہلا LibreNMS bootstrap مکمل کریں، پھر یہ set کریں:

```yaml
librenms_bootstrap_completed: true
```

اور وہی playbook دوبارہ چلائیں۔

---

## Inventory Model / انوینٹری ماڈل

یہ repo hard-coded assumptions کے بجائے inventory groups استعمال کرتا ہے۔

- `librenms_nodes`: application nodes
- `librenms_primary`: primary post-bootstrap tasks کے لیے ایک node
- `librenms_web`: Web UI serve کرنے والے nodes
- `librenms_db`: DB یا Galera nodes
- `librenms_redis`: Redis / Sentinel nodes
- `lb_nodes`: HAProxy / Keepalived nodes
- `gluster_nodes`: shared RRD storage nodes
- `new_nodes`: وہ nodes جو add کیے جا رہے ہیں
- `decommission_nodes`: وہ nodes جو remove کیے جا رہے ہیں

---

## سب سے اہم variables / Variables That Matter Most

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

## Node شامل کرنا / Add a Node

Host کو `librenms_nodes`، `librenms_web` یا `librenms_poller` profile میں شامل کریں، اسے `new_nodes` میں رکھیں، unique `librenms_node_id` set کریں، پھر چلائیں:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/add-node.yml
```

یہ playbook `site.yml` کو reuse کرتا ہے، نئے host کو configure کرتا ہے، load balancer backends reconcile کرتا ہے، اور ضرورت پر Redis / Galera / app configs دوبارہ render کرتا ہے۔

---

## Node ہٹانا / Remove a Node

Host کو active groups سے نکالیں، `decommission_nodes` میں رکھیں، پھر چلائیں:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/remove-node.yml
```

یہ surviving cluster کو updated inventory کے ساتھ sync کرتا ہے اور removed node پر services disable یا cleanup کرتا ہے۔

> اہم
> Gluster-backed RRD layer سے storage node ہٹانا casual operation نہیں سمجھا جاتا۔ Repo جان بوجھ کر اسے operator-reviewed workflow کے طور پر رکھتا ہے۔

---

## SNMP Support / SNMP سپورٹ

- `SNMPv1`: community-based؛ legacy hardware کے لیے مفید۔
- `SNMPv2c`: community-based اور پرانے devices یا simple rollouts میں اب بھی common۔
- `SNMPv3`: recommended؛ repo `snmpd` configure کر سکتا ہے، SNMPv3 users بنا سکتا ہے، اور bootstrap کے بعد SNMP version order set کر سکتا ہے۔

---

## Security Notes / سیکیورٹی نوٹس

- Secrets کو `group_vars/vault.yml` میں رکھیں اور **Ansible Vault** سے encrypt کریں
- generated vault files commit نہ کریں
- public یا semi-public exposure سے پہلے LibreNMS کے سامنے HTTPS لگائیں
- Galera full-cluster recovery اور Gluster membership changes کو explicit operator tasks سمجھیں
- failover باقاعدگی سے test کریں

دیکھیں:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Known Boundaries / معلوم حدود

### جو چیزیں آسانی سے automate ہو سکتی ہیں
- package install
- repo checkout
- nginx / php-fpm config
- local MariaDB mode
- initial Galera join pattern
- Redis / Sentinel config
- HAProxy / Keepalived config
- LibreNMS app file deployment
- SNMP agent config
- application nodes add یا remove کرنا

### جن پر operator review چاہیے
- total outage کے بعد Galera disaster bootstrap
- بڑی failure کے بعد Gluster peer / brick recovery
- storage cluster membership سے destructive node removal
- best-effort distros پر distro-specific package fixes
- RedHat-family systems پر SELinux hardening fine-tuning

---

## Verification / تصدیق

Validation playbook چلائیں:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/validate.yml
```

یا standalone کے لیے:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

یہ LibreNMS validator، Galera status، Redis Sentinel state، اور Gluster volume status کے لیے practical checks چلاتا ہے۔

---

## Development / ڈویلپمنٹ

Local lint چلائیں:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Contributing / حصہ ڈالنا

Pull requests welcome ہیں۔ پہلے [CONTRIBUTING.md](../../CONTRIBUTING.md) پڑھیں۔

## Security / سیکیورٹی

Reporting guidance کے لیے [SECURITY.md](../../SECURITY.md) پڑھیں۔

## License / لائسنس

MIT. [LICENSE](../../LICENSE) دیکھیں۔
