# LibreNMS HA Ansible Deployment

Automacao Ansible pensada para producao para implantar **standalone, distributed polling e full HA** do LibreNMS em varias familias Linux.

![MIT License](https://img.shields.io/badge/license-MIT-green.svg)
![Ansible](https://img.shields.io/badge/ansible-core%202.15%2B-red.svg)
![LibreNMS](https://img.shields.io/badge/librenms-standalone%20%7C%20cluster-blue.svg)
![SNMP](https://img.shields.io/badge/snmp-v1%20%7C%20v2c%20%7C%20v3-orange.svg)
![GitHub Ready](https://img.shields.io/badge/repo-github--ready-black.svg)

> Nota
> O README em ingles e a versao canonica. Este arquivo e uma traducao completa para facilitar o onboarding. Se houver qualquer diferenca, siga [README.md](../../README.md).

## Network and Access Matrix

For the exact controller-to-node ports, cluster east-west traffic, and sudo requirements, see the canonical English section [Network and Access Matrix](../../README.md#network-and-access-matrix).

## Por Que Este Projeto Existe / Why This Exists

O LibreNMS e facil de colocar em funcionamento em um unico servidor, mas a operacao fica rapidamente baguncada assim que voce precisa de um ou mais dos itens abaixo:

- varios nos web ou poller do LibreNMS
- Redis Sentinel
- Galera
- armazenamento RRD compartilhado
- um VIP na frente da Web UI e do balanceador do banco de dados
- reconstrucoes repetiveis apos falha de host
- um unico repositorio que cubra standalone e HA

Este repositorio entrega um unico projeto Ansible capaz de implantar:

1. **LibreNMS standalone tudo em um**
2. **LibreNMS com distributed pollers e servicos compartilhados**
3. **LibreNMS full HA** com MariaDB Galera, Redis Sentinel, HAProxy + Keepalived e armazenamento RRD sobre GlusterFS.

---

## O Que Voce Recebe / What You Get

- roles Ansible modulares em vez de um unico shell script gigante
- selecao de topologia orientada por inventory
- implantacoes standalone ou cluster a partir do mesmo projeto
- Galera opcional e Redis Sentinel opcional
- camada opcional de VIP e load balancer
- gerenciamento opcional do agente SNMP local
- suporte a SNMP **v1**, **v2c** e **v3**
- fluxos para adicionar e remover nos LibreNMS
- estrutura pronta para GitHub com licenca MIT, workflow de lint, CONTRIBUTING, SECURITY, inventories de exemplo e gerador de segredos

---

## Modos De Topologia / Topology Modes

### 1) Standalone
Use um unico host para tudo.

Bom para laboratorios, ambientes menores e producao com um unico no e backups.

### 2) Cluster Sem Cluster De Banco
Use varios nos LibreNMS, mas apontando para uma pilha externa existente de DB / Redis / storage.

Bom para ambientes com MariaDB ou Redis gerenciados e para usuarios que querem escala de poller sem hospedar internamente todos os componentes HA.

### 3) Full HA
Use:
- `librenms_db_mode: galera`
- `librenms_redis_mode: sentinel`
- `librenms_rrd_mode: glusterfs`
- `librenms_vip_enabled: true`

Bom para plataformas internas serias de monitoramento, ambientes que precisam de sobrevivencia de web e pollers e operadores que ja entendem recovery de Galera / Redis / Gluster.

> Importante
> Este projeto automatiza a plataforma e o layout de arquivos e servicos do LibreNMS. O bootstrap inicial da aplicacao continua propositalmente conservador. Conclua primeiro o bootstrap inicial com o instalador web e depois execute o playbook novamente com `librenms_bootstrap_completed: true` para aplicar com limpeza as configuracoes de pos-bootstrap.

---

## Matriz De Suporte / Support Matrix

Este repositorio foi feito para suportar as distribuicoes pedidas, mas faz isso em dois niveis:

| Distro | Nivel | Notas |
|---|---|---|
| Ubuntu | Primario | Melhor encaixe com a documentacao oficial do LibreNMS |
| Debian | Primario | Melhor encaixe com a documentacao oficial do LibreNMS |
| Linux Mint | Quase primario | Usa a logica da familia Debian |
| AlmaLinux | Forte best-effort | Logica da familia RedHat |
| Rocky Linux | Forte best-effort | Logica da familia RedHat |
| Fedora | Forte best-effort | Logica da familia RedHat |
| CentOS / CentOS Stream | Best-effort | Pode exigir ajuste de repositorio dependendo da disponibilidade de PHP |
| Arch Linux | Best-effort | Mapeamento de familia incluido; valide nomes de pacotes em laboratorio |
| Manjaro Linux | Best-effort | Usa a logica da familia Arch |
| Alpine Linux | Best-effort | Diferencas de OpenRC e pacotes podem exigir overrides |
| Gentoo | Best-effort | Diferencas de pacotes e servicos podem exigir overrides |

### Reality Check

A documentacao upstream do LibreNMS atualmente fornece exemplos de pacote e instalacao para **Ubuntu 24.04**, **Ubuntu 22.04**, **Debian 12**, **Debian 13** e **CentOS 8**. Este repo vai alem com mapeamentos por familia amigaveis a override, mas voce deve validar em laboratorio os distros nao primarios antes de producao.

Veja tambem:
- [docs/support-matrix.md](../../docs/support-matrix.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Estrutura Do Repositorio / Repository Layout

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

## Inicio Rapido / Quick Start

1. Clone o repositorio e instale as collections:

```bash
git clone https://github.com/Yunushan/librenms-ha-ansible.git
cd librenms-ha-ansible
ansible-galaxy collection install -r requirements.yml
```

2. Gere segredos:

```bash
python3 scripts/generate-secrets.py > inventories/ha/group_vars/vault.yml
```

ou para standalone:

```bash
python3 scripts/generate-secrets.py > inventories/standalone/group_vars/vault.yml
```

3. Escolha um inventory:
- standalone: `inventories/standalone/hosts.yml`
- full HA: `inventories/ha/hosts.yml`

4. Edite host IPs, usuario SSH, `librenms_fqdn`, `librenms_app_key`, segredos de DB / Redis / VRRP, detalhes do VIP e configuracao de bricks do Gluster.

5. Execute a implantacao:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/standalone.yml
```

ou:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/cluster.yml
```

6. Conclua o primeiro bootstrap do LibreNMS em `/install`, depois defina:

```yaml
librenms_bootstrap_completed: true
```

e execute novamente o mesmo playbook.

---

## Modelo De Inventory / Inventory Model

Este repo usa grupos de inventory em vez de suposicoes hardcoded.

- `librenms_nodes`: nos de aplicacao
- `librenms_primary`: um no usado para tarefas principais de configuracao de pos-bootstrap
- `librenms_web`: nos que servem a Web UI
- `librenms_db`: nos de DB ou Galera
- `librenms_redis`: nos Redis / Sentinel
- `lb_nodes`: nos HAProxy / Keepalived
- `gluster_nodes`: nos de armazenamento RRD compartilhado
- `new_nodes`: nos que voce esta adicionando
- `decommission_nodes`: nos que estao sendo removidos

---

## Variaveis Mais Importantes / Variables That Matter Most

### Modo de instalacao

```yaml
librenms_mode: standalone           # standalone | cluster | ha
librenms_install_profile: full      # full | web | poller
```

### Modo de banco de dados

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

### Modo de armazenamento RRD

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

## Adicionar Um No / Add a Node

Adicione o host a `librenms_nodes`, a `librenms_web` ou ao perfil `librenms_poller`, inclua-o em `new_nodes`, defina um `librenms_node_id` unico e execute:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/add-node.yml
```

O playbook reutiliza `site.yml`, configura o novo host, reconcilia os backends do load balancer e renderiza novamente configs de Redis / Galera / app quando necessario.

> Dica
> Para um no web/poller, este e o caminho mais seguro de escala. Para mudancas de membership em Galera, Redis ou Gluster, teste primeiro o fluxo em laboratorio e leia [docs/architecture.md](../../docs/architecture.md).

---

## Remover Um No / Remove a Node

Tire o host dos grupos ativos, coloque-o em `decommission_nodes` e execute:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/remove-node.yml
```

Isso reconcilia o cluster sobrevivente com o inventory atualizado e desabilita ou limpa servicos no no removido.

> Importante
> Remover um no de storage de uma camada RRD baseada em Gluster nao e tratado como uma operacao casual. O repo deixa isso propositalmente como um fluxo revisado pelo operador.

---

## Suporte SNMP / SNMP Support

Este repo suporta tres modos SNMP:

- `SNMPv1`: community-based, util quando voce precisa suportar hardware legado.
- `SNMPv2c`: community-based e ainda comum para dispositivos antigos ou rollouts simples.
- `SNMPv3`: recomendado quando os dispositivos suportam; o repo pode configurar `snmpd`, criar usuarios SNMPv3 e definir a ordem de versoes SNMP do LibreNMS apos o bootstrap.

---

## Notas De Seguranca / Security Notes

- Coloque segredos em `group_vars/vault.yml` e criptografe com **Ansible Vault**
- Nao faca commit de arquivos vault gerados
- Use HTTPS na frente do LibreNMS antes de exposicao publica ou semipublica
- Trate o full-cluster recovery do Galera e mudancas de membership do Gluster como tarefas explicitas do operador
- Teste o failover regularmente

Veja:
- [SECURITY.md](../../SECURITY.md)
- [docs/architecture.md](../../docs/architecture.md)

---

## Limites Conhecidos / Known Boundaries

### Totalmente confortavel para automatizar
- instalacao de pacotes
- checkout do repo
- configuracao de nginx / php-fpm
- modo local do MariaDB
- padrao inicial de entrada de no no Galera
- configuracao de Redis / Sentinel
- configuracao de HAProxy / Keepalived
- deploy de arquivos da aplicacao LibreNMS
- configuracao do agente SNMP
- adicionar ou remover nos de aplicacao

### Revisado pelo operador por design
- disaster bootstrap do Galera apos outage total
- recovery de peer / brick do Gluster apos uma falha grave
- remocao destrutiva de nos da membership do cluster de storage
- correcoes de pacotes especificas por distro em distros best-effort
- ajuste fino de hardening SELinux em sistemas da familia RedHat

---

## Verificacao / Verification

Execute o playbook de validacao:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/validate.yml
```

ou para standalone:

```bash
ansible-playbook -i inventories/standalone/hosts.yml playbooks/validate.yml
```

Ele roda checagens praticas para o validador do LibreNMS, o status do Galera, o estado do Redis Sentinel e o status do volume Gluster.

---

## Desenvolvimento / Development

Rode lint localmente:

```bash
pip install ansible-core ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
yamllint .
ansible-lint
```

---

## Contribuicao / Contributing

Pull requests sao bem-vindos. Leia primeiro [CONTRIBUTING.md](../../CONTRIBUTING.md).

## Seguranca / Security

Leia [SECURITY.md](../../SECURITY.md) para a orientacao de reporte.

## Licenca / License

MIT. Veja [LICENSE](../../LICENSE).
