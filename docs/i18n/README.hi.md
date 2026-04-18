# LibreNMS HA Ansible Deployment

यह कई Linux परिवारों पर LibreNMS के **standalone, distributed polling, और full HA** deployment के लिए production-oriented Ansible automation है।

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> नोट
> English README canonical version है। यह फ़ाइल आसान onboarding के लिए full translated copy है। अगर कहीं अंतर हो, तो [README.md](../../README.md) को follow करें।

## यह प्रोजेक्ट क्यों है / Why This Exists

LibreNMS को एक server पर चलाना आसान है, लेकिन जैसे ही आपको नीचे दी गई चीज़ों में से एक या अधिक चाहिए हों, operations जल्दी जटिल हो जाते हैं:

- कई LibreNMS web या poller nodes
- Redis Sentinel
- Galera
- shared RRD storage
- Web UI और database load balancer के सामने VIP
- host failure के बाद repeatable rebuild
- standalone और HA दोनों को संभालने वाला एक repo

यह repo एक ही Ansible project देता है जो deploy कर सकता है:

1. **all-in-one standalone LibreNMS**
2. **distributed pollers और shared services वाला LibreNMS**
3. **full HA LibreNMS** with MariaDB Galera, Redis Sentinel, HAProxy + Keepalived, और GlusterFS-backed RRD storage

---

## आपको क्या मिलता है / What You Get

- एक giant shell script की जगह modular Ansible roles
- inventory-driven topology selection
- उसी project से standalone या cluster deployment
- optional Galera और optional Redis Sentinel
- optional VIP और load balancer layer
- optional local SNMP agent management
- SNMP **v1**, **v2c**, और **v3** support
- LibreNMS nodes को add और remove करने के workflow
- GitHub-ready repo structure with MIT license, lint workflow, CONTRIBUTING, SECURITY, sample inventories, और secret generator

---

## Topology Modes / टोपोलॉजी मोड

### 1) Standalone
एक host सब कुछ चलाता है।

labs, छोटे environments, और backups वाले single-node production के लिए उपयुक्त।

### 2) DB Cluster के बिना Cluster
कई LibreNMS nodes इस्तेमाल करें, लेकिन उन्हें existing external DB / Redis / storage stack से जोड़ें।

यह managed MariaDB/Redis वाले environments और उन users के लिए सही है जो poller scale चाहते हैं लेकिन सारे HA components खुद host नहीं करना चाहते।

### 3) Full HA
इस्तेमाल करें:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

यह serious internal monitoring platforms और Galera / Redis / Gluster recovery समझने वाले operators के लिए है।

> महत्वपूर्ण
> यह project platform और LibreNMS file/service layout को automate करता है। Initial app bootstrap जानबूझकर conservative रखा गया है। पहले web installer से पहला bootstrap पूरा करें, फिर `librenms_bootstrap_completed: true` के साथ playbook दोबारा चलाएँ।

---

## Support Matrix / सपोर्ट मैट्रिक्स

यह repo requested distributions को support करने के लिए बनाया गया है, लेकिन दो स्तरों में:

| Distro | Level | Notes |
|---|---|---|
| Ubuntu | Primary | LibreNMS official docs के सबसे करीब |
| Debian | Primary | LibreNMS official docs के सबसे करीब |
| Linux Mint | लगभग Primary | Debian-family logic |
| AlmaLinux | Strong best-effort | RedHat-family logic |
| Rocky Linux | Strong best-effort | RedHat-family logic |
| Fedora | Strong best-effort | RedHat-family logic |
| CentOS / CentOS Stream | Best-effort | PHP availability के अनुसार repo tuning लग सकती है |
| Arch Linux | Best-effort | family mapping शामिल है; package names lab में verify करें |
| Manjaro Linux | Best-effort | Arch-family logic |
| Alpine Linux | Best-effort | OpenRC और package differences के लिए override लग सकते हैं |
| Gentoo | Best-effort | package और service differences के लिए override लग सकते हैं |

### Reality Check

LibreNMS upstream docs अभी **Ubuntu 24.04**, **Ubuntu 22.04**, **Debian 12**, **Debian 13**, और **CentOS 8** के install examples देती हैं। यह repo family mappings के जरिए उससे आगे जाता है, लेकिन non-primary distros को production से पहले lab में test करना चाहिए।

देखें:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Repository Layout / रिपॉज़िटरी संरचना

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

## Quick Start / क्विक स्टार्ट

1. Repo clone करें और collections install करें:

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

2. Secrets generate करें:

```bash
python3 scripts/generate-secrets.py > inventories/ha/group_vars/vault.yml
```

या standalone के लिए:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

3. Inventory चुनें:
- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha/hosts.yml`

4. Host IPs, SSH user, `librenms_fqdn`, `librenms_app_key`, DB / Redis / VRRP secrets, VIP details, और Gluster brick settings भरें।

5. Deployment चलाएँ:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

या:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml
```

6. `/install` पर पहला LibreNMS bootstrap पूरा करें, फिर यह set करें:

```yaml
librenms_bootstrap_completed: true
```

और वही playbook दोबारा चलाएँ।

---

## Inventory Model / इन्वेंटरी मॉडल

यह repo hard-coded assumptions की जगह inventory groups का उपयोग करता है।

- `librenms_nodes`: application nodes
- `librenms_primary`: primary post-bootstrap tasks के लिए एक node
- `librenms_web`: Web UI serve करने वाले nodes
- `librenms_db`: DB या Galera nodes
- `librenms_redis`: Redis / Sentinel nodes
- `lb_nodes`: HAProxy / Keepalived nodes
- `gluster_nodes`: shared RRD storage nodes
- `new_nodes`: जो nodes add किए जा रहे हैं
- `decommission_nodes`: जो nodes remove किए जा रहे हैं

---

## सबसे महत्वपूर्ण variables / Variables That Matter Most

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

## Node जोड़ना / Add a Node

Host को `librenms_nodes`, `librenms_web` या `librenms_poller` profile में जोड़ें, उसे `new_nodes` में रखें, unique `librenms_node_id` सेट करें, फिर चलाएँ:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/add-node.yml
```

यह playbook `site.yml` को reuse करता है, नए host को configure करता है, load balancer backends reconcile करता है, और जरूरत होने पर Redis / Galera / app configs फिर से render करता है।

---

## Node हटाना / Remove a Node

Host को active groups से निकालें, `decommission_nodes` में रखें, फिर चलाएँ:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/remove-node.yml
```

यह surviving cluster को updated inventory के साथ sync करता है और removed node पर services disable या cleanup करता है।

> महत्वपूर्ण
> Gluster-backed RRD layer से storage node हटाना casual operation नहीं माना जाता। Repo जानबूझकर इसे operator-reviewed workflow के रूप में रखता है।

---

## SNMP Support / SNMP समर्थन

- `SNMPv1`: community-based; legacy hardware के लिए उपयोगी।
- `SNMPv2c`: community-based और पुराने devices या simple rollouts में अब भी common।
- `SNMPv3`: recommended; repo `snmpd` configure कर सकता है, SNMPv3 users बना सकता है, और bootstrap के बाद SNMP version order set कर सकता है।

---

## Security Notes / सुरक्षा नोट्स

- Secrets को `group_vars/vault.yml` में रखें और **Ansible Vault** से encrypt करें
- generated vault files commit न करें
- public या semi-public exposure से पहले LibreNMS के सामने HTTPS लगाएँ
- Galera full-cluster recovery और Gluster membership changes को explicit operator tasks मानें
- failover को नियमित रूप से test करें

देखें:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Known Boundaries / ज्ञात सीमाएँ

### जिन चीज़ों को आराम से automate किया जा सकता है
- package install
- repo checkout
- nginx / php-fpm config
- local MariaDB mode
- initial Galera join pattern
- Redis / Sentinel config
- HAProxy / Keepalived config
- LibreNMS app file deployment
- SNMP agent config
- application nodes add या remove करना

### जिन पर operator review चाहिए
- total outage के बाद Galera disaster bootstrap
- बड़ी failure के बाद Gluster peer / brick recovery
- storage cluster membership से destructive node removal
- best-effort distros पर distro-specific package fixes
- RedHat-family systems पर SELinux hardening fine-tuning

---

## Verification / सत्यापन

Validation playbook चलाएँ:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml
```

या standalone के लिए:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

यह LibreNMS validator, Galera status, Redis Sentinel state, और Gluster volume status के लिए practical checks चलाता है।

---

## Development / डेवलपमेंट

Local lint चलाएँ:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Contributing / योगदान

Pull requests welcome हैं। पहले [CONTRIBUTING.md](../../CONTRIBUTING.md) पढ़ें।

## Security / सुरक्षा

Reporting guidance के लिए [SECURITY.md](../../SECURITY.md) पढ़ें।

## License / लाइसेंस

MIT. [LICENSE](../../LICENSE) देखें।
