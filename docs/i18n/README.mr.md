# LibreNMS HA Ansible Deployment

अनेक Linux कुटुंबांवर LibreNMS चे **standalone, distributed polling, आणि full HA** deployment करण्यासाठी production-oriented Ansible automation.

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> नोंद
> English README ही canonical version आहे. ही फाइल सोप्या onboarding साठी full translated copy आहे. फरक आढळल्यास [README.md](../../README.md) ला प्राधान्य द्या.

## हा प्रोजेक्ट का आहे / Why This Exists

LibreNMS एकाच server वर चालवणे सोपे आहे, पण खालीलपैकी एक किंवा अधिक गोष्टी लागल्या की operations पटकन गुंतागुंतीचे होतात:

- अनेक LibreNMS web किंवा poller nodes
- Redis Sentinel
- Galera
- shared RRD storage
- Web UI आणि database load balancer समोर VIP
- host failure नंतर repeatable rebuild
- standalone आणि HA दोन्ही हाताळणारा एक repo

हा repo एकच Ansible project देतो जो deploy करू शकतो:

1. **all-in-one standalone LibreNMS**
2. **distributed pollers आणि shared services असलेला LibreNMS**
3. **full HA LibreNMS** with MariaDB Galera, Redis Sentinel, HAProxy + Keepalived, आणि GlusterFS-backed RRD storage

---

## तुम्हाला काय मिळते / What You Get

- मोठ्या shell script ऐवजी modular Ansible roles
- inventory-driven topology selection
- त्याच project मधून standalone किंवा cluster deployment
- optional Galera आणि optional Redis Sentinel
- optional VIP आणि load balancer layer
- optional local SNMP agent management
- SNMP **v1**, **v2c**, आणि **v3** support
- LibreNMS nodes add/remove workflow
- GitHub-ready repo structure with MIT license, lint workflow, CONTRIBUTING, SECURITY, example inventories, आणि secret generator

---

## Topology Modes / टोपोलॉजी मोड्स

### 1) Standalone
एक host सर्वकाही चालवतो.

lab, छोटे environments, आणि backup असलेले single-node production यासाठी योग्य.

### 2) DB Cluster शिवाय Cluster
अनेक LibreNMS nodes वापरा, पण त्यांना existing external DB / Redis / storage stack ला जोडा.

हे managed MariaDB/Redis environment आणि सर्व HA components स्वतः host न करता poller scale हवे असलेल्या users साठी योग्य आहे.

### 3) Full HA
वापरा:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

हे serious internal monitoring platforms आणि Galera / Redis / Gluster recovery समजणाऱ्या operators साठी आहे.

> महत्वाचे
> हा project platform आणि LibreNMS file/service layout automate करतो. Initial app bootstrap मुद्दाम conservative ठेवले आहे. आधी web installer ने पहिला bootstrap पूर्ण करा, मग `librenms_bootstrap_completed: true` सेट करून playbook पुन्हा चालवा.

---

## Support Matrix / सपोर्ट मॅट्रिक्स

हा repo अपेक्षित distributions साठी तयार आहे, पण support दोन स्तरांमध्ये दिला आहे:

| Distro | Level | Notes |
|---|---|---|
| Ubuntu | Primary | LibreNMS official docs शी सर्वाधिक जुळणारे |
| Debian | Primary | LibreNMS official docs शी सर्वाधिक जुळणारे |
| Linux Mint | जवळपास Primary | Debian-family logic |
| AlmaLinux | Strong best-effort | RedHat-family logic |
| Rocky Linux | Strong best-effort | RedHat-family logic |
| Fedora | Strong best-effort | RedHat-family logic |
| CentOS / CentOS Stream | Best-effort | PHP availability नुसार repo tuning लागू शकते |
| Arch Linux | Best-effort | family mapping आहे; lab मध्ये package names verify करा |
| Manjaro Linux | Best-effort | Arch-family logic |
| Alpine Linux | Best-effort | OpenRC आणि package differences मुळे override लागू शकते |
| Gentoo | Best-effort | package आणि service differences मुळे override लागू शकते |

### Reality Check

LibreNMS upstream docs सध्या **Ubuntu 24.04**, **Ubuntu 22.04**, **Debian 12**, **Debian 13**, आणि **CentOS 8** साठी install examples देतात. हा repo family mappings मुळे त्यापेक्षा पुढे जातो, पण non-primary distros production आधी lab मध्ये test करणे गरजेचे आहे.

पहा:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Repository Layout / रिपॉझिटरी रचना

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

## Quick Start / झटपट सुरुवात

1. Repo clone करा आणि collections install करा:

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

2. Secrets generate करा:

```bash
python3 scripts/generate-secrets.py > inventories/ha/group_vars/vault.yml
```

किंवा standalone साठी:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

3. Inventory निवडा:
- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha/hosts.yml`

4. Host IPs, SSH user, `librenms_fqdn`, `librenms_app_key`, DB / Redis / VRRP secrets, VIP details, आणि Gluster brick settings भरा।

5. Deployment चालवा:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

किंवा:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml
```

6. `/install` वर पहिला LibreNMS bootstrap पूर्ण करा, मग हे set करा:

```yaml
librenms_bootstrap_completed: true
```

आणि तोच playbook पुन्हा चालवा।

---

## Inventory Model / इन्व्हेंटरी मॉडेल

हा repo hard-coded assumptions ऐवजी inventory groups वापरतो.

- `librenms_nodes`: application nodes
- `librenms_primary`: primary post-bootstrap tasks साठी एक node
- `librenms_web`: Web UI serve करणारे nodes
- `librenms_db`: DB किंवा Galera nodes
- `librenms_redis`: Redis / Sentinel nodes
- `lb_nodes`: HAProxy / Keepalived nodes
- `gluster_nodes`: shared RRD storage nodes
- `new_nodes`: add होत असलेले nodes
- `decommission_nodes`: remove होत असलेले nodes

---

## सर्वात महत्त्वाचे variables / Variables That Matter Most

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

## Node जोडणे / Add a Node

Host ला `librenms_nodes`, `librenms_web` किंवा `librenms_poller` profile मध्ये जोडा, `new_nodes` मध्ये ठेवा, unique `librenms_node_id` सेट करा, आणि मग चालवा:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/add-node.yml
```

हा playbook `site.yml` reuse करतो, नवीन host configure करतो, load balancer backends reconcile करतो, आणि गरज पडल्यास Redis / Galera / app configs पुन्हा render करतो.

---

## Node काढणे / Remove a Node

Host ला active groups मधून काढा, `decommission_nodes` मध्ये ठेवा, आणि मग चालवा:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/remove-node.yml
```

यामुळे surviving cluster updated inventory सोबत sync होतो आणि removed node वरील services disable किंवा cleanup होतात.

> महत्वाचे
> Gluster-backed RRD layer मधून storage node काढणे casual operation समजले जात नाही. Repo मुद्दाम हे operator-reviewed workflow म्हणून ठेवतो.

---

## SNMP Support / SNMP सपोर्ट

- `SNMPv1`: community-based; legacy hardware साठी उपयोगी.
- `SNMPv2c`: community-based आणि जुने devices किंवा simple rollout मध्ये अजूनही common.
- `SNMPv3`: recommended; repo `snmpd` configure करू शकतो, SNMPv3 users तयार करू शकतो, आणि bootstrap नंतर SNMP version order set करू शकतो.

---

## Security Notes / सुरक्षा नोंदी

- Secrets `group_vars/vault.yml` मध्ये ठेवा आणि **Ansible Vault** ने encrypt करा
- generated vault files commit करू नका
- public किंवा semi-public exposure आधी LibreNMS समोर HTTPS वापरा
- Galera full-cluster recovery आणि Gluster membership changes यांना explicit operator tasks माना
- failover नियमितपणे test करा

पहा:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Known Boundaries / ज्ञात मर्यादा

### सहज automate होणाऱ्या गोष्टी
- package install
- repo checkout
- nginx / php-fpm config
- local MariaDB mode
- initial Galera join pattern
- Redis / Sentinel config
- HAProxy / Keepalived config
- LibreNMS app file deployment
- SNMP agent config
- application nodes add किंवा remove करणे

### operator review लागणाऱ्या गोष्टी
- total outage नंतर Galera disaster bootstrap
- मोठ्या failure नंतर Gluster peer / brick recovery
- storage cluster membership मधून destructive node removal
- best-effort distros वर distro-specific package fixes
- RedHat-family systems वर SELinux hardening fine-tuning

---

## Verification / पडताळणी

Validation playbook चालवा:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml
```

किंवा standalone साठी:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

हे LibreNMS validator, Galera status, Redis Sentinel state, आणि Gluster volume status साठी practical checks चालवते.

---

## Development / डेव्हलपमेंट

Local lint चालवा:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Contributing / योगदान

Pull requests स्वागतार्ह आहेत. आधी [CONTRIBUTING.md](../../CONTRIBUTING.md) वाचा।

## Security / सुरक्षा

Reporting guidance साठी [SECURITY.md](../../SECURITY.md) वाचा।

## License / परवाना

MIT. [LICENSE](../../LICENSE) पहा।
