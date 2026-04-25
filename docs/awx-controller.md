# Optional AWX Controller

This repository can optionally bootstrap an AWX controller VM for teams that want a GUI, job scheduling, RBAC, and run history around the LibreNMS playbooks.

AWX is not part of the default LibreNMS deployment path. It is an optional controller-side service and should be treated as a separate management plane.

## What gets installed

The optional `awx_controller` role can:

- install k3s on a dedicated controller VM, or use an existing Kubernetes cluster reachable by `kubectl`
- deploy the upstream AWX Operator with Kustomize
- create an AWX custom resource
- expose AWX by NodePort, LoadBalancer, Ingress, or OpenShift Route settings

Upstream references:

- [AWX Operator documentation](https://docs.ansible.com/projects/awx-operator/en/latest/)
- [AWX Operator basic install](https://docs.ansible.com/projects/awx-operator/en/latest/installation/basic-install.html)
- [AWX network and TLS configuration](https://docs.ansible.com/projects/awx-operator/en/latest/user-guide/network-and-tls-configuration.html)

It does not automatically import this repository into AWX or create job
templates. After AWX is online, create a Project, Inventory, Machine
Credential, Vault Credential if needed, and the operational Job Templates below.

## Inventory

Add a controller VM to the `ansible_controller` group. The group exists empty in both example inventories.

```yaml
ansible_controller:
  hosts:
    awx1:
      ansible_host: 10.10.10.30
      ansible_user: root
```

## Basic k3s-backed AWX

Set these variables in the inventory group vars or host vars for the controller:

```yaml
awx_controller_enabled: true
awx_controller_kubernetes_backend: k3s
awx_controller_service_type: NodePort
awx_controller_nodeport_port: 30080
```

Then run:

```bash
make awx-controller
```

or explicitly:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/awx-controller.yml
```

For the standalone inventory:

```bash
make awx-controller AWX_INVENTORY=inventories/standalone/hosts.yml
```

## Existing Kubernetes cluster

If the controller host already has `kubectl` configured, use:

```yaml
awx_controller_enabled: true
awx_controller_kubernetes_backend: existing
awx_controller_kubectl: kubectl
awx_controller_kubeconfig: /root/.kube/config
```

The role will use the configured cluster and deploy AWX into `awx_controller_namespace`.

## Common settings

```yaml
awx_controller_namespace: awx
awx_controller_instance_name: librenms-awx
awx_controller_operator_version: 2.19.1
awx_controller_admin_user: admin
awx_controller_admin_email: noc@example.com
awx_controller_postgres_storage_size: 8Gi
```

The default operator version is pinned. Check the upstream AWX Operator release page before production use and override `awx_controller_operator_version` when you want a newer tested release.

## Admin password

If `awx_controller_admin_password` is empty, the AWX Operator generates a Kubernetes secret named:

```text
<awx_controller_instance_name>-admin-password
```

Retrieve it on the controller VM with:

```bash
kubectl -n awx get secret librenms-awx-admin-password -o jsonpath='{.data.password}' | base64 --decode ; echo
```

You can provide your own password:

```yaml
awx_controller_admin_password: CHANGE_ME_STRONG_PASSWORD
```

For production, store that value with Ansible Vault.

## Exposure modes

The simplest lab mode is NodePort:

```yaml
awx_controller_service_type: NodePort
awx_controller_nodeport_port: 30080
```

For an ingress controller:

```yaml
awx_controller_service_type: ClusterIP
awx_controller_ingress_type: ingress
awx_controller_ingress_hosts:
  - hostname: awx.example.com
awx_controller_ingress_class_name: nginx
```

For a Kubernetes LoadBalancer:

```yaml
awx_controller_service_type: LoadBalancer
awx_controller_loadbalancer_port: 80
```

Add TLS at your ingress, load balancer, or reverse proxy. The AWX role does not manage certificates.

## Optional AWX content bootstrap

After AWX is reachable, you can either create the Project, Inventory, and Job
Templates manually from the sections below, or let this repo create the baseline
objects through the AWX API.

Minimal bootstrap variables:

```yaml
awx_bootstrap_api_url: http://awx.example.com
awx_bootstrap_username: admin
awx_bootstrap_password: CHANGE_ME
awx_bootstrap_project_scm_url: https://github.com/example/librenms-ha-ansible.git
awx_bootstrap_project_scm_branch: main
```

Run:

```bash
make awx-bootstrap
```

or explicitly:

```bash
ansible-playbook -i inventories/ha/hosts.yml playbooks/awx-bootstrap.yml \
  -e awx_bootstrap_api_url=http://awx.example.com \
  -e awx_bootstrap_username=admin \
  -e awx_bootstrap_password=CHANGE_ME \
  -e awx_bootstrap_project_scm_url=https://github.com/example/librenms-ha-ansible.git
```

For production, store `awx_bootstrap_password` or `awx_bootstrap_oauth_token`
with Ansible Vault. If AWX already has a Machine Credential, attach it to the
templates by name:

```yaml
awx_bootstrap_job_template_credential_names:
  - LibreNMS HA SSH
```

If no credential names are supplied, the generated templates prompt for a
credential at launch. The bootstrap also creates an SCM inventory source pointed
at `inventories/ha/hosts.yml` by default:

```yaml
awx_bootstrap_inventory_source_path: inventories/ha/hosts.yml
```

Set `awx_bootstrap_execution_environment_name` to attach an existing execution
environment to every generated Job Template.

## AWX setup after deployment

Inside AWX, manually create or review these objects:

1. Add a Project pointing at this Git repository.
2. Add an Inventory matching the target LibreNMS topology.
3. Add a Machine Credential with SSH access to the managed hosts.
4. Add a Vault Credential when inventory or group vars are encrypted.
5. Create Job Templates for the playbooks operators should run.
6. Create Workflow Job Templates for repeated operational sequences.
7. Use schedules only for read-only checks and backups.
8. Use AWX RBAC to separate day-2 operations from full cluster administration.

The AWX job execution environment must be able to reach managed hosts over SSH
and must have access to required private Git repositories, SSH keys, Ansible
collections, and any internal package mirrors.

## Recommended Job Templates

Use one AWX Project for this repository and one Inventory per environment
(`lab`, `staging`, `production`). Enable "Prompt on launch" only for variables
that should be chosen by operators at runtime.

| Template name | Playbook | Launch type | Survey / extra vars | Notes |
| --- | --- | --- | --- | --- |
| LibreNMS HA - Status Strict | `playbooks/status.yml` | Scheduled and manual | `librenms_status_alert_fail_on_degraded: true` | Read-only health gate for VIP, HAProxy, Keepalived, Galera, Redis/Sentinel, Gluster, LibreNMS workers, scheduler, writable paths, and maintenance drift. |
| LibreNMS HA - Diagnostics | `playbooks/diagnostics.yml` | Manual or failure workflow | Optional `librenms_diagnostics_log_lines`, `librenms_diagnostics_journal_lines`, `librenms_diagnostics_keep_remote`, `librenms_diagnostics_fetch` | Collect before repeated recovery attempts. Archives are written to `diagnostics/<run-id>/` on the controller unless fetching is disabled. |
| LibreNMS HA - Validate | `playbooks/validate.yml` | Manual and workflow step | None by default | Application-level validation after changes, maintenance, or reboot convergence. |
| LibreNMS HA - Backup | `playbooks/backup.yml` | Scheduled and manual | Optional `librenms_backup_include_rrd`, `librenms_backup_host`, `librenms_backup_app_host`, `librenms_backup_rrd_host` | Schedule before maintenance windows. Keep at least one copy outside the HA cluster. |
| LibreNMS HA - Restore Test | `playbooks/restore-test.yml` | Manual | Required `librenms_restore_test_backup_dir` | Verifies a backup artifact without restoring it. |
| LibreNMS HA - Cluster Converge | `playbooks/cluster.yml` | Manual | None by default | Use after inventory/config changes or package/template drift. Do not schedule. |
| LibreNMS HA - Post Reboot | `playbooks/post-reboot.yml` | Manual | None by default | Use after full power loss, hypervisor maintenance, or restart of all nodes. |
| LibreNMS HA - Maintenance Enter | `playbooks/maintenance-enter.yml` | Manual with confirmation | Required `librenms_maintenance_target`; required `librenms_maintenance_confirm: true` | Drains one node before shutdown or OS work. Restrict to senior operators. |
| LibreNMS HA - Maintenance Exit | `playbooks/maintenance-exit.yml` | Manual with confirmation | Required `librenms_maintenance_target`; required `librenms_maintenance_confirm: true` | Rejoins one node and verifies the remaining HA layer. |
| LibreNMS HA - Failover Drill | `playbooks/ha-failover-test.yml` | Manual with confirmation | Required `librenms_failover_test_confirm: true`; optional `librenms_failover_test_cases` | Use in a maintenance window. Keep web/VIP cases separate from Redis/Galera cases unless you have a fresh backup. |
| LibreNMS HA - Galera Recovery | `playbooks/galera-recover.yml` | Emergency manual with approval | Required `librenms_galera_recover_confirm: true`; usually required `librenms_galera_recover_bootstrap_host` | Use only when Galera has no Primary component. Restrict heavily and require diagnostics first. |
| LibreNMS HA - Add Node | `playbooks/add-node.yml` | Manual | Node-specific inventory change first | Run only after the host is added to inventory and reviewed. |
| LibreNMS HA - Remove Node | `playbooks/remove-node.yml` | Manual | Node-specific inventory change first | Run only after the host is marked for removal and reviewed. |

For a standalone deployment, keep separate templates for
`playbooks/standalone.yml` and `playbooks/validate.yml` against the standalone
inventory. Do not point HA templates at a standalone inventory.

## Surveys

Recommended survey fields:

| Variable | Type | Required | Where used |
| --- | --- | --- | --- |
| `librenms_maintenance_target` | Text or multiple choice from inventory hostnames | Yes | Maintenance enter/exit |
| `librenms_maintenance_confirm` | Boolean | Yes, default `false` | Maintenance enter/exit |
| `librenms_restore_test_backup_dir` | Text | Yes | Restore test |
| `librenms_failover_test_confirm` | Boolean | Yes, default `false` | Failover drill |
| `librenms_failover_test_cases` | Multiple choice | Optional | Failover drill |
| `librenms_galera_recover_confirm` | Boolean | Yes, default `false` | Galera recovery |
| `librenms_galera_recover_bootstrap_host` | Text or multiple choice from DB hostnames | Required for confirmed recovery | Galera recovery |
| `librenms_diagnostics_log_lines` | Integer | Optional | Diagnostics |
| `librenms_diagnostics_journal_lines` | Integer | Optional | Diagnostics |

Keep confirmation booleans defaulted to `false`. This forces the operator to
make an explicit disruptive or destructive choice at launch time.

## Workflow Templates

Create these AWX Workflow Job Templates for common operations:

| Workflow | Steps | Schedule |
| --- | --- | --- |
| HA Health Gate | Status Strict | Every 5-15 minutes if AWX is your alert source |
| Pre-Maintenance Evidence | Status Strict -> Backup -> Validate | Manual before planned work |
| Incident Evidence | Status Strict -> Diagnostics | Manual, or attach to failed Status Strict notifications |
| Full Cluster Power-On Check | Post Reboot -> Validate -> Status Strict | Manual after all nodes boot |
| Node Maintenance Exit Check | Maintenance Exit -> Validate -> Status Strict | Manual after one node returns |
| Backup Assurance | Backup -> Restore Test | Daily or before maintenance if storage allows |

Do not put `maintenance-enter.yml`, `ha-failover-test.yml`, or
`galera-recover.yml` on an unattended schedule.

## RBAC Model

Use separate AWX teams:

- **Viewers** can read job history and diagnostics artifacts.
- **Operators** can launch `status.yml`, `diagnostics.yml`, `validate.yml`,
  `backup.yml`, `restore-test.yml`, `post-reboot.yml`, and maintenance exit.
- **Maintainers** can launch maintenance enter/exit, failover drills, and
  cluster convergence.
- **Administrators** can edit inventories, credentials, projects, and launch
  Galera recovery.

For production, require a ticket or approval process before launching
maintenance enter, data-layer failover tests, node removal, or Galera recovery.

## Scheduling

Reasonable production schedules:

- `status.yml` with `librenms_status_alert_fail_on_degraded: true`: every
  5-15 minutes.
- `backup.yml`: daily and before maintenance windows.
- `restore-test.yml`: after backup creation, or at least weekly.
- `diagnostics.yml`: not scheduled by default; run on failure.
- `validate.yml`: after changes, post-reboot convergence, or maintenance exit.

Avoid running `cluster.yml` on a timer. It is a convergence tool for intentional
changes, not a monitoring job.

## Operational notes

- Use a dedicated controller VM when possible.
- Back up AWX PostgreSQL data and Kubernetes secrets before upgrades.
- Treat `awx_controller_secret_key` as persistent state if you set it manually.
- Keep AWX, its Kubernetes runtime, and LibreNMS service nodes on restricted management networks.
- For small or single-operator environments, the existing CLI or Dockerized controller workflow may be simpler.
