# LibreNMS HA Ansible Deployment

Automatisation Ansible pensee pour la production pour des deploiements **standalone, distributed polling et full HA** de LibreNMS sur plusieurs familles Linux.

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> Note
> Le README anglais est la version canonique. Ce fichier est une traduction complete pour faciliter la prise en main. En cas de difference, suivez [README.md](../../README.md).

## Network and Access Matrix

For the exact controller-to-node ports, cluster east-west traffic, and sudo requirements, see the canonical English section [Network and Access Matrix](../../README.md#network-and-access-matrix).

## Pourquoi Ce Projet Existe / Why This Exists

LibreNMS est simple a lancer sur un seul serveur, mais l'exploitation devient vite compliquee des que vous avez besoin d'un ou plusieurs des elements suivants:

- plusieurs noeuds web ou poller LibreNMS
- Redis Sentinel
- Galera
- un stockage RRD partage
- une VIP devant la Web UI et le load balancer de base de donnees
- des reconstructions repetables apres une panne d'hote
- un seul depot capable de couvrir standalone et HA

Ce depot vous fournit un projet Ansible unique capable de deployer:

1. **LibreNMS standalone tout-en-un**
2. **LibreNMS a pollers distribues avec services partages**
3. **LibreNMS full HA** avec:
   - plusieurs noeuds web ou full
   - MariaDB Galera
   - Redis Sentinel
   - HAProxy + Keepalived
   - stockage RRD adosse a GlusterFS

---

## Ce Que Vous Obtenez / What You Get

- des roles Ansible modulaires au lieu d'un seul script geant
- une selection de topologie pilotee par l'inventory
- des deploiements standalone ou cluster depuis le meme projet
- Galera optionnel et Redis Sentinel optionnel
- une couche optionnelle VIP et load balancer
- une gestion optionnelle de l'agent SNMP local
- le support SNMP **v1**, **v2c** et **v3**
- des workflows pour **ajouter** et **retirer** des noeuds LibreNMS
- une structure de depot prete pour GitHub avec licence MIT, workflow de lint, documents CONTRIBUTING et SECURITY, inventories d'exemple et generateur de secrets

---

## Modes De Topologie / Topology Modes

### 1) Standalone
Utilisez un seul hote pour tout.

Adapte a:
- laboratoires
- petits environnements
- production mono-noeud avec sauvegardes

### 2) Cluster Sans Cluster De Base De Donnees
Utilisez plusieurs noeuds LibreNMS, mais pointez-les vers une pile externe existante pour DB / Redis / stockage.

Adapte a:
- environnements avec MariaDB ou Redis manages
- utilisateurs qui veulent faire monter les pollers en charge sans heberger eux-memes tous les composants HA

### 3) Full HA
Utilisez:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

Adapte a:
- plateformes internes de supervision serieuses
- environnements qui ont besoin de survie du web et des pollers
- operateurs qui connaissent deja la reprise Galera / Redis / Gluster

> Important
> Ce projet automatise la plateforme ainsi que l'organisation des fichiers et des services LibreNMS. L'amorcage initial de l'application reste volontairement conservateur. Terminez d'abord le premier bootstrap avec l'installateur web, puis relancez le playbook avec `librenms_bootstrap_completed: true` pour appliquer proprement les reglages post-bootstrap.

---

## Matrice De Support / Support Matrix

Ce depot est construit pour prendre en charge les distributions demandees, mais il le fait en deux niveaux:

| Distro | Niveau | Notes |
|---|---|---|
| Ubuntu | Primaire | Meilleur alignement avec la documentation officielle LibreNMS |
| Debian | Primaire | Meilleur alignement avec la documentation officielle LibreNMS |
| Linux Mint | Presque primaire | Utilise la logique de la famille Debian |
| AlmaLinux | Fort best-effort | Logique de la famille RedHat |
| Rocky Linux | Fort best-effort | Logique de la famille RedHat |
| Fedora | Fort best-effort | Logique de la famille RedHat |
| CentOS / CentOS Stream | Best-effort | Peut necessiter un ajustement de depots selon la disponibilite de PHP |
| Arch Linux | Best-effort | Mapping de famille inclus; verifiez les noms de paquets en labo |
| Manjaro Linux | Best-effort | Utilise la logique de la famille Arch |
| Alpine Linux | Best-effort | Les differences OpenRC / paquets peuvent demander des overrides |
| Gentoo | Best-effort | Les differences de paquets et services peuvent demander des overrides |

### Reality Check

La documentation amont de LibreNMS fournit aujourd'hui des exemples de paquets et d'installation pour **Ubuntu 24.04**, **Ubuntu 22.04**, **Debian 12**, **Debian 13** et **CentOS 8**. Ce depot va au-dela grace a des mappings par famille faciles a surcharger, mais il faut tester en laboratoire les distros non primaires avant la production.

Voir aussi:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Structure Du Depot / Repository Layout

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

## Demarrage Rapide / Quick Start

### 1) Cloner et installer les collections

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

### 2) Generer les secrets

```bash
python3 scripts/generate-secrets.py > inventories/ha/group_vars/vault.yml
```

ou pour standalone:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

### 3) Choisir un inventory

- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha/hosts.yml`

### 4) Modifier l'inventory et les group vars

Au minimum, renseignez:
- les IP des hotes et l'utilisateur SSH
- `librenms_fqdn`
- `librenms_app_key`
- les secrets DB / Redis / VRRP
- les details de VIP pour HA
- les reglages de bricks Gluster pour HA

### 5) Lancer le deploiement

Standalone:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

HA / cluster:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml
```

### 6) Terminer le premier bootstrap LibreNMS

Ouvrez le site et terminez le premier bootstrap applicatif:

```text
http://librenms.example.com/install
```

ou en standalone:

```text
http://<your-hostname-or-ip>/install
```

Ensuite, definissez:

```yaml
librenms_bootstrap_completed: true
```

puis relancez le meme playbook. Cela active proprement les taches post-bootstrap `lnms config:set`.

---

## Modele D'Inventory / Inventory Model

Ce depot utilise des groupes d'inventory plutot que des hypotheses codees en dur.

### Groupes principaux

- `librenms_nodes` - noeuds applicatifs
- `librenms_primary` - un noeud utilise pour les taches principales de configuration post-bootstrap
- `librenms_web` - noeuds servant la Web UI
- `librenms_db` - noeuds DB ou Galera
- `librenms_redis` - noeuds Redis / Sentinel
- `lb_nodes` - noeuds HAProxy / Keepalived
- `gluster_nodes` - noeuds de stockage RRD partage

### Groupes de cycle de vie

- `new_nodes` - noeuds que vous ajoutez
- `decommission_nodes` - noeuds en cours de retrait

---

## Variables Importantes / Variables That Matter Most

### Mode d'installation

```yaml
librenms_mode: standalone           # standalone | cluster | ha
librenms_install_profile: full      # full | web | poller
```

### Mode base de donnees

```yaml
librenms_db_mode: local             # local | external | galera
librenms_db_host: ""
librenms_db_name: librenms
librenms_db_user: librenms
librenms_db_password: CHANGE_ME
```

### Mode Redis

```yaml
librenms_redis_mode: local          # local | external | sentinel
librenms_redis_password: CHANGE_ME
librenms_redis_sentinel_password: CHANGE_ME
librenms_redis_master_host: lnms1
```

### Mode stockage RRD

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

## Ajouter Un Noeud / Add a Node

### Ajouter un nouveau noeud applicatif LibreNMS

1. Ajoutez l'hote a `librenms_nodes`, a `librenms_web` ou a un usage `librenms_poller` via `librenms_install_profile`, puis a `new_nodes`.
2. Donnez-lui un `librenms_node_id` unique.
3. Relancez:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/add-node.yml
```

Le playbook reutilise `site.yml`, qui configure le nouvel hote, reconcilie les backends du load balancer et re-genere les configs Redis / Galera / app la ou necessaire.

> Conseil
> Pour un **noeud web/poller**, c'est la voie de mise a l'echelle la plus sure.
> Pour un changement de membership **Galera**, **Redis** ou **Gluster**, testez d'abord le workflow en laboratoire et lisez [docs/architecture.md](../../docs/architecture.md). Les changements de membership de stockage sont volontairement plus conservateurs que les changements de noeuds web.

---

## Retirer Un Noeud / Remove a Node

1. Retirez l'hote des groupes actifs (`librenms_nodes`, `librenms_web`, `librenms_db`, `librenms_redis`, `lb_nodes`, `gluster_nodes`).
2. Placez-le dans `decommission_nodes`.
3. Lancez:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/remove-node.yml
```

Cela reconcilie le cluster survivant avec l'inventory mis a jour et desactive ou nettoie eventuellement les services sur le noeud retire.

> Important
> Retirer un noeud de stockage d'une couche RRD basee sur Gluster n'est pas traite comme une operation banale. Le depot laisse volontairement ce workflow a une revue operateur.

---

## Support SNMP / SNMP Support

Ce depot prend en charge trois modes SNMP:

### SNMPv1
Base sur community. Utile seulement quand vous devez prendre en charge du materiel ancien.

### SNMPv2c
Base sur community et encore courant pour les appareils plus anciens ou les deploiements simples.

### SNMPv3
Recommande quand les equipements le supportent. Ce depot peut configurer `snmpd` local, creer des utilisateurs SNMPv3 et definir l'ordre des versions SNMP LibreNMS apres bootstrap.

> Note
> Cote agent local, SNMPv1 et SNMPv2c utilisent tous deux une configuration basee sur community. La difference compte surtout quand LibreNMS dialogue avec les equipements surveilles.

---

## Notes De Securite / Security Notes

- Placez les secrets dans `group_vars/vault.yml` et chiffrez-les avec **Ansible Vault**
- Ne committez pas les fichiers vault generes
- Utilisez HTTPS devant LibreNMS avant toute exposition publique ou semi-publique
- Traitez la reprise totale Galera et les changements de membership Gluster comme des taches explicites d'operateur
- Testez regulierement le failover

Voir:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Limites Connues / Known Boundaries

Ce projet est volontairement honnete sur les parties difficiles.

### Entierement a l'aise pour automatiser
- installation des paquets
- checkout du depot
- configuration nginx / php-fpm
- mode local MariaDB
- schema initial de jonction des noeuds Galera
- configuration Redis / Sentinel
- configuration HAProxy / Keepalived
- deploiement des fichiers applicatifs LibreNMS
- configuration de l'agent SNMP
- ajout ou suppression des noeuds **applicatifs**

### Revu par l'operateur par conception
- bootstrap de reprise Galera apres panne totale
- reprise des peers / bricks Gluster apres grosse panne
- retrait destructif de noeuds du cluster de stockage
- corrections de paquets specifiques aux distros best-effort
- ajustement fin du hardening SELinux sur les systemes de la famille RedHat

---

## Verification / Verification

Lancez le playbook de validation:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml
```

ou pour standalone:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

Il execute un ensemble pratique de verifications sur le validateur LibreNMS, l'etat de Galera, l'etat de Redis Sentinel et l'etat du volume Gluster.

---

## Developpement / Development

Lancez le lint localement:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Contribution / Contributing

Les pull requests sont bienvenues. Merci de lire d'abord [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Securite / Security

Merci de lire [SECURITY.md](../../SECURITY.md) pour les consignes de signalement.

## Licence / License

MIT. Voir [LICENSE](../../LICENSE).
