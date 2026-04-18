# LibreNMS HA Ansible Deployment

畀 production 用嘅 Ansible automation，用嚟喺多種 Linux 系統上部署 LibreNMS 嘅 **standalone、distributed polling 同 full HA**。

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> 注意
> 英文 README 先係 canonical version。呢個檔案係完整翻譯版本，方便快啲上手。如果內容有出入，請以 [README.md](../../README.md) 為準。

## 點解要有呢個 project / Why This Exists

LibreNMS 喺單一 server 上好容易起得郁，但當你需要以下一樣或幾樣功能之後，operations 就會好快變得複雜：

- 多個 LibreNMS web 或 poller nodes
- Redis Sentinel
- Galera
- shared RRD storage
- 擺喺 Web UI 同 database load balancer 前面嘅 VIP
- host failure 之後可以 repeat 嘅 rebuild
- 一個同時處理 standalone 同 HA 嘅 repo

呢個 repo 提供一個 Ansible project，可以 deploy：

1. **all-in-one standalone LibreNMS**
2. **有 distributed pollers 同 shared services 嘅 LibreNMS**
3. **full HA LibreNMS** with MariaDB Galera, Redis Sentinel, HAProxy + Keepalived, 同 GlusterFS-backed RRD storage

---

## 你會得到咩 / What You Get

- modular Ansible roles，唔使靠一個超大 shell script
- inventory-driven topology selection
- 同一個 project 做 standalone 或 cluster deployment
- optional Galera 同 optional Redis Sentinel
- optional VIP 同 load balancer layer
- optional local SNMP agent management
- SNMP **v1**、**v2c**、**v3** support
- LibreNMS nodes add / remove workflow
- GitHub-ready repo structure with MIT license, lint workflow, CONTRIBUTING, SECURITY, example inventories, 同 secret generator

---

## Topology Modes / 拓撲模式

### 1) Standalone
一部 host 做晒全部嘢。

適合 labs、細 environment、同有 backup 嘅 single-node production。

### 2) 冇 DB Cluster 嘅 Cluster
用多個 LibreNMS nodes，但接去現有 external DB / Redis / storage stack。

適合用 managed MariaDB/Redis 嘅 environment，同埋想擴 poller 但唔想自己 host 所有 HA components 嘅 users。

### 3) Full HA
用：
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

適合 serious internal monitoring platforms，同埋熟悉 Galera / Redis / Gluster recovery 嘅 operators。

> 重要
> 呢個 project 會 automate 平台同 LibreNMS 嘅 file / service layout。第一次 app bootstrap 仍然刻意保守。請先用 web installer 完成第一個 bootstrap，之後再將 `librenms_bootstrap_completed: true` 設定好，然後重跑 playbook。

---

## Support Matrix / 支援矩陣

呢個 repo 係為咗支援你要嘅 distributions 而做，但分成兩個層級：

| Distro | Level | Notes |
|---|---|---|
| Ubuntu | Primary | 同 LibreNMS official docs 最夾 |
| Debian | Primary | 同 LibreNMS official docs 最夾 |
| Linux Mint | 幾乎 Primary | Debian-family logic |
| AlmaLinux | Strong best-effort | RedHat-family logic |
| Rocky Linux | Strong best-effort | RedHat-family logic |
| Fedora | Strong best-effort | RedHat-family logic |
| CentOS / CentOS Stream | Best-effort | 視乎 PHP availability，可能要調 repo |
| Arch Linux | Best-effort | 已經有 family mapping；package names 請喺 lab 驗證 |
| Manjaro Linux | Best-effort | Arch-family logic |
| Alpine Linux | Best-effort | OpenRC 同 package differences 可能要 override |
| Gentoo | Best-effort | package 同 service differences 可能要 override |

### Reality Check

LibreNMS upstream docs 而家有 **Ubuntu 24.04**、**Ubuntu 22.04**、**Debian 12**、**Debian 13** 同 **CentOS 8** 嘅 install examples。呢個 repo 用 override-friendly family mappings 再行前一步，但 non-primary distros 仍然應該喺 production 之前先喺 lab 測試。

另外可睇：
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Repository Layout / 倉庫結構

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

## Quick Start / 快速開始

1. clone 個 repo，同 install collections：

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

2. generate secrets：

```bash
python3 scripts/generate-secrets.py > inventories/ha/group_vars/vault.yml
```

或者 standalone：

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

3. 揀 inventory：
- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha/hosts.yml`

4. 填 host IP、SSH user、`librenms_fqdn`、`librenms_app_key`、DB / Redis / VRRP secrets、VIP details 同 Gluster brick settings。

5. 跑 deployment：

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

或者：

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml
```

6. 喺 `/install` 完成第一個 LibreNMS bootstrap，之後 set：

```yaml
librenms_bootstrap_completed: true
```

再重跑同一個 playbook。

---

## Inventory Model / Inventory 模型

呢個 repo 用 inventory groups，唔係用 hard-coded assumptions。

- `librenms_nodes`: application nodes
- `librenms_primary`: 做 primary post-bootstrap tasks 嘅一個 node
- `librenms_web`: serve Web UI 嘅 nodes
- `librenms_db`: DB 或 Galera nodes
- `librenms_redis`: Redis / Sentinel nodes
- `lb_nodes`: HAProxy / Keepalived nodes
- `gluster_nodes`: shared RRD storage nodes
- `new_nodes`: 正在 add 嘅 nodes
- `decommission_nodes`: 正在 remove 嘅 nodes

---

## 最重要嘅 variables / Variables That Matter Most

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

## 加 node / Add a Node

將 host 加入 `librenms_nodes`、`librenms_web` 或 `librenms_poller` profile，放入 `new_nodes`，設定 unique `librenms_node_id`，然後執行：

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/add-node.yml
```

呢個 playbook 會 reuse `site.yml`，配置新 host、reconcile load balancer backends，同埋喺需要時重新 render Redis / Galera / app configs。

---

## 刪 node / Remove a Node

將 host 喺 active groups 移走，放入 `decommission_nodes`，然後執行：

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/remove-node.yml
```

佢會令 surviving cluster 同 updated inventory 同步，並且 disable 或 cleanup removed node 上面嘅 services。

> 重要
> 喺 Gluster-backed RRD layer 移除 storage node 唔係 casual operation。呢個 repo 刻意將佢保留做 operator-reviewed workflow。

---

## SNMP Support / SNMP 支援

- `SNMPv1`: community-based；對 legacy hardware 有用。
- `SNMPv2c`: community-based，喺舊 device 或 simple rollout 依然常見。
- `SNMPv3`: recommended；repo 可以 configure `snmpd`、建立 SNMPv3 users，同埋喺 bootstrap 後 set SNMP version order。

---

## Security Notes / 安全說明

- 將 secrets 放喺 `group_vars/vault.yml`，再用 **Ansible Vault** 加密
- 唔好 commit generated vault files
- 喺 public 或 semi-public exposure 之前，先喺 LibreNMS 前面用 HTTPS
- 將 Galera full-cluster recovery 同 Gluster membership changes 視為明確嘅 operator tasks
- 定期測 failover

睇埋：
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Known Boundaries / 已知限制

### 適合 automate 嘅部分
- package install
- repo checkout
- nginx / php-fpm config
- local MariaDB mode
- initial Galera join pattern
- Redis / Sentinel config
- HAProxy / Keepalived config
- LibreNMS app file deployment
- SNMP agent config
- add 或 remove application nodes

### 需要 operator review 嘅部分
- total outage 後嘅 Galera disaster bootstrap
- 大故障後嘅 Gluster peer / brick recovery
- 喺 storage cluster membership 做 destructive node removal
- best-effort distros 上嘅 distro-specific package fixes
- RedHat-family systems 上嘅 SELinux hardening fine-tuning

---

## Verification / 驗證

執行 validation playbook：

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml
```

或者 standalone：

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

會對 LibreNMS validator、Galera status、Redis Sentinel state、同 Gluster volume status 做一組 practical checks。

---

## Development / 開發

喺本地跑 lint：

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Contributing / 貢獻

歡迎 Pull requests。請先睇 [CONTRIBUTING.md](../../CONTRIBUTING.md)。

## Security / 安全

有關 reporting guidance，請睇 [SECURITY.md](../../SECURITY.md)。

## License / 授權

MIT。請參閱 [LICENSE](../../LICENSE)。
