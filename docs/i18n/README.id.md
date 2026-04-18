# LibreNMS HA Ansible Deployment

Otomasi Ansible yang dirancang untuk production untuk deployment LibreNMS **standalone, distributed polling, dan full HA** di berbagai keluarga Linux.

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> Catatan
> README bahasa Inggris adalah versi kanonik. Berkas ini adalah salinan terjemahan penuh untuk memudahkan onboarding. Jika ada perbedaan, ikuti [README.md](../../README.md).

## Mengapa Proyek Ini Ada / Why This Exists

LibreNMS mudah dijalankan di satu server, tetapi operasionalnya cepat menjadi rumit ketika Anda memerlukan satu atau lebih hal berikut:

- beberapa node web atau poller LibreNMS
- Redis Sentinel
- Galera
- storage RRD bersama
- VIP di depan Web UI dan load balancer database
- rebuild yang bisa diulang setelah host failure
- satu repo yang bisa menangani standalone dan HA

Repo ini memberi Anda satu proyek Ansible yang dapat melakukan deployment:

1. **LibreNMS standalone all-in-one**
2. **LibreNMS dengan distributed pollers dan shared services**
3. **LibreNMS full HA** dengan MariaDB Galera, Redis Sentinel, HAProxy + Keepalived, dan GlusterFS-backed RRD storage.

---

## Yang Anda Dapatkan / What You Get

- role Ansible modular, bukan satu shell script besar
- pemilihan topologi berbasis inventory
- deployment standalone atau cluster dari proyek yang sama
- Galera opsional dan Redis Sentinel opsional
- layer VIP dan load balancer opsional
- manajemen agent SNMP lokal opsional
- dukungan SNMP **v1**, **v2c**, dan **v3**
- workflow untuk menambah dan menghapus node LibreNMS
- struktur repo yang siap GitHub dengan MIT license, lint workflow, CONTRIBUTING, SECURITY, example inventories, dan helper pembuat secret

---

## Mode Topologi / Topology Modes

### 1) Standalone
Gunakan satu host untuk semuanya.

Cocok untuk lab, environment kecil, dan production satu node dengan backup.

### 2) Cluster Tanpa DB Cluster
Gunakan beberapa node LibreNMS tetapi hubungkan ke stack DB / Redis / storage eksternal yang sudah ada.

Cocok untuk environment dengan MariaDB atau Redis terkelola dan untuk pengguna yang ingin skala poller tanpa self-hosting semua komponen HA.

### 3) Full HA
Gunakan:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

Cocok untuk platform monitoring internal yang serius dan operator yang sudah memahami recovery Galera / Redis / Gluster.

> Penting
> Proyek ini mengotomasi platform serta layout file dan service LibreNMS. Bootstrap aplikasi pertama sengaja dibuat konservatif. Selesaikan bootstrap awal melalui web installer lalu jalankan ulang playbook dengan `librenms_bootstrap_completed: true` agar konfigurasi pasca-bootstrap diterapkan dengan rapi.

---

## Matriks Dukungan / Support Matrix

Repo ini dibuat untuk mendukung distro yang Anda minta, tetapi dukungannya dibagi dua tingkat:

| Distro | Tingkat | Catatan |
|---|---|---|
| Ubuntu | Utama | Paling cocok dengan dokumentasi resmi LibreNMS |
| Debian | Utama | Paling cocok dengan dokumentasi resmi LibreNMS |
| Linux Mint | Hampir utama | Menggunakan logika keluarga Debian |
| AlmaLinux | Strong best-effort | Logika keluarga RedHat |
| Rocky Linux | Strong best-effort | Logika keluarga RedHat |
| Fedora | Strong best-effort | Logika keluarga RedHat |
| CentOS / CentOS Stream | Best-effort | Mungkin perlu penyesuaian repo tergantung ketersediaan PHP |
| Arch Linux | Best-effort | Family mapping sudah ada; verifikasi nama paket di lab |
| Manjaro Linux | Best-effort | Menggunakan logika keluarga Arch |
| Alpine Linux | Best-effort | Perbedaan OpenRC dan paket mungkin butuh override |
| Gentoo | Best-effort | Perbedaan paket dan service mungkin butuh override |

### Reality Check

Dokumentasi upstream LibreNMS saat ini menyediakan contoh package/install untuk **Ubuntu 24.04**, **Ubuntu 22.04**, **Debian 12**, **Debian 13**, dan **CentOS 8**. Repo ini melangkah lebih jauh dengan family mapping yang mudah dioverride, tetapi distro non-primer tetap perlu diuji di lab sebelum production.

Lihat juga:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Struktur Repo / Repository Layout

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

## Mulai Cepat / Quick Start

1. Clone repo dan install collections:

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

2. Generate secret:

```bash
python3 scripts/generate-secrets.py > inventories/ha/group_vars/vault.yml
```

atau untuk standalone:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

3. Pilih inventory:
- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha/hosts.yml`

4. Isi host IP, SSH user, `librenms_fqdn`, `librenms_app_key`, DB / Redis / VRRP secrets, VIP details, dan pengaturan Gluster brick.

5. Jalankan deployment:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

atau:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml
```

6. Selesaikan bootstrap pertama LibreNMS di `/install`, lalu set:

```yaml
librenms_bootstrap_completed: true
```

dan jalankan ulang playbook yang sama.

---

## Model Inventory / Inventory Model

Repo ini memakai inventory groups alih-alih asumsi hard-coded.

- `librenms_nodes`: node aplikasi
- `librenms_primary`: satu node untuk primary post-bootstrap tasks
- `librenms_web`: node yang menyajikan Web UI
- `librenms_db`: node DB atau Galera
- `librenms_redis`: node Redis / Sentinel
- `lb_nodes`: node HAProxy / Keepalived
- `gluster_nodes`: node shared RRD storage
- `new_nodes`: node yang sedang ditambahkan
- `decommission_nodes`: node yang sedang dihapus

---

## Variabel Paling Penting / Variables That Matter Most

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

## Menambah Node / Add a Node

Tambahkan host ke `librenms_nodes`, ke `librenms_web` atau profil `librenms_poller`, masukkan ke `new_nodes`, beri `librenms_node_id` yang unik, lalu jalankan:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/add-node.yml
```

Playbook menggunakan kembali `site.yml`, mengonfigurasi host baru, menyelaraskan backend load balancer, dan me-render ulang Redis / Galera / app config bila diperlukan.

> Tip
> Untuk node web/poller, ini adalah jalur scaling yang paling aman. Untuk perubahan membership pada Galera, Redis, atau Gluster, uji dulu workflow di lab dan baca [docs/architecture.md](../../docs/architecture.md).

---

## Menghapus Node / Remove a Node

Keluarkan host dari grup aktif, masukkan ke `decommission_nodes`, lalu jalankan:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/remove-node.yml
```

Ini akan menyelaraskan cluster yang tersisa dengan inventory terbaru dan menonaktifkan atau membersihkan service di node yang dihapus.

> Penting
> Menghapus storage node dari layer RRD berbasis Gluster tidak diperlakukan sebagai operasi biasa. Repo ini sengaja membiarkannya sebagai workflow yang harus direview operator.

---

## Dukungan SNMP / SNMP Support

- `SNMPv1`: community-based, berguna saat Anda harus mendukung hardware lama.
- `SNMPv2c`: community-based dan masih umum untuk perangkat lama atau rollout sederhana.
- `SNMPv3`: direkomendasikan ketika perangkat mendukung; repo ini bisa mengonfigurasi `snmpd`, membuat SNMPv3 users, dan mengatur urutan versi SNMP setelah bootstrap.

---

## Catatan Keamanan / Security Notes

- Simpan secret di `group_vars/vault.yml` dan enkripsi dengan **Ansible Vault**
- Jangan commit file vault yang dihasilkan
- Gunakan HTTPS di depan LibreNMS sebelum public atau semi-public exposure
- Perlakukan full-cluster recovery Galera dan perubahan membership Gluster sebagai tugas operator eksplisit
- Uji failover secara berkala

Lihat:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Batasan Yang Diketahui / Known Boundaries

### Aman untuk diotomasi
- package install
- repo checkout
- nginx / php-fpm config
- local MariaDB mode
- initial Galera join pattern
- Redis / Sentinel config
- HAProxy / Keepalived config
- deployment file aplikasi LibreNMS
- konfigurasi SNMP agent
- tambah atau hapus application nodes

### Tetap direview operator
- Galera disaster bootstrap setelah total outage
- Gluster peer / brick recovery setelah kegagalan besar
- destructive node removal dari storage cluster membership
- distro-specific package fixes pada best-effort distros
- fine-tuning SELinux hardening pada sistem keluarga RedHat

---

## Verifikasi / Verification

Jalankan validation playbook:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml
```

atau untuk standalone:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

Playbook ini menjalankan practical checks untuk LibreNMS validator, Galera status, Redis Sentinel state, dan Gluster volume status.

---

## Pengembangan / Development

Jalankan lint secara lokal:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Kontribusi / Contributing

Pull request dipersilakan. Baca dulu [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Keamanan / Security

Baca [SECURITY.md](../../SECURITY.md) untuk panduan pelaporan.

## Lisensi / License

MIT. Lihat [LICENSE](../../LICENSE).
