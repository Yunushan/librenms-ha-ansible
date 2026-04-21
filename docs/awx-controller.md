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

It does not automatically import this repository into AWX or create job templates. After AWX is online, create a Project, Inventory, Machine Credential, and Job Templates for the playbooks you want operators to run.

Useful job templates usually include:

- `playbooks/cluster.yml`
- `playbooks/standalone.yml`
- `playbooks/validate.yml`
- `playbooks/add-node.yml`
- `playbooks/remove-node.yml`

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

## AWX setup after deployment

Inside AWX:

1. Add a Project pointing at this Git repository.
2. Add an Inventory matching the target LibreNMS topology.
3. Add a Machine Credential with SSH access to the managed hosts.
4. Create Job Templates for the playbooks operators should run.
5. Use AWX RBAC to separate day-2 operations from full cluster administration.

The AWX job execution environment must be able to reach managed hosts over SSH and must have access to any required private Git repositories or SSH keys.

## Operational notes

- Use a dedicated controller VM when possible.
- Back up AWX PostgreSQL data and Kubernetes secrets before upgrades.
- Treat `awx_controller_secret_key` as persistent state if you set it manually.
- Keep AWX, its Kubernetes runtime, and LibreNMS service nodes on restricted management networks.
- For small or single-operator environments, the existing CLI or Dockerized controller workflow may be simpler.
