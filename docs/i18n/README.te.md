# LibreNMS HA Ansible Deployment

అనేక Linux కుటుంబాలపై LibreNMS యొక్క **standalone, distributed polling, మరియు full HA** deployment కోసం production-oriented Ansible automation.

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> గమనిక
> English README canonical version. ఈ ఫైల్ సులభమైన onboarding కోసం పూర్తి translated copy. ఏమైనా తేడా ఉంటే [README.md](../../README.md) ను అనుసరించండి.

## ఈ ప్రాజెక్ట్ ఎందుకు ఉంది / Why This Exists

ఒక server పై LibreNMS నడపడం సులభం, కానీ క్రింది వాటిలో ఒకటి లేదా ఎక్కువ అవసరమైతే operations త్వరగా క్లిష్టం అవుతాయి:

- అనేక LibreNMS web లేదా poller nodes
- Redis Sentinel
- Galera
- shared RRD storage
- Web UI మరియు database load balancer ముందు VIP
- host failure తర్వాత repeatable rebuild
- standalone మరియు HA రెండింటినీ హ్యాండిల్ చేసే ఒక repo

ఈ repo ఒకే Ansible project ద్వారా deploy చేయగలదు:

1. **all-in-one standalone LibreNMS**
2. **distributed pollers మరియు shared services తో LibreNMS**
3. **full HA LibreNMS** with MariaDB Galera, Redis Sentinel, HAProxy + Keepalived, మరియు GlusterFS-backed RRD storage

---

## మీకు ఏమి లభిస్తుంది / What You Get

- giant shell script బదులుగా modular Ansible roles
- inventory-driven topology selection
- అదే project నుండి standalone లేదా cluster deployment
- optional Galera మరియు optional Redis Sentinel
- optional VIP మరియు load balancer layer
- optional local SNMP agent management
- SNMP **v1**, **v2c**, మరియు **v3** support
- LibreNMS nodes add/remove workflow
- GitHub-ready repo structure with MIT license, lint workflow, CONTRIBUTING, SECURITY, example inventories, మరియు secret generator

---

## Topology Modes / టోపాలజీ మోడ్‌లు

### 1) Standalone
ఒక host అన్నింటినీ నిర్వహిస్తుంది.

labs, చిన్న environments, మరియు backup ఉన్న single-node production కు సరైనది.

### 2) DB Cluster లేకుండా Cluster
అనేక LibreNMS nodes ఉపయోగించండి, కానీ వాటిని existing external DB / Redis / storage stack కు point చేయండి.

managed MariaDB/Redis environments మరియు అన్ని HA components ను self-host చేయకుండా poller scale కోరుకునే users కు ఇది సరిపోతుంది.

### 3) Full HA
వాడాల్సినవి:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

ఇది serious internal monitoring platforms మరియు Galera / Redis / Gluster recovery అర్థం చేసుకునే operators కోసం.

> ముఖ్యము
> ఈ project platform మరియు LibreNMS file/service layout ను automate చేస్తుంది. Initial app bootstrap ను ఉద్దేశపూర్వకంగా conservative గా ఉంచారు. ముందుగా web installer ద్వారా మొదటి bootstrap పూర్తి చేయండి, తర్వాత `librenms_bootstrap_completed: true` సెట్ చేసి playbook ను మళ్లీ నడపండి.

---

## Support Matrix / సపోర్ట్ మ్యాట్రిక్స్

ఈ repo అవసరమైన distributions ను support చేయడానికి రూపొందించబడింది, కానీ రెండు స్థాయిలలో చేస్తుంది:

| Distro | Level | Notes |
|---|---|---|
| Ubuntu | Primary | LibreNMS official docs కు అత్యంత సరిపోలుతుంది |
| Debian | Primary | LibreNMS official docs కు అత్యంత సరిపోలుతుంది |
| Linux Mint | దాదాపు Primary | Debian-family logic |
| AlmaLinux | Strong best-effort | RedHat-family logic |
| Rocky Linux | Strong best-effort | RedHat-family logic |
| Fedora | Strong best-effort | RedHat-family logic |
| CentOS / CentOS Stream | Best-effort | PHP availability ఆధారంగా repo tuning కావచ్చు |
| Arch Linux | Best-effort | family mapping ఉంది; lab లో package names verify చేయండి |
| Manjaro Linux | Best-effort | Arch-family logic |
| Alpine Linux | Best-effort | OpenRC మరియు package differences కి override కావచ్చు |
| Gentoo | Best-effort | package మరియు service differences కి override కావచ్చు |

### Reality Check

LibreNMS upstream docs ప్రస్తుతం **Ubuntu 24.04**, **Ubuntu 22.04**, **Debian 12**, **Debian 13**, మరియు **CentOS 8** కు install examples ఇస్తాయి. ఈ repo family mappings ద్వారా దానికంటే ఎక్కువగా వెళ్తుంది, కానీ non-primary distros ను production కు ముందు lab లో test చేయాలి.

చూడండి:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Repository Layout / రిపోజిటరీ నిర్మాణం

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

## Quick Start / త్వరిత ప్రారంభం

1. Repo clone చేసి collections install చేయండి:

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

2. Secrets generate చేయండి:

```bash
python3 scripts/generate-secrets.py > inventories/ha-3node/group_vars/vault.yml
```

లేదా standalone కోసం:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

3. Inventory ఎంచుకోండి:
- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha-3node/hosts.yml`

4. Host IPs, SSH user, `librenms_fqdn`, `librenms_app_key`, DB / Redis / VRRP secrets, VIP details, మరియు Gluster brick settings నింపండి.

5. Deployment నడపండి:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

లేదా:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/cluster.yml
```

6. `/install` లో మొదటి LibreNMS bootstrap పూర్తి చేసి, తర్వాత ఇది set చేయండి:

```yaml
librenms_bootstrap_completed: true
```

ఆపై అదే playbook ను మళ్లీ నడపండి.

---

## Inventory Model / ఇన్వెంటరీ మోడల్

ఈ repo hard-coded assumptions బదులుగా inventory groups ను ఉపయోగిస్తుంది.

- `librenms_nodes`: application nodes
- `librenms_primary`: primary post-bootstrap tasks కోసం ఒక node
- `librenms_web`: Web UI serve చేసే nodes
- `librenms_db`: DB లేదా Galera nodes
- `librenms_redis`: Redis / Sentinel nodes
- `lb_nodes`: HAProxy / Keepalived nodes
- `gluster_nodes`: shared RRD storage nodes
- `new_nodes`: add అవుతున్న nodes
- `decommission_nodes`: remove అవుతున్న nodes

---

## అత్యంత ముఖ్యమైన variables / Variables That Matter Most

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

## Node జోడించడం / Add a Node

Host ను `librenms_nodes`, `librenms_web` లేదా `librenms_poller` profile లో జోడించి, `new_nodes` లో ఉంచి, unique `librenms_node_id` సెట్ చేసి, తర్వాత నడపండి:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/add-node.yml
```

ఈ playbook `site.yml` ను reuse చేసి కొత్త host ను configure చేస్తుంది, load balancer backends ను reconcile చేస్తుంది, మరియు అవసరమైతే Redis / Galera / app configs ను మళ్లీ render చేస్తుంది.

---

## Node తొలగించడం / Remove a Node

Host ను active groups నుండి తీసి `decommission_nodes` లో పెట్టి, తర్వాత నడపండి:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/remove-node.yml
```

ఇది surviving cluster ను updated inventory తో sync చేస్తుంది మరియు removed node పై services ను disable లేదా cleanup చేస్తుంది.

> ముఖ్యము
> Gluster-backed RRD layer నుండి storage node ను తొలగించడం casual operation కాదు. Repo దీన్ని operator-reviewed workflow గా ఉంచుతుంది.

---

## SNMP Support / SNMP సపోర్ట్

- `SNMPv1`: community-based; legacy hardware కోసం ఉపయోగకరం.
- `SNMPv2c`: community-based మరియు పాత devices లేదా simple rollouts లో ఇప్పటికీ common.
- `SNMPv3`: recommended; repo `snmpd` configure చేయగలదు, SNMPv3 users సృష్టించగలదు, మరియు bootstrap తర్వాత SNMP version order set చేయగలదు.

---

## Security Notes / భద్రతా గమనికలు

- Secrets ను `group_vars/vault.yml` లో ఉంచి **Ansible Vault** తో encrypt చేయండి
- generated vault files ను commit చేయవద్దు
- public లేదా semi-public exposure కు ముందు LibreNMS ముందు HTTPS ఉంచండి
- Galera full-cluster recovery మరియు Gluster membership changes ను explicit operator tasks గా భావించండి
- failover ను క్రమం తప్పకుండా test చేయండి

చూడండి:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Known Boundaries / తెలిసిన పరిమితులు

### సులభంగా automate చేయగలవి
- package install
- repo checkout
- nginx / php-fpm config
- local MariaDB mode
- initial Galera join pattern
- Redis / Sentinel config
- HAProxy / Keepalived config
- LibreNMS app file deployment
- SNMP agent config
- application nodes add లేదా remove చేయడం

### operator review అవసరమయ్యేవి
- total outage తర్వాత Galera disaster bootstrap
- పెద్ద failure తర్వాత Gluster peer / brick recovery
- storage cluster membership నుండి destructive node removal
- best-effort distros పై distro-specific package fixes
- RedHat-family systems పై SELinux hardening fine-tuning

---

## Verification / ధృవీకరణ

Validation playbook ను నడపండి:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/validate.yml
```

లేదా standalone కోసం:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

ఇది LibreNMS validator, Galera status, Redis Sentinel state, మరియు Gluster volume status పై practical checks ను నడుపుతుంది.

---

## Development / డెవలప్మెంట్

Local lint ను నడపండి:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Contributing / సహకారం

Pull requests స్వాగతం. ముందుగా [CONTRIBUTING.md](../../CONTRIBUTING.md) చదవండి.

## Security / భద్రత

Reporting guidance కోసం [SECURITY.md](../../SECURITY.md) చదవండి.

## License / లైసెన్స్

MIT. [LICENSE](../../LICENSE) చూడండి.
