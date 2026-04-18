# LibreNMS HA Ansible Deployment

面向生产环境的 Ansible 自动化，用于在多种 Linux 发行版上部署 **standalone、distributed polling 和 full HA** 的 LibreNMS。

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> 说明
> 英文 README 是规范版本。这个文件是完整翻译副本，方便更快上手。如果内容有差异，请以 [README.md](../../README.md) 为准。

## 为什么要做这个项目 / Why This Exists

LibreNMS 在单台服务器上很容易跑起来，但一旦你需要下面这些能力中的一项或多项，运维复杂度就会明显上升：

- 多个 LibreNMS Web 或 poller 节点
- Redis Sentinel
- Galera
- 共享 RRD 存储
- 位于 Web UI 和数据库负载均衡器前面的 VIP
- 主机故障后的可重复重建
- 同时支持 standalone 和 HA 的单一仓库

这个仓库提供一个统一的 Ansible 项目，可以部署：

1. **一体化 standalone LibreNMS**
2. **带 distributed pollers 和共享服务的 LibreNMS**
3. **full HA LibreNMS**，包含 MariaDB Galera、Redis Sentinel、HAProxy + Keepalived，以及基于 GlusterFS 的 RRD 存储。

---

## 你会得到什么 / What You Get

- 模块化的 Ansible roles，而不是一个巨大的 shell 脚本
- 基于 inventory 的拓扑选择
- 从同一个项目执行 standalone 或 cluster 部署
- 可选的 Galera 和 Redis Sentinel
- 可选的 VIP 与负载均衡层
- 可选的本地 SNMP agent 管理
- 对 SNMP **v1**、**v2c**、**v3** 的支持
- 添加和移除 LibreNMS 节点的 workflow
- 已适配 GitHub 的仓库结构，包含 MIT license、lint workflow、CONTRIBUTING、SECURITY、示例 inventory 和 secret 生成脚本

---

## 拓扑模式 / Topology Modes

### 1) Standalone
使用一台主机承担所有角色。

适合实验环境、小型部署以及带备份的单节点生产环境。

### 2) 不带数据库集群的 Cluster
使用多个 LibreNMS 节点，但连接到现有的外部 DB / Redis / storage 栈。

适合已经使用托管 MariaDB 或 Redis 的环境，也适合只想扩展 poller，而不想自建所有 HA 组件的用户。

### 3) Full HA
使用：
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

适合严肃的内部监控平台，以及已经理解 Galera / Redis / Gluster 恢复流程的运维团队。

> 重要
> 这个项目会自动化平台本身，以及 LibreNMS 文件和服务布局。首次应用 bootstrap 仍然保持保守策略。请先通过 Web 安装器完成第一次 bootstrap，然后将 `librenms_bootstrap_completed: true` 设为 true 并重新运行 playbook，以干净地应用 bootstrap 之后的设置。

---

## 支持矩阵 / Support Matrix

这个仓库按两个层级支持你需要的发行版：

| Distro | 级别 | 说明 |
|---|---|---|
| Ubuntu | Primary | 与 LibreNMS 官方文档最匹配 |
| Debian | Primary | 与 LibreNMS 官方文档最匹配 |
| Linux Mint | 接近 Primary | 使用 Debian 家族逻辑 |
| AlmaLinux | Strong best-effort | 使用 RedHat 家族逻辑 |
| Rocky Linux | Strong best-effort | 使用 RedHat 家族逻辑 |
| Fedora | Strong best-effort | 使用 RedHat 家族逻辑 |
| CentOS / CentOS Stream | Best-effort | 可能需要根据 PHP 可用性调整仓库 |
| Arch Linux | Best-effort | 已包含 family mapping；请在实验环境验证包名 |
| Manjaro Linux | Best-effort | 使用 Arch 家族逻辑 |
| Alpine Linux | Best-effort | OpenRC 和软件包差异可能需要 override |
| Gentoo | Best-effort | 软件包与服务差异可能需要 override |

### 现实说明 / Reality Check

LibreNMS 上游文档目前提供 **Ubuntu 24.04**、**Ubuntu 22.04**、**Debian 12**、**Debian 13** 和 **CentOS 8** 的安装示例。这个仓库通过易于覆盖的 family mapping 进一步扩展了支持范围，但在生产环境之前，你仍然应该先在实验环境测试非 primary 发行版。

另请参阅：
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## 仓库结构 / Repository Layout

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

## 快速开始 / Quick Start

1. 克隆仓库并安装 collections：

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

2. 生成 secrets：

```bash
python3 scripts/generate-secrets.py > inventories/ha/group_vars/vault.yml
```

或者 standalone：

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

3. 选择 inventory：
- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha/hosts.yml`

4. 填写 host IP、SSH user、`librenms_fqdn`、`librenms_app_key`、DB / Redis / VRRP secrets、VIP 参数以及 Gluster brick 配置。

5. 执行部署：

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

或：

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml
```

6. 在 `/install` 完成 LibreNMS 第一次 bootstrap，然后设置：

```yaml
librenms_bootstrap_completed: true
```

再重新运行同一个 playbook。

---

## Inventory 模型 / Inventory Model

这个仓库使用 inventory groups，而不是写死的假设。

- `librenms_nodes`: 应用节点
- `librenms_primary`: 用于 primary post-bootstrap tasks 的单个节点
- `librenms_web`: 提供 Web UI 的节点
- `librenms_db`: DB 或 Galera 节点
- `librenms_redis`: Redis / Sentinel 节点
- `lb_nodes`: HAProxy / Keepalived 节点
- `gluster_nodes`: 共享 RRD 存储节点
- `new_nodes`: 正在新增的节点
- `decommission_nodes`: 正在下线的节点

---

## 最重要的变量 / Variables That Matter Most

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

## 添加节点 / Add a Node

把 host 加入 `librenms_nodes`、`librenms_web` 或 `librenms_poller` 配置对应的组，再加入 `new_nodes`，设置唯一的 `librenms_node_id`，然后执行：

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/add-node.yml
```

这个 playbook 会复用 `site.yml`，配置新主机，协调 load balancer backends，并在需要时重新渲染 Redis / Galera / app 配置。

> 提示
> 对于 web/poller 节点，这是最安全的扩容路径。对于 Galera、Redis 或 Gluster 的 membership 变更，请先在实验环境验证流程，并阅读 [docs/architecture.md](../../docs/architecture.md)。

---

## 移除节点 / Remove a Node

把 host 从活跃组移除，加入 `decommission_nodes`，然后执行：

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/remove-node.yml
```

这会让剩余 cluster 与更新后的 inventory 对齐，并在被移除节点上停用或清理服务。

> 重要
> 从基于 Gluster 的 RRD 层中移除 storage 节点并不是常规操作。仓库有意将这个流程保留为需要 operator 审核的步骤。

---

## SNMP 支持 / SNMP Support

- `SNMPv1`: community-based，仅在必须支持旧硬件时使用。
- `SNMPv2c`: community-based，仍然常见于旧设备或简单 rollout。
- `SNMPv3`: 推荐优先使用；仓库可以配置 `snmpd`、创建 SNMPv3 users，并在 bootstrap 后设置 LibreNMS 的 SNMP version 顺序。

---

## 安全说明 / Security Notes

- 把 secrets 放在 `group_vars/vault.yml` 中，并使用 **Ansible Vault** 加密
- 不要提交生成出来的 vault 文件
- 在 public 或 semi-public 暴露之前，请先在 LibreNMS 前面加上 HTTPS
- 把 Galera 全集群恢复和 Gluster membership 变更视为明确的 operator tasks
- 定期测试 failover

参阅：
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## 已知边界 / Known Boundaries

### 适合完全自动化的部分
- package install
- repo checkout
- nginx / php-fpm config
- local MariaDB mode
- initial Galera join pattern
- Redis / Sentinel config
- HAProxy / Keepalived config
- LibreNMS app file deployment
- SNMP agent config
- 添加或移除应用节点

### 有意保留给 operator 审核的部分
- 全部 outage 之后的 Galera disaster bootstrap
- 严重故障后的 Gluster peer / brick recovery
- 从 storage cluster membership 中做 destructive node removal
- best-effort 发行版上的 distro-specific package fixes
- RedHat 家族系统上的 SELinux hardening 微调

---

## 验证 / Verification

运行 validation playbook：

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml
```

或 standalone：

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

它会对 LibreNMS validator、Galera status、Redis Sentinel state 和 Gluster volume status 执行一组实用检查。

---

## 开发 / Development

在本地运行 lint：

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## 贡献 / Contributing

欢迎提交 pull request。请先阅读 [CONTRIBUTING.md](../../CONTRIBUTING.md)。

## 安全 / Security

有关漏洞报告流程，请阅读 [SECURITY.md](../../SECURITY.md)。

## 许可证 / License

MIT。参见 [LICENSE](../../LICENSE)。
