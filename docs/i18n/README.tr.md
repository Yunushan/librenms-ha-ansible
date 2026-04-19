# LibreNMS HA Ansible Deployment

Uretim odakli Ansible otomasyonu ile **standalone, distributed polling ve full HA** LibreNMS kurulumlarini birden fazla Linux ailesinde yonetin.

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> Not
> Ingilizce README kanonik surumdur. Bu dosya daha kolay onboard olmak icin tam ceviri olarak tutulur. Herhangi bir fark gorursen [README.md](../../README.md) dosyasini esas al.

## Network and Access Matrix

For the exact controller-to-node ports, cluster east-west traffic, and sudo requirements, see the canonical English section [Network and Access Matrix](../../README.md#network-and-access-matrix).

## Neden Var / Why This Exists

LibreNMS tek bir sunucuda kolayca ayaga kalkar, ancak asagidaki ihtiyaclardan biri ya da birkaci ortaya ciktiginda operasyonel olarak hizla karmasiklasir:

- birden fazla LibreNMS web veya poller dugumu
- Redis Sentinel
- Galera
- paylasimli RRD depolamasi
- Web UI ve veritabani load balancer onunde bir VIP
- host arizasindan sonra tekrarlanabilir yeniden kurulumlar
- hem standalone hem HA'yi kapsayan tek bir repo

Bu repo size su modlari kurabilen tek bir Ansible projesi verir:

1. **Hepsi bir arada standalone LibreNMS**
2. **Distributed poller ve paylasimli servislerle LibreNMS**
3. **Full HA LibreNMS** su bilesenlerle:
   - birden fazla web veya full dugum
   - MariaDB Galera
   - Redis Sentinel
   - HAProxy + Keepalived
   - GlusterFS tabanli RRD depolamasi

---

## Neler Saglar / What You Get

- tek bir dev shell script yerine moduler Ansible rolleri
- inventory tabanli topoloji secimi
- ayni projeden standalone veya cluster kurulumlari
- opsiyonel Galera ve opsiyonel Redis Sentinel
- opsiyonel VIP ve load balancer katmani
- opsiyonel yerel SNMP agent yonetimi
- SNMP **v1**, **v2c** ve **v3** destegi
- LibreNMS dugumu ekleme ve kaldirma akislari
- MIT lisansi, lint workflow'u, CONTRIBUTING ve SECURITY belgeleri, ornek inventory'ler ve helper secret uretici ile GitHub hazir repo yapisi

---

## Topoloji Modlari / Topology Modes

### 1) Standalone
Her sey icin tek host kullan.

Su durumlar icin iyi:
- lab ortamlari
- kucuk ortamlar
- yedeklemeli tek node production

### 2) Veritabani Cluster'i Olmadan Cluster
Birden fazla LibreNMS dugumu kullan, ancak var olan harici DB / Redis / storage yiginina baglan.

Su durumlar icin iyi:
- yonetilen MariaDB veya Redis kullanan ortamlar
- tum HA bilesenlerini kendisi host etmeden poller olcegi isteyen kullanicilar

### 3) Full HA
Sunlari kullan:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

Su durumlar icin iyi:
- ciddi dahili monitoring platformlari
- web ve poller surekliligi gereken ortamlar
- Galera / Redis / Gluster recovery akisini bilen operatorler

> Onemli
> Varsayilan olarak post-bootstrap gorevleri otomatik uygulanir, cunku
> varsayilan deger `librenms_bootstrap_auto_complete: true` olarak gelir.
> Ilk uygulama bootstrap'ini web installer ile tamamla ve inventory
> degistirmeden ayni playbook'u yeniden calistir. Eski iki asamali akis sadece
> `librenms_bootstrap_auto_complete: false` ayarlarsan gerekir; bu modda
> installer'i tamamladiktan sonra `librenms_bootstrap_completed: true` ile
> tekrar calistir.

---

## Destek Matrisi / Support Matrix

Bu repo istenen dagitimlari desteklemek icin tasarlandi, ancak bunu iki seviye halinde yapar:

| Distro | Seviye | Notlar |
|---|---|---|
| Ubuntu | Birincil | LibreNMS upstream dokumanlariyla en uyumlu secenek |
| Debian | Birincil | LibreNMS upstream dokumanlariyla en uyumlu secenek |
| Linux Mint | Birincile yakin | Debian ailesi mantigini kullanir |
| AlmaLinux | Guclu best-effort | RedHat ailesi mantigini kullanir |
| Rocky Linux | Guclu best-effort | RedHat ailesi mantigini kullanir |
| Fedora | Guclu best-effort | RedHat ailesi mantigini kullanir |
| CentOS / CentOS Stream | Best-effort | PHP bulunabilirligine gore repo ayari gerekebilir |
| Arch Linux | Best-effort | Aile eslemesi vardir; paket adlarini labda dogrula |
| Manjaro Linux | Best-effort | Arch ailesi mantigini kullanir |
| Alpine Linux | Best-effort | OpenRC ve paket farklari override gerektirebilir |
| Gentoo | Best-effort | Paket atomu ve servis farklari override gerektirebilir |

### Gercekci Not / Reality Check

LibreNMS upstream dokumantasyonu su anda **Ubuntu 24.04**, **Ubuntu 22.04**, **Debian 12**, **Debian 13** ve **CentOS 8** icin paket ve kurulum ornekleri verir. Bu repo aile bazli ve override dostu eslemelerle bunun otesine gecer, ancak birincil olmayan dagitimlari production oncesi labda test etmelisin.

Ayrica bak:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Repo Yapisi / Repository Layout

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

## Hizli Baslangic / Quick Start

### 1) Repo'yu klonla ve koleksiyonlari kur

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

### 2) Secret uret

```bash
python3 scripts/generate-secrets.py > inventories/ha/group_vars/vault.yml
```

veya standalone icin:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

### 3) Bir inventory sec

- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha/hosts.yml`

### 4) Inventory ve group var dosyalarini duzenle

En azindan sunlari ayarla:
- host IP'leri ve SSH kullanicisi
- `librenms_fqdn`
- `librenms_app_key`
- DB / Redis / VRRP secret'lari
- HA icin VIP ayrintilari
- HA icin Gluster brick ayarlari

### 5) Deploy islemini calistir

Standalone:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

HA / cluster:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml
```

### 6) Ilk LibreNMS bootstrap'ini tamamla

Siteyi ac ve ilk uygulama bootstrap'ini tamamla:

```text
http://librenms.example.com/install
```

veya standalone icin:

```text
http://<your-hostname-or-ip>/install
```

Ardindan ayni playbook'u yeniden calistir. Varsayilan olarak inventory
degisikligi gerekmez; `librenms_bootstrap_auto_complete: true` post-bootstrap
`lnms config:set` gorevlerini otomatik acar.

Eski konservatif iki asamali akisi bilincli olarak kullanmak istersen sunu
ayarla:

```yaml
librenms_bootstrap_auto_complete: false
```

installer'i tamamladiktan sonra sunu ayarlayip tekrar calistir:

```yaml
librenms_bootstrap_completed: true
```

---

## Inventory Modeli / Inventory Model

Bu repo sabit varsayimlar yerine inventory gruplari kullanir.

### Temel gruplar

- `librenms_nodes` - uygulama dugumleri
- `librenms_primary` - bootstrap sonrasi ana konfig gorevleri icin kullanilan bir dugum
- `librenms_web` - Web UI sunan dugumler
- `librenms_db` - DB veya Galera dugumleri
- `librenms_redis` - Redis / Sentinel dugumleri
- `lb_nodes` - HAProxy / Keepalived dugumleri
- `gluster_nodes` - paylasimli RRD depolama dugumleri

### Yasam dongusu gruplari

- `new_nodes` - ekledigin dugumler
- `decommission_nodes` - kaldirilacak dugumler

---

## En Onemli Degiskenler / Variables That Matter Most

### Kurulum modu

```yaml
librenms_mode: standalone           # standalone | cluster | ha
librenms_install_profile: full      # full | web | poller
```

### Veritabani modu

```yaml
librenms_db_mode: local             # local | external | galera
librenms_db_host: ""
librenms_db_name: librenms
librenms_db_user: librenms
librenms_db_password: CHANGE_ME
```

### Redis modu

```yaml
librenms_redis_mode: local          # local | external | sentinel
librenms_redis_password: CHANGE_ME
librenms_redis_sentinel_password: CHANGE_ME
librenms_redis_master_host: lnms1
```

### RRD depolama modu

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

## Dugum Ekleme / Add a Node

### Yeni bir LibreNMS uygulama dugumu ekle

1. Host'u `librenms_nodes`, `librenms_web` ya da `librenms_install_profile` ile `librenms_poller` benzeri kullanim grubuna ve `new_nodes` grubuna ekle.
2. Benzersiz bir `librenms_node_id` ver.
3. Tekrar calistir:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/add-node.yml
```

Bu playbook `site.yml` dosyasini yeniden kullanir, yeni host'u konfigure eder, load balancer backend'lerini uzlastirir ve gerektiginde Redis / Galera / app config dosyalarini yeniden uretir.

> Ipuclari
> **Web/poller dugumu** icin bu en guvenli olcekleme yoludur.
> **Galera**, **Redis** veya **Gluster** uyelik degisiklikleri icin once akisi labda test et ve [docs/architecture.md](../../docs/architecture.md) dosyasini oku. Depolama uyeligi degisiklikleri bilerek web dugumu degisikliklerinden daha temkinlidir.

---

## Dugum Kaldirma / Remove a Node

1. Host'u aktif gruplardan cikar (`librenms_nodes`, `librenms_web`, `librenms_db`, `librenms_redis`, `lb_nodes`, `gluster_nodes`).
2. `decommission_nodes` grubuna koy.
3. Calistir:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/remove-node.yml
```

Bu, guncellenmis inventory ile hayatta kalan cluster'i uzlastirir ve kaldirilan dugumde servisleri durdurur ya da istege bagli olarak temizler.

> Onemli
> Gluster tabanli RRD katmanindan bir depolama dugumunu cikarmak rutin bir islem gibi ele alinmaz. Repo bunu bilerek operator incelemesine birakir.

---

## SNMP Destegi / SNMP Support

Bu repo uc SNMP modunu destekler:

### SNMPv1
Community tabanlidir. Yalnizca eski donanimi desteklemek zorundaysan kullanislidir.

### SNMPv2c
Community tabanlidir ve eski cihazlar veya basit rollout'lar icin hala yaygindir.

### SNMPv3
Cihazlar destekliyorsa onerilir. Bu repo yerel `snmpd` ayarlayabilir, SNMPv3 kullanicilari olusturabilir ve bootstrap sonrasinda LibreNMS SNMP surum siralamasi ayarlayabilir.

> Not
> Yerel agent tarafinda SNMPv1 ve SNMPv2c community tabanli agent konfigrasyonu kullanir. Fark daha cok LibreNMS'in izlenen cihazlarla konustugu tarafta onem kazanir.

---

## Guvenlik Notlari / Security Notes

- Secret'lari `group_vars/vault.yml` icinde tut ve **Ansible Vault** ile sifrele
- Uretilmis vault dosyalarini commit etme
- LibreNMS'i public veya yari-public ortama acmadan once HTTPS kullan
- Galera tum-cluster recovery ve Gluster uyelik degisikliklerini operator gorevi olarak ele al
- Failover testlerini duzenli yap

Bak:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Bilinen Sinirlar / Known Boundaries

Bu proje zor kisimlarda bilerek acik sozludur.

### Tam rahatlikla otomatize edilenler
- paket kurulumu
- repo checkout
- nginx / php-fpm config
- MariaDB local modu
- Galera ilk node join deseni
- Redis / Sentinel config
- HAProxy / Keepalived config
- LibreNMS uygulama dosyalarinin deploy edilmesi
- SNMP agent config
- uygulama dugumu ekleme veya kaldirma

### Bilerek operator incelemesine birakilanlar
- tam kesinti sonrasi Galera disaster bootstrap
- buyuk ariza sonrasi Gluster peer / brick recovery
- storage cluster uyeliginden yikici node cikarma islemleri
- best-effort dagitimlarda distro ozel paket duzeltmeleri
- RedHat ailesinde SELinux hardening ince ayari

---

## Dogrulama / Verification

Validation playbook'unu calistir:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml
```

veya standalone icin:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

Bu, LibreNMS validator, Galera durumu, Redis Sentinel durumu ve Gluster volume durumu uzerinde pratik kontroller calistirir.

---

## Gelistirme / Development

Lint'i yerelde calistir:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Katki / Contributing

Pull request'ler memnuniyetle kabul edilir. Once [CONTRIBUTING.md](../../CONTRIBUTING.md) dosyasini oku.

## Guvenlik / Security

Bildirim rehberi icin [SECURITY.md](../../SECURITY.md) dosyasini oku.

## Lisans / License

MIT. Bkz. [LICENSE](../../LICENSE).
