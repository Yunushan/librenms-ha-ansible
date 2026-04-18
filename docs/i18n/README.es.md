# LibreNMS HA Ansible Deployment

Automatizacion con Ansible pensada para produccion para despliegues **standalone, distributed polling y full HA** de LibreNMS en varias familias Linux.

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> Nota
> El README en ingles es la version canonica. Este archivo es una traduccion completa para facilitar el onboarding. Si encuentras alguna diferencia, sigue [README.md](../../README.md).

## Por Que Existe / Why This Exists

LibreNMS es facil de poner en marcha en un solo servidor, pero se vuelve operacionalmente desordenado en cuanto necesitas una o varias de estas cosas:

- varios nodos web o poller de LibreNMS
- Redis Sentinel
- Galera
- almacenamiento RRD compartido
- un VIP delante de la Web UI y del balanceador de base de datos
- reconstrucciones repetibles despues de una caida de host
- un solo repositorio capaz de cubrir standalone y HA

Este repositorio te da un unico proyecto Ansible capaz de desplegar:

1. **LibreNMS standalone todo en uno**
2. **LibreNMS con distributed pollers y servicios compartidos**
3. **LibreNMS full HA** con:
   - varios nodos web o full
   - MariaDB Galera
   - Redis Sentinel
   - HAProxy + Keepalived
   - almacenamiento RRD sobre GlusterFS

---

## Lo Que Obtienes / What You Get

- roles modulares de Ansible en lugar de un unico script gigante
- seleccion de topologia guiada por inventory
- despliegues standalone o cluster desde el mismo proyecto
- Galera opcional y Redis Sentinel opcional
- capa opcional de VIP y balanceador
- gestion opcional del agente SNMP local
- soporte para SNMP **v1**, **v2c** y **v3**
- flujos para **agregar** y **eliminar** nodos LibreNMS
- estructura lista para GitHub con:
  - licencia MIT
  - workflow de lint
  - documentos CONTRIBUTING y SECURITY
  - inventories de ejemplo
  - generador auxiliar de secretos

---

## Modos de Topologia / Topology Modes

### 1) Standalone
Usa un solo host para todo.

Bueno para:
- labs
- entornos pequenos
- produccion de un solo nodo con copias de seguridad

### 2) Cluster Sin Cluster de BD
Usa varios nodos LibreNMS, pero apuntando a una pila externa existente de DB / Redis / almacenamiento.

Bueno para:
- entornos con MariaDB o Redis gestionados
- usuarios que quieren escalar pollers sin alojar internamente todos los componentes HA

### 3) Full HA
Usa:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

Bueno para:
- plataformas internas serias de monitorizacion
- entornos que necesitan supervivencia del web y de los pollers
- operadores que ya entienden la recuperacion de Galera / Redis / Gluster

> Importante
> Este proyecto automatiza la plataforma y la distribucion de archivos y servicios de LibreNMS. El bootstrap inicial de la aplicacion sigue siendo intencionadamente conservador. Completa primero el bootstrap inicial con el instalador web y luego vuelve a ejecutar el playbook con `librenms_bootstrap_completed: true` para aplicar de forma limpia la configuracion posterior al bootstrap.

---

## Matriz de Soporte / Support Matrix

Este repositorio esta construido para soportar las distribuciones que pediste, pero lo hace en dos niveles:

| Distro | Nivel | Notas |
|---|---|---|
| Ubuntu | Primario | Mejor encaje con la documentacion oficial de LibreNMS |
| Debian | Primario | Mejor encaje con la documentacion oficial de LibreNMS |
| Linux Mint | Casi primario | Usa logica de la familia Debian |
| AlmaLinux | Fuerte best-effort | Logica de la familia RedHat |
| Rocky Linux | Fuerte best-effort | Logica de la familia RedHat |
| Fedora | Fuerte best-effort | Logica de la familia RedHat |
| CentOS / CentOS Stream | Best-effort | Puede requerir ajuste de repos segun la disponibilidad de PHP |
| Arch Linux | Best-effort | Mapeo de familia incluido; verifica nombres de paquetes en laboratorio |
| Manjaro Linux | Best-effort | Usa logica de la familia Arch |
| Alpine Linux | Best-effort | Las diferencias de OpenRC y paquetes pueden requerir overrides |
| Gentoo | Best-effort | Las diferencias de paquetes y servicios pueden requerir overrides |

### Reality Check

La documentacion oficial de LibreNMS hoy publica ejemplos de paquete e instalacion para **Ubuntu 24.04**, **Ubuntu 22.04**, **Debian 12**, **Debian 13** y **CentOS 8**. Este repo va mas alla con mapeos por familia y faciles de sobreescribir, pero debes probar en laboratorio los distros no primarios antes de llevarlos a produccion.

Vease tambien:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Estructura del Repositorio / Repository Layout

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

## Inicio Rapido / Quick Start

### 1) Clona e instala las colecciones

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

### 2) Genera secretos

```bash
python3 scripts/generate-secrets.py > inventories/ha-3node/group_vars/vault.yml
```

o para standalone:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

### 3) Elige un inventory

- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha-3node/hosts.yml`

### 4) Edita el inventory y los group vars

Como minimo, define:

- IPs de hosts y usuario SSH
- `librenms_fqdn`
- `librenms_app_key`
- secretos de DB / Redis / VRRP
- detalles del VIP para HA
- configuracion de bricks de Gluster para HA

### 5) Ejecuta el despliegue

Standalone:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

HA / cluster:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/cluster.yml
```

### 6) Completa el primer bootstrap de LibreNMS

Abre el sitio y completa el primer bootstrap de la aplicacion:

```text
http://librenms.example.com/install
```

o en standalone:

```text
http://<your-hostname-or-ip>/install
```

Despues define:

```yaml
librenms_bootstrap_completed: true
```

y vuelve a ejecutar el mismo playbook. Esto habilita limpiamente las tareas `lnms config:set` posteriores al bootstrap.

---

## Modelo de Inventory / Inventory Model

Este repo usa grupos de inventory en lugar de supuestos codificados.

### Grupos principales

- `librenms_nodes` - nodos de aplicacion
- `librenms_primary` - un nodo usado para tareas principales de configuracion post-bootstrap
- `librenms_web` - nodos que sirven la Web UI
- `librenms_db` - nodos DB o Galera
- `librenms_redis` - nodos Redis / Sentinel
- `lb_nodes` - nodos HAProxy / Keepalived
- `gluster_nodes` - nodos de almacenamiento RRD compartido

### Grupos de ciclo de vida

- `new_nodes` - nodos que estas agregando
- `decommission_nodes` - nodos que se van a retirar

---

## Variables Mas Importantes / Variables That Matter Most

### Modo de instalacion

```yaml
librenms_mode: standalone           # standalone | cluster | ha
librenms_install_profile: full      # full | web | poller
```

### Modo de base de datos

```yaml
librenms_db_mode: local             # local | external | galera
librenms_db_host: ""
librenms_db_name: librenms
librenms_db_user: librenms
librenms_db_password: CHANGE_ME
```

### Modo Redis

```yaml
librenms_redis_mode: local          # local | external | sentinel
librenms_redis_password: CHANGE_ME
librenms_redis_sentinel_password: CHANGE_ME
librenms_redis_master_host: lnms1
```

### Modo de almacenamiento RRD

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

## Agregar Un Nodo / Add a Node

### Agregar un nuevo nodo de aplicacion LibreNMS

1. Agrega el host a:
   - `librenms_nodes`
   - `librenms_web` o a un uso tipo `librenms_poller` mediante `librenms_install_profile`
   - `new_nodes`
2. Dale un `librenms_node_id` unico
3. Vuelve a ejecutar:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/add-node.yml
```

El playbook reutiliza `site.yml`, que:
- configura el nuevo host
- reconcilia los backends del balanceador
- vuelve a renderizar configs de Redis / Galera / app donde haga falta

> Consejo
> Para un **nodo web/poller**, esta es la ruta de escalado mas segura.
> Para cambios de membresia en **Galera**, **Redis** o **Gluster**, prueba primero el flujo en laboratorio y lee [docs/architecture.md](../../docs/architecture.md). Los cambios de membresia en almacenamiento son intencionadamente mas conservadores que los cambios de nodos web.

---

## Eliminar Un Nodo / Remove a Node

1. Saca el host de los grupos activos (`librenms_nodes`, `librenms_web`, `librenms_db`, `librenms_redis`, `lb_nodes`, `gluster_nodes`)
2. Ponlo en `decommission_nodes`
3. Ejecuta:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/remove-node.yml
```

Esto hace dos cosas:
- reconcilia el cluster superviviente con el inventory actualizado
- desactiva y opcionalmente limpia servicios en el nodo retirado

> Importante
> Retirar un nodo de almacenamiento de una capa RRD respaldada por Gluster no se trata como una operacion casual. El repo lo deja a proposito como un flujo revisado por el operador.

---

## Soporte SNMP / SNMP Support

Este repo soporta tres modos SNMP:

### SNMPv1
Basado en community. Util solo cuando debes soportar hardware heredado.

### SNMPv2c
Basado en community y aun comun para dispositivos antiguos o despliegues simples.

### SNMPv3
Recomendado donde los dispositivos lo soportan. Este repo puede:
- configurar `snmpd` local
- crear usuarios SNMPv3
- definir el orden de versiones SNMP de LibreNMS despues del bootstrap

> Nota
> En el lado del agente local, SNMPv1 y SNMPv2c usan configuracion basada en community. La diferencia importa sobre todo cuando LibreNMS habla con los dispositivos monitorizados.

---

## Notas De Seguridad / Security Notes

- Pon los secretos en `group_vars/vault.yml` y cifralos con **Ansible Vault**
- No hagas commit de archivos vault generados
- Usa HTTPS delante de LibreNMS antes de exponerlo en entornos publicos o semipublicos
- Trata la recuperacion completa de Galera y los cambios de membresia de Gluster como tareas explicitas del operador
- Prueba el failover con regularidad

Vease:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Limites Conocidos / Known Boundaries

Este proyecto es intencionadamente honesto sobre las partes dificiles.

### Totalmente comodo de automatizar
- instalacion de paquetes
- checkout del repo
- configuracion de nginx / php-fpm
- modo local de MariaDB
- patron inicial de union de nodos Galera
- configuracion de Redis / Sentinel
- configuracion de HAProxy / Keepalived
- despliegue de archivos de la app LibreNMS
- configuracion del agente SNMP
- agregar/eliminar nodos **de aplicacion**

### Revisado por el operador por diseno
- bootstrap de desastre de Galera tras una caida total
- recuperacion de peers / bricks de Gluster despues de un fallo grave
- eliminacion destructiva de nodos de la membresia del cluster de almacenamiento
- correcciones de paquetes especificas por distro en distros best-effort
- ajuste fino de hardening SELinux en sistemas de la familia RedHat

---

## Verificacion / Verification

Ejecuta el playbook de validacion:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/validate.yml
```

o para standalone:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

Ejecuta un conjunto practico de comprobaciones sobre:
- validador de LibreNMS
- estado de Galera
- estado de Redis Sentinel
- estado del volumen Gluster

---

## Desarrollo / Development

Haz lint localmente:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Contribuir / Contributing

Los pull requests son bienvenidos. Lee primero [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Seguridad / Security

Lee [SECURITY.md](../../SECURITY.md) para la guia de reporte.

## Licencia / License

MIT. Vease [LICENSE](../../LICENSE).
