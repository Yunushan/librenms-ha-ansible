# LibreNMS HA Ansible Deployment

أتمتة Ansible موجهة للإنتاج لنشر LibreNMS في أوضاع **standalone** و **distributed polling** و **full HA** على عدة عائلات من Linux.

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> ملاحظة
> ملف README الإنجليزي هو النسخة المرجعية. هذا الملف نسخة مترجمة كاملة لتسهيل البدء. إذا وُجد اختلاف فاعتمد [README.md](../../README.md).

## لماذا يوجد هذا المشروع / Why This Exists

من السهل تشغيل LibreNMS على خادم واحد، لكن التشغيل يصبح معقدًا بسرعة عندما تحتاج إلى واحد أو أكثر مما يلي:

- عدة عقد web أو poller من LibreNMS
- Redis Sentinel
- Galera
- تخزين RRD مشترك
- VIP أمام Web UI وموازن حمل قاعدة البيانات
- إعادة بناء قابلة للتكرار بعد فشل host
- مستودع واحد يدعم standalone و HA معًا

يوفر هذا المستودع مشروع Ansible واحدًا يمكنه نشر:

1. **LibreNMS standalone all-in-one**
2. **LibreNMS مع distributed pollers و shared services**
3. **LibreNMS full HA** مع MariaDB Galera و Redis Sentinel و HAProxy + Keepalived و GlusterFS-backed RRD storage

---

## ماذا ستحصل عليه / What You Get

- أدوار Ansible modular بدلًا من shell script ضخم
- اختيار topology بالاعتماد على inventory
- نشر standalone أو cluster من نفس المشروع
- Galera اختياري و Redis Sentinel اختياري
- طبقة VIP و load balancer اختيارية
- إدارة local SNMP agent اختيارية
- دعم SNMP **v1** و **v2c** و **v3**
- workflow لإضافة وإزالة عقد LibreNMS
- بنية repo جاهزة لـ GitHub مع MIT license و lint workflow و CONTRIBUTING و SECURITY و inventories أمثلة ومولّد secrets

---

## أوضاع البنية / Topology Modes

### 1) Standalone
استخدم host واحدًا لكل شيء.

مناسب للمختبرات والبيئات الصغيرة والإنتاج بعقدة واحدة مع نسخ احتياطي.

### 2) Cluster بدون DB Cluster
استخدم عدة عقد LibreNMS لكن اربطها مع stack خارجي موجود لـ DB / Redis / storage.

مناسب للبيئات التي تستخدم MariaDB أو Redis مُدار، ولمن يريد توسيع pollers من دون استضافة كل مكونات HA بنفسه.

### 3) Full HA
استخدم:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

مناسب لمنصات monitoring داخلية جادة، وللمشغلين الذين يفهمون recovery الخاص بـ Galera / Redis / Gluster.

> مهم
> هذا المشروع يؤتمت المنصة نفسها وكذلك file/service layout الخاص بـ LibreNMS. أما bootstrap الأول للتطبيق فهو محافظ عن قصد. أكمل أول bootstrap عبر web installer أولًا، ثم أعد تشغيل playbook مع `librenms_bootstrap_completed: true` لتطبيق إعدادات ما بعد bootstrap بشكل نظيف.

---

## مصفوفة الدعم / Support Matrix

هذا المستودع صُمم لدعم التوزيعات المطلوبة، لكنه يفعل ذلك على مستويين:

| Distro | المستوى | ملاحظات |
|---|---|---|
| Ubuntu | أساسي | أفضل توافق مع وثائق LibreNMS الرسمية |
| Debian | أساسي | أفضل توافق مع وثائق LibreNMS الرسمية |
| Linux Mint | قريب من الأساسي | يستخدم منطق Debian-family |
| AlmaLinux | Strong best-effort | منطق RedHat-family |
| Rocky Linux | Strong best-effort | منطق RedHat-family |
| Fedora | Strong best-effort | منطق RedHat-family |
| CentOS / CentOS Stream | Best-effort | قد يحتاج ضبط repo حسب توفر PHP |
| Arch Linux | Best-effort | توجد family mapping؛ تحقق من أسماء الحزم في lab |
| Manjaro Linux | Best-effort | يستخدم منطق Arch-family |
| Alpine Linux | Best-effort | قد تتطلب فروق OpenRC والحزم بعض overrides |
| Gentoo | Best-effort | قد تتطلب فروق الحزم والخدمات بعض overrides |

### Reality Check

توفر وثائق LibreNMS upstream حاليًا أمثلة تثبيت لـ **Ubuntu 24.04** و **Ubuntu 22.04** و **Debian 12** و **Debian 13** و **CentOS 8**. هذا repo يذهب أبعد من ذلك عبر family mappings قابلة للـ override بسهولة، لكن يجب اختبار التوزيعات غير الأساسية في lab قبل الإنتاج.

راجع أيضًا:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## بنية المستودع / Repository Layout

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

## البدء السريع / Quick Start

1. انسخ المستودع وثبّت collections:

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

2. أنشئ secrets:

```bash
python3 scripts/generate-secrets.py > inventories/ha/group_vars/vault.yml
```

أو لـ standalone:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

3. اختر inventory:
- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha/hosts.yml`

4. املأ host IPs و SSH user و `librenms_fqdn` و `librenms_app_key` و DB / Redis / VRRP secrets و VIP details وإعدادات Gluster brick.

5. شغّل deployment:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

أو:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml
```

6. أكمل أول bootstrap لـ LibreNMS على `/install` ثم عيّن:

```yaml
librenms_bootstrap_completed: true
```

ثم أعد تشغيل نفس playbook.

---

## نموذج Inventory / Inventory Model

يستخدم هذا repo inventory groups بدل الافتراضات الثابتة.

- `librenms_nodes`: عقد التطبيق
- `librenms_primary`: عقدة واحدة لمهام primary post-bootstrap
- `librenms_web`: العقد التي تقدم Web UI
- `librenms_db`: عقد DB أو Galera
- `librenms_redis`: عقد Redis / Sentinel
- `lb_nodes`: عقد HAProxy / Keepalived
- `gluster_nodes`: عقد shared RRD storage
- `new_nodes`: العقد التي تتم إضافتها
- `decommission_nodes`: العقد التي تتم إزالتها

---

## أهم المتغيرات / Variables That Matter Most

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

## إضافة عقدة / Add a Node

أضف host إلى `librenms_nodes` وإلى `librenms_web` أو profile `librenms_poller`، ثم إلى `new_nodes`، واضبط `librenms_node_id` فريدًا، وبعد ذلك شغّل:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/add-node.yml
```

يعيد هذا playbook استخدام `site.yml` ليضبط host الجديد ويعيد مواءمة load balancer backends ويعيد توليد Redis / Galera / app configs عند الحاجة.

---

## إزالة عقدة / Remove a Node

أخرج host من active groups، وضعه في `decommission_nodes`، ثم شغّل:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/remove-node.yml
```

هذا يزامن cluster المتبقي مع inventory المحدث ويعطل أو ينظف الخدمات على العقدة التي تمت إزالتها.

> مهم
> إزالة storage node من Gluster-backed RRD layer لا تُعامل كعملية عادية. يتركها هذا repo عمدًا كخطوة تحتاج إلى operator review.

---

## دعم SNMP / SNMP Support

- `SNMPv1`: community-based ومفيد فقط عندما تحتاج إلى دعم hardware قديم.
- `SNMPv2c`: community-based وما زال شائعًا للأجهزة القديمة أو rollouts البسيطة.
- `SNMPv3`: موصى به متى ما كان مدعومًا؛ يمكن للـ repo ضبط `snmpd` وإنشاء SNMPv3 users وضبط SNMP version order بعد bootstrap.

---

## ملاحظات الأمان / Security Notes

- ضع secrets في `group_vars/vault.yml` وشفرها باستخدام **Ansible Vault**
- لا تقم بعمل commit لملفات vault الناتجة
- استخدم HTTPS أمام LibreNMS قبل أي public أو semi-public exposure
- تعامل مع Galera full-cluster recovery و Gluster membership changes على أنها operator tasks واضحة
- اختبر failover بانتظام

راجع:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## الحدود المعروفة / Known Boundaries

### أشياء مريحة للأتمتة
- package install
- repo checkout
- nginx / php-fpm config
- local MariaDB mode
- initial Galera join pattern
- Redis / Sentinel config
- HAProxy / Keepalived config
- LibreNMS app file deployment
- SNMP agent config
- إضافة أو إزالة application nodes

### أشياء تبقى لمراجعة المشغل
- Galera disaster bootstrap بعد total outage
- Gluster peer / brick recovery بعد failure كبير
- destructive node removal من storage cluster membership
- distro-specific package fixes على best-effort distros
- fine-tuning لـ SELinux hardening على RedHat-family systems

---

## التحقق / Verification

شغّل validation playbook:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml
```

أو لـ standalone:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

سيجري ذلك practical checks على LibreNMS validator و Galera status و Redis Sentinel state و Gluster volume status.

---

## التطوير / Development

شغّل lint محليًا:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## المساهمة / Contributing

طلبات السحب مرحب بها. اقرأ أولًا [CONTRIBUTING.md](../../CONTRIBUTING.md).

## الأمان / Security

اقرأ [SECURITY.md](../../SECURITY.md) لإرشادات الإبلاغ.

## الترخيص / License

MIT. راجع [LICENSE](../../LICENSE).
