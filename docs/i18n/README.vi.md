# LibreNMS HA Ansible Deployment

Tu dong hoa Ansible huong toi production de trien khai LibreNMS o cac che do **standalone, distributed polling va full HA** tren nhieu ho Linux.

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> Luu y
> README tieng Anh la ban chuan. Tep nay la ban dich day du de giup onboard nhanh hon. Neu co khac biet, hay uu tien [README.md](../../README.md).

## Vi Sao Co Du An Nay / Why This Exists

LibreNMS de chay tren mot may chu, nhung van hanh se nhanh chong phuc tap khi ban can mot hoac nhieu thu sau:

- nhieu node web hoac poller LibreNMS
- Redis Sentinel
- Galera
- RRD storage dung chung
- VIP dat truoc Web UI va database load balancer
- kha nang rebuild lap lai sau host failure
- mot repo duy nhat cho ca standalone va HA

Repo nay cung cap mot du an Ansible duy nhat de trien khai:

1. **LibreNMS standalone all-in-one**
2. **LibreNMS voi distributed pollers va shared services**
3. **LibreNMS full HA** voi MariaDB Galera, Redis Sentinel, HAProxy + Keepalived va GlusterFS-backed RRD storage.

---

## Ban Nhan Duoc Gi / What You Get

- cac role Ansible dang module thay vi mot shell script khong lo
- lua chon topology dua tren inventory
- deployment standalone hoac cluster tu cung mot du an
- Galera tuy chon va Redis Sentinel tuy chon
- lop VIP va load balancer tuy chon
- quan ly local SNMP agent tuy chon
- ho tro SNMP **v1**, **v2c**, **v3**
- workflow de them va xoa node LibreNMS
- cau truc repo san sang cho GitHub voi MIT license, lint workflow, CONTRIBUTING, SECURITY, example inventories va helper tao secret

---

## Che Do Topology / Topology Modes

### 1) Standalone
Dung mot host cho tat ca.

Phu hop voi lab, moi truong nho va production mot node co backup.

### 2) Cluster Khong Co DB Cluster
Dung nhieu node LibreNMS nhung tro toi stack DB / Redis / storage ben ngoai da co san.

Phu hop voi moi truong dung MariaDB hoac Redis duoc quan ly, va voi nguoi muon mo rong poller ma khong tu host tat ca thanh phan HA.

### 3) Full HA
Dung:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

Phu hop voi nen tang monitoring noi bo nghiem tuc va doi ngu van hanh da hieu quy trinh recovery cua Galera / Redis / Gluster.

> Quan trong
> Du an nay tu dong hoa nen tang va bo tri file / service cua LibreNMS. Bootstrap ung dung lan dau co chu y duoc giu than trong. Hay hoan tat bootstrap dau tien bang web installer, sau do chay lai playbook voi `librenms_bootstrap_completed: true` de ap dung sach se cac cai dat sau bootstrap.

---

## Ma Tran Ho Tro / Support Matrix

Repo nay duoc xay dung de ho tro cac distro ban can, nhung duoc chia thanh hai muc:

| Distro | Muc | Ghi chu |
|---|---|---|
| Ubuntu | Chinh | Phu hop nhat voi tai lieu chinh thuc cua LibreNMS |
| Debian | Chinh | Phu hop nhat voi tai lieu chinh thuc cua LibreNMS |
| Linux Mint | Gan chinh | Dung logic ho Debian |
| AlmaLinux | Strong best-effort | Logic ho RedHat |
| Rocky Linux | Strong best-effort | Logic ho RedHat |
| Fedora | Strong best-effort | Logic ho RedHat |
| CentOS / CentOS Stream | Best-effort | Co the can chinh repo tuy theo do san co cua PHP |
| Arch Linux | Best-effort | Da co family mapping; can kiem tra ten package trong lab |
| Manjaro Linux | Best-effort | Dung logic ho Arch |
| Alpine Linux | Best-effort | Khac biet OpenRC va package co the can override |
| Gentoo | Best-effort | Khac biet package va service co the can override |

### Reality Check

Tai lieu upstream cua LibreNMS hien cung cap vi du cai dat cho **Ubuntu 24.04**, **Ubuntu 22.04**, **Debian 12**, **Debian 13** va **CentOS 8**. Repo nay di xa hon voi family mapping de override de dang, nhung cac distro khong thuoc nhom chinh van nen duoc test trong lab truoc khi dua vao production.

Xem them:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Cau Truc Repo / Repository Layout

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

## Bat Dau Nhanh / Quick Start

1. Clone repo va cai collections:

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

2. Tao secret:

```bash
python3 scripts/generate-secrets.py > inventories/ha-3node/group_vars/vault.yml
```

hoac voi standalone:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

3. Chon inventory:
- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha-3node/hosts.yml`

4. Dien host IP, SSH user, `librenms_fqdn`, `librenms_app_key`, DB / Redis / VRRP secrets, VIP details va cau hinh Gluster brick.

5. Chay deployment:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

hoac:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/cluster.yml
```

6. Hoan tat bootstrap LibreNMS dau tien tai `/install`, sau do set:

```yaml
librenms_bootstrap_completed: true
```

roi chay lai cung playbook do.

---

## Mo Hinh Inventory / Inventory Model

Repo nay dung inventory groups thay vi cac gia dinh hard-coded.

- `librenms_nodes`: cac node ung dung
- `librenms_primary`: mot node dung cho primary post-bootstrap tasks
- `librenms_web`: cac node phuc vu Web UI
- `librenms_db`: cac node DB hoac Galera
- `librenms_redis`: cac node Redis / Sentinel
- `lb_nodes`: cac node HAProxy / Keepalived
- `gluster_nodes`: cac node shared RRD storage
- `new_nodes`: cac node dang duoc them vao
- `decommission_nodes`: cac node dang bi go bo

---

## Bien Quan Trong Nhat / Variables That Matter Most

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

## Them Node / Add a Node

Them host vao `librenms_nodes`, vao `librenms_web` hoac profile `librenms_poller`, dua vao `new_nodes`, dat `librenms_node_id` duy nhat, roi chay:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/add-node.yml
```

Playbook se tai su dung `site.yml`, cau hinh host moi, can bang lai load balancer backends va render lai Redis / Galera / app config khi can.

> Meo
> Day la cach scale an toan nhat cho web/poller node. Voi thay doi membership cua Galera, Redis hoac Gluster, hay test truoc trong lab va doc [docs/architecture.md](../../docs/architecture.md).

---

## Xoa Node / Remove a Node

Dua host ra khoi cac active groups, them vao `decommission_nodes`, roi chay:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/remove-node.yml
```

Lenh nay se dong bo cluster con lai voi inventory moi va tat hoac cleanup service tren node bi go bo.

> Quan trong
> Viec loai bo storage node khoi Gluster-backed RRD layer khong duoc xem la thao tac thong thuong. Repo co chu y de quy trinh nay cho operator review.

---

## Ho Tro SNMP / SNMP Support

- `SNMPv1`: community-based, huu ich khi ban bat buoc phai ho tro hardware cu.
- `SNMPv2c`: community-based va van pho bien cho thiet bi cu hoac rollout don gian.
- `SNMPv3`: duoc khuyen nghi khi thiet bi ho tro; repo co the cau hinh `snmpd`, tao SNMPv3 users va dat thu tu SNMP versions sau bootstrap.

---

## Ghi Chu Bao Mat / Security Notes

- Luu secret trong `group_vars/vault.yml` va ma hoa bang **Ansible Vault**
- Khong commit cac vault file da sinh ra
- Dung HTTPS truoc LibreNMS truoc khi public hoac semi-public exposure
- Xem Galera full-cluster recovery va Gluster membership changes la operator tasks ro rang
- Thu failover dinh ky

Xem:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Gioi Han Da Biet / Known Boundaries

### Co the tu dong hoa thoai mai
- package install
- repo checkout
- nginx / php-fpm config
- local MariaDB mode
- initial Galera join pattern
- Redis / Sentinel config
- HAProxy / Keepalived config
- LibreNMS app file deployment
- SNMP agent config
- them hoac xoa application nodes

### Co y de operator review
- Galera disaster bootstrap sau total outage
- Gluster peer / brick recovery sau su co nghiem trong
- destructive node removal khoi storage cluster membership
- distro-specific package fixes tren best-effort distros
- tinh chinh SELinux hardening tren he RedHat family

---

## Xac Minh / Verification

Chay validation playbook:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/validate.yml
```

hoac voi standalone:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

Playbook nay chay practical checks cho LibreNMS validator, Galera status, Redis Sentinel state va Gluster volume status.

---

## Phat Trien / Development

Chay lint o local:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Dong Gop / Contributing

Pull request duoc hoan nghenh. Hay doc [CONTRIBUTING.md](../../CONTRIBUTING.md) truoc.

## Bao Mat / Security

Hay doc [SECURITY.md](../../SECURITY.md) de xem huong dan bao cao.

## Giay Phep / License

MIT. Xem [LICENSE](../../LICENSE).
