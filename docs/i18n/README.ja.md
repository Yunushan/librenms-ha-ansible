# LibreNMS HA Ansible Deployment

複数の Linux ファミリー上で **standalone、distributed polling、full HA** の LibreNMS を展開するための、本番運用向け Ansible 自動化です。

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> 注記
> 英語版 README が正本です。このファイルは導入しやすくするための完全翻訳版です。差分がある場合は [README.md](../../README.md) を優先してください。

## このプロジェクトが必要な理由 / Why This Exists

LibreNMS は 1 台のサーバーなら簡単に動かせますが、次のような要件が出てくると運用は一気に複雑になります。

- 複数の LibreNMS web または poller ノード
- Redis Sentinel
- Galera
- 共有 RRD ストレージ
- Web UI と DB load balancer の前段に置く VIP
- ホスト障害後に繰り返し実行できる再構築
- standalone と HA の両方を扱える単一リポジトリ

このリポジトリは、次の構成を 1 つの Ansible プロジェクトで展開できます。

1. **all-in-one の standalone LibreNMS**
2. **distributed pollers と shared services を使う LibreNMS**
3. **full HA LibreNMS**。MariaDB Galera、Redis Sentinel、HAProxy + Keepalived、GlusterFS-backed RRD storage を含みます。

---

## 得られるもの / What You Get

- 巨大な shell script ではなく、モジュール化された Ansible roles
- inventory 駆動の topology 選択
- 同じプロジェクトから standalone / cluster deployment
- optional な Galera と Redis Sentinel
- optional な VIP / load balancer レイヤー
- optional なローカル SNMP agent 管理
- SNMP **v1**、**v2c**、**v3** のサポート
- LibreNMS ノードの追加・削除 workflow
- MIT license、lint workflow、CONTRIBUTING、SECURITY、example inventories、secret generator を含む GitHub-ready な構成

---

## トポロジーモード / Topology Modes

### 1) Standalone
1 台の host ですべてを担当します。

lab、小規模環境、backup 付き single-node production に向いています。

### 2) DB Cluster なしの Cluster
複数の LibreNMS ノードを使い、既存の外部 DB / Redis / storage stack に接続します。

managed MariaDB / Redis を使う環境や、HA コンポーネントを全部 self-host せずに poller を増やしたいケースに向いています。

### 3) Full HA
使用する主な設定:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

本格的な内部 monitoring platform と、Galera / Redis / Gluster recovery を理解している運用チーム向けです。

> 重要
> このプロジェクトはプラットフォームと LibreNMS の file / service layout を自動化します。最初の application bootstrap は意図的に保守的です。まず web installer で最初の bootstrap を完了し、その後 `librenms_bootstrap_completed: true` を設定して同じ playbook を再実行してください。

---

## サポートマトリクス / Support Matrix

このリポジトリは必要な distro をサポートするよう作られていますが、サポートには 2 段階あります。

| Distro | レベル | メモ |
|---|---|---|
| Ubuntu | Primary | LibreNMS 公式ドキュメントと最も整合 |
| Debian | Primary | LibreNMS 公式ドキュメントと最も整合 |
| Linux Mint | ほぼ Primary | Debian family logic を使用 |
| AlmaLinux | Strong best-effort | RedHat family logic |
| Rocky Linux | Strong best-effort | RedHat family logic |
| Fedora | Strong best-effort | RedHat family logic |
| CentOS / CentOS Stream | Best-effort | PHP の availability により repo tuning が必要な場合あり |
| Arch Linux | Best-effort | family mapping あり。package names は lab で確認 |
| Manjaro Linux | Best-effort | Arch family logic |
| Alpine Linux | Best-effort | OpenRC と package 差分で override が必要な場合あり |
| Gentoo | Best-effort | package / service 差分で override が必要な場合あり |

### Reality Check

LibreNMS upstream docs は現在 **Ubuntu 24.04**、**Ubuntu 22.04**、**Debian 12**、**Debian 13**、**CentOS 8** 向けの install examples を提供しています。この repo は override-friendly な family mapping で対応範囲を広げていますが、primary 以外の distro は production 前に lab で検証すべきです。

参照:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## リポジトリ構成 / Repository Layout

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

## クイックスタート / Quick Start

1. リポジトリを clone して collections を install します。

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

2. secrets を生成します。

```bash
python3 scripts/generate-secrets.py > inventories/ha-3node/group_vars/vault.yml
```

standalone の場合:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

3. inventory を選びます。
- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha-3node/hosts.yml`

4. host IP、SSH user、`librenms_fqdn`、`librenms_app_key`、DB / Redis / VRRP secrets、VIP 設定、Gluster brick 設定を入力します。

5. deployment を実行します。

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

または:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/cluster.yml
```

6. `/install` で最初の LibreNMS bootstrap を完了し、次を設定します。

```yaml
librenms_bootstrap_completed: true
```

その後、同じ playbook を再実行します。

---

## Inventory モデル / Inventory Model

この repo は hard-coded assumptions ではなく inventory groups を使います。

- `librenms_nodes`: application nodes
- `librenms_primary`: primary post-bootstrap tasks を実行する 1 台の node
- `librenms_web`: Web UI を提供する nodes
- `librenms_db`: DB または Galera nodes
- `librenms_redis`: Redis / Sentinel nodes
- `lb_nodes`: HAProxy / Keepalived nodes
- `gluster_nodes`: shared RRD storage nodes
- `new_nodes`: 追加対象の nodes
- `decommission_nodes`: 削除対象の nodes

---

## 重要な変数 / Variables That Matter Most

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

## ノード追加 / Add a Node

host を `librenms_nodes`、`librenms_web` あるいは `librenms_poller` プロファイルのグループに追加し、`new_nodes` に入れ、ユニークな `librenms_node_id` を設定してから次を実行します。

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/add-node.yml
```

この playbook は `site.yml` を再利用し、新しい host を設定し、load balancer backends を調整し、必要に応じて Redis / Galera / app configs を再描画します。

> ヒント
> web/poller node の追加は最も安全なスケールパスです。Galera、Redis、Gluster の membership change を行う前に、必ず lab で試し、[docs/architecture.md](../../docs/architecture.md) を確認してください。

---

## ノード削除 / Remove a Node

host を active groups から外し、`decommission_nodes` に移してから次を実行します。

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/remove-node.yml
```

これにより、残存 cluster が更新後の inventory と整合し、削除対象 node の services が停止または cleanup されます。

> 重要
> Gluster-backed RRD layer から storage node を外す作業は、軽い操作として扱うべきではありません。この repo は意図的に operator review 前提の workflow にしています。

---

## SNMP サポート / SNMP Support

- `SNMPv1`: community-based。legacy hardware を扱う場合のみ有用です。
- `SNMPv2c`: community-based で、古い機器や単純な rollout では今でも一般的です。
- `SNMPv3`: デバイスが対応していれば推奨です。repo は `snmpd` の設定、SNMPv3 users の作成、bootstrap 後の SNMP version order 設定を行えます。

---

## セキュリティ注意事項 / Security Notes

- secrets は `group_vars/vault.yml` に保存し、**Ansible Vault** で暗号化してください
- 生成された vault files は commit しないでください
- public または semi-public exposure の前に HTTPS を前段に置いてください
- Galera full-cluster recovery と Gluster membership changes は明示的な operator task として扱ってください
- failover は定期的にテストしてください

参照:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## 既知の境界 / Known Boundaries

### 十分に自動化しやすい部分
- package install
- repo checkout
- nginx / php-fpm config
- local MariaDB mode
- initial Galera join pattern
- Redis / Sentinel config
- HAProxy / Keepalived config
- LibreNMS app file deployment
- SNMP agent config
- application nodes の追加と削除

### 意図的に operator review に残している部分
- total outage 後の Galera disaster bootstrap
- 深刻な障害後の Gluster peer / brick recovery
- storage cluster membership からの destructive node removal
- best-effort distro 上の distro-specific package fixes
- RedHat family systems での SELinux hardening 微調整

---

## 検証 / Verification

validation playbook を実行します。

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/validate.yml
```

standalone の場合:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

LibreNMS validator、Galera status、Redis Sentinel state、Gluster volume status に対して practical checks を実行します。

---

## 開発 / Development

ローカルで lint を実行します。

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## コントリビュート / Contributing

Pull request は歓迎です。まず [CONTRIBUTING.md](../../CONTRIBUTING.md) を読んでください。

## セキュリティ / Security

報告手順は [SECURITY.md](../../SECURITY.md) を参照してください。

## ライセンス / License

MIT。 [LICENSE](../../LICENSE) を参照してください。
