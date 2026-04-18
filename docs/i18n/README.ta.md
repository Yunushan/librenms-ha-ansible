# LibreNMS HA Ansible Deployment

பல Linux குடும்பங்களில் LibreNMS இன் **standalone, distributed polling, மற்றும் full HA** deployment களுக்கான production-oriented Ansible automation.

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> குறிப்பு
> English README தான் canonical version. இந்த file எளிய onboarding க்காக இருக்கும் full translated copy. வேறுபாடு இருந்தால் [README.md](../../README.md) ஐப் பின்பற்றுங்கள்.

## Network and Access Matrix

For the exact controller-to-node ports, cluster east-west traffic, and sudo requirements, see the canonical English section [Network and Access Matrix](../../README.md#network-and-access-matrix).

## இந்த project ஏன் உள்ளது / Why This Exists

ஒரு server மீது LibreNMS ஓடச் செய்வது எளிது. ஆனால் கீழே உள்ள ஒன்றையாவது அல்லது பலவற்றையாவது தேவைப்பட்டதும் operations சிக்கலாகிவிடும்:

- பல LibreNMS web அல்லது poller nodes
- Redis Sentinel
- Galera
- shared RRD storage
- Web UI மற்றும் database load balancer முன்னால் VIP
- host failure பிறகு repeatable rebuild
- standalone மற்றும் HA இரண்டையும் கையாளும் ஒரே repo

இந்த repo ஒரு Ansible project மூலம் deploy செய்யக்கூடியவை:

1. **all-in-one standalone LibreNMS**
2. **distributed pollers மற்றும் shared services உடன் LibreNMS**
3. **full HA LibreNMS** with MariaDB Galera, Redis Sentinel, HAProxy + Keepalived, மற்றும் GlusterFS-backed RRD storage

---

## உங்களுக்கு கிடைப்பவை / What You Get

- giant shell script க்கு பதிலாக modular Ansible roles
- inventory-driven topology selection
- அதே project இலிருந்து standalone அல்லது cluster deployment
- optional Galera மற்றும் optional Redis Sentinel
- optional VIP மற்றும் load balancer layer
- optional local SNMP agent management
- SNMP **v1**, **v2c**, மற்றும் **v3** support
- LibreNMS nodes add/remove workflow
- GitHub-ready repo structure with MIT license, lint workflow, CONTRIBUTING, SECURITY, example inventories, மற்றும் secret generator

---

## Topology Modes / டோபாலஜி முறைகள்

### 1) Standalone
ஒரே host எல்லாவற்றையும் இயக்கும்.

labs, சிறிய environments, மற்றும் backup உடன் single-node production க்கு பொருத்தமானது.

### 2) DB Cluster இல்லாத Cluster
பல LibreNMS nodes பயன்படுத்தி, அவற்றை existing external DB / Redis / storage stack க்கு point செய்யுங்கள்.

managed MariaDB/Redis environments க்கும், எல்லா HA components ஐ self-host செய்யாமல் poller scale விரும்பும் users க்கும் இது ஏற்றது.

### 3) Full HA
பயன்படுத்த வேண்டிய settings:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

இது serious internal monitoring platforms மற்றும் Galera / Redis / Gluster recovery புரிந்த operators க்கு ஏற்றது.

> முக்கியம்
> இந்த project platform மற்றும் LibreNMS file/service layout ஐ automate செய்கிறது. Initial app bootstrap நினைத்தே conservative ஆக வைத்திருக்கப்படுகிறது. முதலில் web installer மூலம் முதல் bootstrap ஐ முடித்து, பிறகு `librenms_bootstrap_completed: true` set செய்து playbook ஐ மீண்டும் இயக்குங்கள்.

---

## Support Matrix / ஆதரவு அட்டவணை

இந்த repo வேண்டிய distributions ஐ support செய்ய உருவாக்கப்பட்டுள்ளது, ஆனால் இரண்டு நிலைகளில்:

| Distro | Level | Notes |
|---|---|---|
| Ubuntu | Primary | LibreNMS official docs உடன் மிகவும் பொருந்தும் |
| Debian | Primary | LibreNMS official docs உடன் மிகவும் பொருந்தும் |
| Linux Mint | Primary-க்கு அருகில் | Debian-family logic |
| AlmaLinux | Strong best-effort | RedHat-family logic |
| Rocky Linux | Strong best-effort | RedHat-family logic |
| Fedora | Strong best-effort | RedHat-family logic |
| CentOS / CentOS Stream | Best-effort | PHP availability அடிப்படையில் repo tuning தேவைப்படலாம் |
| Arch Linux | Best-effort | family mapping உள்ளது; lab இல் package names verify செய்யுங்கள் |
| Manjaro Linux | Best-effort | Arch-family logic |
| Alpine Linux | Best-effort | OpenRC மற்றும் package differences க்கு override தேவைப்படலாம் |
| Gentoo | Best-effort | package மற்றும் service differences க்கு override தேவைப்படலாம் |

### Reality Check

LibreNMS upstream docs தற்போது **Ubuntu 24.04**, **Ubuntu 22.04**, **Debian 12**, **Debian 13**, மற்றும் **CentOS 8** க்கான install examples தருகிறது. இந்த repo family mappings மூலம் அதைவிட விரிவாகச் செல்கிறது, ஆனால் non-primary distros ஐ production க்கு முன் lab இல் test செய்ய வேண்டும்.

பார்க்க:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Repository Layout / ரிபொசிட்டரி அமைப்பு

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

## Quick Start / விரைவான தொடக்கம்

1. Repo clone செய்து collections install செய்யுங்கள்:

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

2. Secrets generate செய்யுங்கள்:

```bash
python3 scripts/generate-secrets.py > inventories/ha/group_vars/vault.yml
```

அல்லது standalone க்காக:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

3. Inventory தேர்வு செய்யுங்கள்:
- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha/hosts.yml`

4. Host IPs, SSH user, `librenms_fqdn`, `librenms_app_key`, DB / Redis / VRRP secrets, VIP details, மற்றும் Gluster brick settings நிரப்புங்கள்.

5. Deployment இயக்குங்கள்:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

அல்லது:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml
```

6. `/install` இல் முதல் LibreNMS bootstrap ஐ முடித்து, பின்னர் இதை set செய்யுங்கள்:

```yaml
librenms_bootstrap_completed: true
```

பிறகு அதே playbook ஐ மீண்டும் இயக்குங்கள்.

---

## Inventory Model / இன்வென்டரி மாதிரி

இந்த repo hard-coded assumptions க்கு பதிலாக inventory groups ஐப் பயன்படுத்துகிறது.

- `librenms_nodes`: application nodes
- `librenms_primary`: primary post-bootstrap tasks க்கான ஒரு node
- `librenms_web`: Web UI serve செய்யும் nodes
- `librenms_db`: DB அல்லது Galera nodes
- `librenms_redis`: Redis / Sentinel nodes
- `lb_nodes`: HAProxy / Keepalived nodes
- `gluster_nodes`: shared RRD storage nodes
- `new_nodes`: add செய்யப்படும் nodes
- `decommission_nodes`: remove செய்யப்படும் nodes

---

## மிக முக்கியமான variables / Variables That Matter Most

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

## Node சேர்த்தல் / Add a Node

Host ஐ `librenms_nodes`, `librenms_web` அல்லது `librenms_poller` profile இல் சேர்த்து, `new_nodes` இல் வைத்து, unique `librenms_node_id` ஐ set செய்து, பின்னர் இயக்குங்கள்:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/add-node.yml
```

இந்த playbook `site.yml` ஐ reuse செய்து புதிய host ஐ configure செய்கிறது, load balancer backends ஐ reconcile செய்கிறது, மேலும் தேவையானபோது Redis / Galera / app configs ஐ மீண்டும் render செய்கிறது.

---

## Node அகற்றல் / Remove a Node

Host ஐ active groups இலிருந்து அகற்றி `decommission_nodes` இல் வைத்து, பின்னர் இயக்குங்கள்:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/remove-node.yml
```

இது surviving cluster ஐ updated inventory உடன் sync செய்து removed node இல் services ஐ disable அல்லது cleanup செய்கிறது.

> முக்கியம்
> Gluster-backed RRD layer இலிருந்து storage node ஐ அகற்றுவது casual operation அல்ல. Repo இதை operator-reviewed workflow ஆகவே வைத்திருக்கிறது.

---

## SNMP Support / SNMP ஆதரவு

- `SNMPv1`: community-based; legacy hardware க்கு உதவும்.
- `SNMPv2c`: community-based மற்றும் பழைய devices அல்லது simple rollouts இல் இன்னும் common.
- `SNMPv3`: recommended; repo `snmpd` configure செய்ய முடியும், SNMPv3 users உருவாக்க முடியும், மற்றும் bootstrap பின் SNMP version order set செய்ய முடியும்.

---

## Security Notes / பாதுகாப்பு குறிப்புகள்

- Secrets ஐ `group_vars/vault.yml` இல் வைத்து **Ansible Vault** மூலம் encrypt செய்யுங்கள்
- generated vault files ஐ commit செய்ய வேண்டாம்
- public அல்லது semi-public exposure க்கு முன் LibreNMS முன் HTTPS பயன்படுத்துங்கள்
- Galera full-cluster recovery மற்றும் Gluster membership changes ஐ explicit operator tasks ஆகக் கொள்ளுங்கள்
- failover ஐ முறையாக test செய்யுங்கள்

பார்க்க:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Known Boundaries / அறியப்பட்ட வரம்புகள்

### எளிதாக automate செய்யக்கூடியவை
- package install
- repo checkout
- nginx / php-fpm config
- local MariaDB mode
- initial Galera join pattern
- Redis / Sentinel config
- HAProxy / Keepalived config
- LibreNMS app file deployment
- SNMP agent config
- application nodes add அல்லது remove செய்வது

### operator review தேவைப்படுபவை
- total outage பிறகு Galera disaster bootstrap
- பெரிய failure பிறகு Gluster peer / brick recovery
- storage cluster membership இலிருந்து destructive node removal
- best-effort distros இல் distro-specific package fixes
- RedHat-family systems இல் SELinux hardening fine-tuning

---

## Verification / சரிபார்ப்பு

Validation playbook ஐ இயக்குங்கள்:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml
```

அல்லது standalone க்காக:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

இது LibreNMS validator, Galera status, Redis Sentinel state, மற்றும் Gluster volume status மீது practical checks இயக்கும்.

---

## Development / மேம்பாடு

Local lint இயக்குங்கள்:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Contributing / பங்களிப்பு

Pull requests வரவேற்கப்படுகின்றன. முதலில் [CONTRIBUTING.md](../../CONTRIBUTING.md) ஐப் படியுங்கள்.

## Security / பாதுகாப்பு

Reporting guidance க்காக [SECURITY.md](../../SECURITY.md) ஐப் படியுங்கள்.

## License / உரிமம்

MIT. [LICENSE](../../LICENSE) ஐப் பார்க்கவும்.
