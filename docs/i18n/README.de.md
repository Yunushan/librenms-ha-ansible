# LibreNMS HA Ansible Deployment

Produktionsorientierte Ansible-Automatisierung fuer **standalone-, distributed-polling- und full-HA**-Bereitstellungen von LibreNMS auf mehreren Linux-Familien.

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> Hinweis
> Das englische README ist die kanonische Version. Diese Datei ist eine vollstaendige Uebersetzung fuer einen einfacheren Einstieg. Wenn etwas voneinander abweicht, folge bitte [README.md](../../README.md).

## Warum Dieses Projekt Existiert / Why This Exists

LibreNMS laesst sich auf einem einzelnen Server leicht starten, aber der Betrieb wird schnell unuebersichtlich, sobald du eines oder mehrere der folgenden Dinge brauchst:

- mehrere LibreNMS-Web- oder Poller-Knoten
- Redis Sentinel
- Galera
- gemeinsam genutzten RRD-Speicher
- eine VIP vor Web UI und Datenbank-Load-Balancer
- reproduzierbare Wiederaufbauten nach einem Host-Ausfall
- ein einziges Repository, das sowohl standalone als auch HA abdeckt

Dieses Repository liefert dir ein einziges Ansible-Projekt, das Folgendes bereitstellen kann:

1. **Standalone-LibreNMS als All-in-One**
2. **LibreNMS mit verteilten Pollern und geteilten Diensten**
3. **Full-HA-LibreNMS** mit:
   - mehreren Web- oder Full-Knoten
   - MariaDB Galera
   - Redis Sentinel
   - HAProxy + Keepalived
   - GlusterFS-basiertem RRD-Speicher

---

## Was Du Bekommst / What You Get

- modulare Ansible-Rollen statt eines riesigen Shell-Skripts
- inventory-gesteuerte Topologieauswahl
- standalone- oder Cluster-Bereitstellungen aus demselben Projekt
- optionales Galera und optionales Redis Sentinel
- optionale VIP- und Load-Balancer-Ebene
- optionale Verwaltung des lokalen SNMP-Agenten
- Unterstuetzung fuer SNMP **v1**, **v2c** und **v3**
- Workflows zum **Hinzufuegen** und **Entfernen** von LibreNMS-Knoten
- eine GitHub-faehige Repo-Struktur mit MIT-Lizenz, Lint-Workflow, CONTRIBUTING- und SECURITY-Dokumenten, Beispiel-Inventories und Hilfsskript zur Secret-Erzeugung

---

## Topologie-Modi / Topology Modes

### 1) Standalone
Ein Host uebernimmt alles.

Gut fuer:
- Labore
- kleinere Umgebungen
- Single-Node-Produktivsysteme mit Backups

### 2) Cluster Ohne DB-Cluster
Mehrere LibreNMS-Knoten nutzen, aber gegen einen vorhandenen externen Stack fuer DB / Redis / Storage.

Gut fuer:
- Umgebungen mit verwaltetem MariaDB oder Redis
- Nutzer, die Poller-Skalierung wollen, ohne alle HA-Komponenten selbst zu hosten

### 3) Full HA
Verwende:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

Gut fuer:
- ernsthafte interne Monitoring-Plattformen
- Umgebungen, die Web- und Poller-Ueberlebensfaehigkeit brauchen
- Betreiber, die Galera-, Redis- und Gluster-Recovery bereits verstehen

> Wichtig
> Dieses Projekt automatisiert die Plattform sowie die LibreNMS-Datei- und Service-Struktur. Der erste App-Bootstrap bleibt absichtlich konservativ. Schliess den ersten Bootstrap ueber den Web-Installer ab und fuehre das Playbook danach mit `librenms_bootstrap_completed: true` erneut aus, damit die Post-Bootstrap-Einstellungen sauber angewendet werden.

---

## Support-Matrix / Support Matrix

Dieses Repository ist so gebaut, dass es die gewuenschten Distributionen unterstuetzt, allerdings in zwei Stufen:

| Distro | Stufe | Hinweise |
|---|---|---|
| Ubuntu | Primaer | Beste Passung zur offiziellen LibreNMS-Dokumentation |
| Debian | Primaer | Beste Passung zur offiziellen LibreNMS-Dokumentation |
| Linux Mint | Fast primaer | Nutzt Debian-Familienlogik |
| AlmaLinux | Starkes best-effort | RedHat-Familienlogik |
| Rocky Linux | Starkes best-effort | RedHat-Familienlogik |
| Fedora | Starkes best-effort | RedHat-Familienlogik |
| CentOS / CentOS Stream | Best-effort | Je nach PHP-Verfuegbarkeit kann Repo-Tuning noetig sein |
| Arch Linux | Best-effort | Familien-Mapping enthalten; Paketnamen im Labor pruefen |
| Manjaro Linux | Best-effort | Nutzt Arch-Familienlogik |
| Alpine Linux | Best-effort | OpenRC- und Paketunterschiede koennen Overrides noetig machen |
| Gentoo | Best-effort | Unterschiede bei Paketen und Diensten koennen Overrides noetig machen |

### Reality Check

Die offizielle LibreNMS-Dokumentation stellt derzeit Paket- und Installationsbeispiele fuer **Ubuntu 24.04**, **Ubuntu 22.04**, **Debian 12**, **Debian 13** und **CentOS 8** bereit. Dieses Repo geht mit override-freundlichen Familien-Mappings weiter, aber du solltest nicht-primaere Distros vor dem Produktionseinsatz im Labor testen.

Siehe auch:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Repository-Struktur / Repository Layout

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

## Schnellstart / Quick Start

### 1) Klonen und Collections installieren

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

### 2) Secrets erzeugen

```bash
python3 scripts/generate-secrets.py > inventories/ha-3node/group_vars/vault.yml
```

oder fuer standalone:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

### 3) Ein Inventory waehlen

- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha-3node/hosts.yml`

### 4) Inventory und Group Vars bearbeiten

Mindestens setzen:
- Host-IPs und SSH-Benutzer
- `librenms_fqdn`
- `librenms_app_key`
- DB / Redis / VRRP-Secrets
- VIP-Details fuer HA
- Gluster-Brick-Einstellungen fuer HA

### 5) Deployment ausfuehren

Standalone:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

HA / Cluster:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/cluster.yml
```

### 6) Den ersten LibreNMS-Bootstrap abschliessen

Oeffne die Site und schliesse den ersten App-Bootstrap ab:

```text
http://librenms.example.com/install
```

oder bei standalone:

```text
http://<your-hostname-or-ip>/install
```

Setze danach:

```yaml
librenms_bootstrap_completed: true
```

und fuehre dasselbe Playbook erneut aus. Dadurch werden die Post-Bootstrap-Tasks `lnms config:set` sauber aktiviert.

---

## Inventory-Modell / Inventory Model

Dieses Repo verwendet Inventory-Gruppen statt fest verdrahteter Annahmen.

### Kern-Gruppen

- `librenms_nodes` - Applikationsknoten
- `librenms_primary` - ein Knoten fuer primaere Post-Bootstrap-Konfigurationsaufgaben
- `librenms_web` - Knoten fuer die Web UI
- `librenms_db` - DB- oder Galera-Knoten
- `librenms_redis` - Redis- / Sentinel-Knoten
- `lb_nodes` - HAProxy- / Keepalived-Knoten
- `gluster_nodes` - Knoten fuer gemeinsamen RRD-Speicher

### Lifecycle-Gruppen

- `new_nodes` - Knoten, die du hinzufuegst
- `decommission_nodes` - Knoten, die entfernt werden

---

## Wichtige Variablen / Variables That Matter Most

### Installationsmodus

```yaml
librenms_mode: standalone           # standalone | cluster | ha
librenms_install_profile: full      # full | web | poller
```

### Datenbankmodus

```yaml
librenms_db_mode: local             # local | external | galera
librenms_db_host: ""
librenms_db_name: librenms
librenms_db_user: librenms
librenms_db_password: CHANGE_ME
```

### Redis-Modus

```yaml
librenms_redis_mode: local          # local | external | sentinel
librenms_redis_password: CHANGE_ME
librenms_redis_sentinel_password: CHANGE_ME
librenms_redis_master_host: lnms1
```

### RRD-Speichermodus

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

## Einen Knoten Hinzufuegen / Add a Node

### Einen neuen LibreNMS-Applikationsknoten hinzufuegen

1. Fuege den Host zu `librenms_nodes`, `librenms_web` oder einer `librenms_poller`-artigen Nutzung ueber `librenms_install_profile` hinzu und setze ihn in `new_nodes`.
2. Gib ihm eine eindeutige `librenms_node_id`.
3. Fuehre erneut aus:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/add-node.yml
```

Das Playbook verwendet `site.yml` wieder, richtet den neuen Host ein, gleicht Load-Balancer-Backends ab und rendert Redis-, Galera- und App-Konfigurationen bei Bedarf neu.

> Tipp
> Fuer einen **Web-/Poller-Knoten** ist das der sicherste Skalierungspfad.
> Fuer **Galera**-, **Redis**- oder **Gluster**-Membership-Aenderungen teste den Ablauf zuerst im Labor und lies [docs/architecture.md](../../docs/architecture.md). Aenderungen an der Storage-Membership sind absichtlich konservativer als Aenderungen an Web-Knoten.

---

## Einen Knoten Entfernen / Remove a Node

1. Verschiebe den Host aus den aktiven Gruppen (`librenms_nodes`, `librenms_web`, `librenms_db`, `librenms_redis`, `lb_nodes`, `gluster_nodes`).
2. Fuege ihn `decommission_nodes` hinzu.
3. Fuehre aus:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/remove-node.yml
```

Das gleicht den verbleibenden Cluster mit dem aktualisierten Inventory ab und deaktiviert oder bereinigt optional Dienste auf dem entfernten Knoten.

> Wichtig
> Das Entfernen eines Storage-Knotens aus einer Gluster-basierten RRD-Schicht gilt nicht als Routineeingriff. Das Repo laesst diesen Workflow bewusst zur Betreiber-Pruefung.

---

## SNMP-Unterstuetzung / SNMP Support

Dieses Repo unterstuetzt drei SNMP-Modi:

### SNMPv1
Community-basiert. Nur sinnvoll, wenn du Legacy-Hardware unterstuetzen musst.

### SNMPv2c
Community-basiert und noch immer haeufig fuer aeltere Geraete oder einfache Rollouts.

### SNMPv3
Empfohlen, wenn die Geraete es unterstuetzen. Dieses Repo kann lokales `snmpd` konfigurieren, SNMPv3-Benutzer anlegen und die SNMP-Versionsreihenfolge in LibreNMS nach dem Bootstrap setzen.

> Hinweis
> Auf der Seite des lokalen Agenten verwenden SNMPv1 und SNMPv2c beide community-basierte Agent-Konfiguration. Der Unterschied ist vor allem relevant, wenn LibreNMS mit ueberwachten Geraeten spricht.

---

## Sicherheitshinweise / Security Notes

- Lege Secrets in `group_vars/vault.yml` ab und verschluessle sie mit **Ansible Vault**
- Committe keine generierten Vault-Dateien
- Nutze HTTPS vor LibreNMS, bevor du es oeffentlich oder halb-oeffentlich exponierst
- Behandle Galera-Gesamtrecovery und Gluster-Membership-Aenderungen als explizite Betreiberaufgaben
- Teste Failover regelmaessig

Siehe:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Bekannte Grenzen / Known Boundaries

Dieses Projekt ist absichtlich ehrlich bei den schwierigen Teilen.

### Voll komfortabel zu automatisieren
- Paketinstallation
- Repo-Checkout
- nginx- / php-fpm-Konfiguration
- MariaDB-Lokalmodus
- initiales Galera-Join-Muster
- Redis- / Sentinel-Konfiguration
- HAProxy- / Keepalived-Konfiguration
- Bereitstellung der LibreNMS-App-Dateien
- SNMP-Agent-Konfiguration
- Applikationsknoten hinzufuegen oder entfernen

### Bewusst mit Betreiber-Pruefung
- Galera-Disaster-Bootstrap nach Totalausfall
- Gluster-Peer- / Brick-Recovery nach schwerem Fehler
- destruktives Entfernen von Knoten aus dem Storage-Cluster
- distro-spezifische Paketkorrekturen auf best-effort-Distros
- SELinux-Hardening-Feinabstimmung auf RedHat-Systemfamilien

---

## Verifizierung / Verification

Fuehre das Validierungs-Playbook aus:

```bash
ansible-playbook -i inventories/ha-3node/hosts.yml playbooks/validate.yml
```

oder fuer standalone:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

Es fuehrt praktische Pruefungen gegen den LibreNMS-Validator, den Galera-Status, den Redis-Sentinel-Status und den Gluster-Volume-Status aus.

---

## Entwicklung / Development

Lint lokal ausfuehren:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Mitwirken / Contributing

Pull Requests sind willkommen. Bitte lies zuerst [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Sicherheit / Security

Bitte lies [SECURITY.md](../../SECURITY.md) fuer Hinweise zum Melden von Problemen.

## Lizenz / License

MIT. Siehe [LICENSE](../../LICENSE).
