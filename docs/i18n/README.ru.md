# LibreNMS HA Ansible Deployment

Продуманная для production автоматизация Ansible для развертывания LibreNMS в режимах **standalone, distributed polling и full HA** на нескольких семействах Linux.

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> Примечание
> Английский README является канонической версией. Этот файл представляет собой полную переведенную копию для удобного старта. Если есть расхождения, ориентируйтесь на [README.md](../../README.md).

## Зачем Нужен Этот Проект / Why This Exists

LibreNMS легко поднять на одном сервере, но эксплуатация быстро усложняется, когда вам нужно одно или несколько из следующего:

- несколько web- или poller-узлов LibreNMS
- Redis Sentinel
- Galera
- общий RRD storage
- VIP перед Web UI и балансировщиком базы данных
- повторяемое восстановление после отказа хоста
- один репозиторий для standalone и HA

Этот репозиторий дает единый Ansible-проект, который может развернуть:

1. **Standalone all-in-one LibreNMS**
2. **LibreNMS с distributed pollers и общими сервисами**
3. **Full HA LibreNMS** с MariaDB Galera, Redis Sentinel, HAProxy + Keepalived и GlusterFS-backed RRD storage.

---

## Что Вы Получаете / What You Get

- модульные роли Ansible вместо одного огромного shell script
- выбор топологии через inventory
- standalone и cluster deployment из одного проекта
- опциональные Galera и Redis Sentinel
- опциональный слой VIP и load balancer
- опциональное управление локальным SNMP agent
- поддержка SNMP **v1**, **v2c** и **v3**
- workflow для добавления и удаления LibreNMS узлов
- GitHub-ready структура с MIT license, lint workflow, CONTRIBUTING, SECURITY, example inventories и генератором секретов

---

## Режимы Топологии / Topology Modes

### 1) Standalone
Один host делает все.

Подходит для labs, небольших окружений и single-node production с backup.

### 2) Cluster Без DB Cluster
Несколько LibreNMS nodes используют существующий внешний стек DB / Redis / storage.

Подходит для managed MariaDB или Redis и для тех, кому нужна poller scale without self-hosting every HA component.

### 3) Full HA
Используйте:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

Подходит для серьезных внутренних monitoring platforms и операторов, которые понимают recovery для Galera / Redis / Gluster.

> Важно
> Этот проект автоматизирует платформу и layout файлов и сервисов LibreNMS. Первичный bootstrap приложения намеренно оставлен консервативным. Сначала завершите первый bootstrap через web installer, затем повторно запустите playbook с `librenms_bootstrap_completed: true`, чтобы чисто применить post-bootstrap настройки.

---

## Матрица Поддержки / Support Matrix

Репозиторий рассчитан на поддержку нужных вам дистрибутивов, но делает это в двух уровнях:

| Distro | Уровень | Примечания |
|---|---|---|
| Ubuntu | Основной | Лучшее совпадение с upstream LibreNMS docs |
| Debian | Основной | Лучшее совпадение с upstream LibreNMS docs |
| Linux Mint | Почти основной | Использует Debian-family logic |
| AlmaLinux | Сильный best-effort | RedHat-family logic |
| Rocky Linux | Сильный best-effort | RedHat-family logic |
| Fedora | Сильный best-effort | RedHat-family logic |
| CentOS / CentOS Stream | Best-effort | Может потребоваться настройка репозиториев из-за доступности PHP |
| Arch Linux | Best-effort | Есть family mapping; проверьте package names в lab |
| Manjaro Linux | Best-effort | Использует Arch-family logic |
| Alpine Linux | Best-effort | Различия OpenRC и пакетов могут потребовать overrides |
| Gentoo | Best-effort | Различия пакетов и сервисов могут потребовать overrides |

### Reality Check

Upstream LibreNMS docs сейчас дают package/install examples для **Ubuntu 24.04**, **Ubuntu 22.04**, **Debian 12**, **Debian 13** и **CentOS 8**. Этот repo идет дальше за счет override-friendly family mappings, но non-primary distros стоит проверить в lab до production.

См. также:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Структура Репозитория / Repository Layout

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

## Быстрый Старт / Quick Start

1. Клонируйте репозиторий и установите collections:

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

2. Сгенерируйте secrets:

```bash
python3 scripts/generate-secrets.py > inventories/ha-3node/group_vars/vault.yml
```

или для standalone:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

3. Выберите inventory:
- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha-3node/hosts.yml`

4. Заполните host IPs, SSH user, `librenms_fqdn`, `librenms_app_key`, DB / Redis / VRRP secrets, VIP details и Gluster brick settings.

5. Запустите deployment:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

или:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/cluster.yml
```

6. Завершите первый LibreNMS bootstrap на `/install`, затем задайте:

```yaml
librenms_bootstrap_completed: true
```

и повторно запустите тот же playbook.

---

## Модель Inventory / Inventory Model

Репозиторий использует inventory groups вместо жестко зашитых предположений.

- `librenms_nodes`: application nodes
- `librenms_primary`: один узел для primary post-bootstrap tasks
- `librenms_web`: узлы, отдающие Web UI
- `librenms_db`: DB или Galera nodes
- `librenms_redis`: Redis / Sentinel nodes
- `lb_nodes`: HAProxy / Keepalived nodes
- `gluster_nodes`: shared RRD storage nodes
- `new_nodes`: добавляемые узлы
- `decommission_nodes`: удаляемые узлы

---

## Самые Важные Переменные / Variables That Matter Most

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

## Добавление Узла / Add a Node

Добавьте host в `librenms_nodes`, в `librenms_web` или профиль `librenms_poller`, включите его в `new_nodes`, задайте уникальный `librenms_node_id` и выполните:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/add-node.yml
```

Playbook повторно использует `site.yml`, настраивает новый host, пересобирает load balancer backends и обновляет Redis / Galera / app configs где это нужно.

> Совет
> Для web/poller node это самый безопасный путь масштабирования. Для membership changes в Galera, Redis или Gluster сначала проверьте workflow в lab и прочитайте [docs/architecture.md](../../docs/architecture.md).

---

## Удаление Узла / Remove a Node

Выведите host из активных групп, поместите его в `decommission_nodes` и выполните:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/remove-node.yml
```

Это синхронизирует оставшийся cluster с обновленным inventory и отключит или очистит сервисы на удаляемом узле.

> Важно
> Удаление storage node из Gluster-backed RRD layer не считается простой операцией. Репозиторий оставляет этот workflow под контролем оператора.

---

## Поддержка SNMP / SNMP Support

- `SNMPv1`: community-based, полезен только для legacy hardware.
- `SNMPv2c`: community-based и все еще распространен для старых устройств и простых rollout.
- `SNMPv3`: рекомендуется там, где устройство поддерживает его; репозиторий умеет настраивать `snmpd`, создавать SNMPv3 users и задавать порядок SNMP versions после bootstrap.

---

## Заметки По Безопасности / Security Notes

- Храните secrets в `group_vars/vault.yml` и шифруйте их через **Ansible Vault**
- Не коммитьте сгенерированные vault files
- Используйте HTTPS перед LibreNMS до public или semi-public exposure
- Считайте full-cluster recovery для Galera и membership changes для Gluster отдельными operator tasks
- Регулярно проверяйте failover

См.:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Известные Ограничения / Known Boundaries

### Комфортно автоматизируется
- package install
- repo checkout
- nginx / php-fpm config
- local MariaDB mode
- initial Galera join pattern
- Redis / Sentinel config
- HAProxy / Keepalived config
- LibreNMS app file deployment
- SNMP agent config
- добавление и удаление application nodes

### Оставлено на review оператора
- Galera disaster bootstrap после total outage
- Gluster peer / brick recovery после серьезного сбоя
- destructive node removal из storage cluster membership
- distro-specific package fixes на best-effort distros
- тонкая настройка SELinux hardening на RedHat-family systems

---

## Проверка / Verification

Запустите validation playbook:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/validate.yml
```

или для standalone:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

Он выполняет practical checks для LibreNMS validator, Galera status, Redis Sentinel state и Gluster volume status.

---

## Разработка / Development

Запускайте lint локально:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Участие / Contributing

Pull requests приветствуются. Сначала прочитайте [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Безопасность / Security

Прочитайте [SECURITY.md](../../SECURITY.md) для инструкций по reporting.

## Лицензия / License

MIT. См. [LICENSE](../../LICENSE).
