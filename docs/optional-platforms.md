# Optional Platform Profiles

The repository now has separate, opt-in profiles for container and Kubernetes
platforms. They are deliberately outside `playbooks/site.yml` and the
`inventories/ha` inventory. Running the normal package-based HA workflow never
installs Docker, Podman, k3s, RKE2, MicroK8s, or a Kubernetes distribution.

These profiles are lifecycle adapters and application manifests. They do not
silently migrate an existing VM cluster, import an existing database, change
Galera membership, or upgrade MariaDB. Review the target platform and take a
backup before every mutating action.

## Support map

| Profile | Entry point | What it manages | State boundary |
|---|---|---|---|
| Docker Compose | `playbooks/docker.yml`, `make docker-ha` | The four Compose projects under `examples/docker-ha` | The target host's container runtime, Compose projects, and operator-provided `.env` files |
| Podman Compose | `playbooks/podman.yml`, `make podman-ha` | The same reviewed service definitions through Podman | The target host's Podman runtime and Compose provider |
| Generic Kubernetes | `charts/librenms-ha`, `playbooks/kubernetes.yml`, `make kubernetes` | LibreNMS web and dispatcher Deployments, Service, PVC use, probes, PDB, Ingress | Existing Kubernetes cluster, external MariaDB/Galera, Redis/Sentinel, Secret, and RWX storage |
| k3s | `playbooks/k3s.yml`, `make k3s` | A reviewed k3s node installer and node lifecycle | k3s only; deploy the LibreNMS chart separately with `make k3s-app` |
| RKE2 | `playbooks/rke2.yml`, `make rke2` | A reviewed RKE2 node installer and node lifecycle | RKE2 only; deploy the LibreNMS chart separately with `make rke2-app` |
| MicroK8s | `playbooks/microk8s.yml`, `make microk8s` | Snap installation, explicit join, addons, status, removal | MicroK8s only; deploy the LibreNMS chart separately with `make microk8s-app` |
| OKD | `playbooks/okd.yml`, `make okd-app` | The chart through `oc`, including an optional Route | Existing OKD cluster and its operators |
| Kubespray | `playbooks/kubespray.yml`, `make kubespray` | Native Kubespray preflight, plan, apply, and reset commands | An operator-managed Kubespray checkout and inventory |
| KubeOne | `playbooks/kubeone.yml`, `make kubeone` | Native KubeOne status, plan, apply, and reset commands | An operator-managed KubeOne manifest |
| Gardener | `playbooks/gardener.yml`, `make gardener` | `gardenctl` preflight, shoot status, and explicit kubeconfig export | Existing Gardener landscape/project/shoot |

The Kubernetes application chart intentionally treats MariaDB/Galera, Redis
Sentinel, secrets, and shared RRD as existing platform services. This avoids
embedding an unsafe stateful database implementation in a generic chart. A
production cluster must provide a tested RWX-capable storage class or an
existing claim and must use an immutable image digest.

## Separate inventory

Copy and edit [inventories/platforms/hosts.yml](../inventories/platforms/hosts.yml)
for platform hosts. Keep the existing `inventories/ha/hosts.yml` unchanged for
the package deployment. Put provider credentials in Ansible Vault or the
provider's secret store; do not place join tokens, passwords, or kubeconfigs in
this file.

## Docker and Podman

The Compose examples are still operator-reviewed examples, not a replacement
for the native package HA profile. On the container host, prepare a separate
`.env` file in each selected directory. Use immutable image references, for
example a registry digest, and verify the shared `/data` and RRD design before
deploying. The role validates every Compose project before it performs a
lifecycle action.

Read-only checks:

```bash
make docker-ha \
  CONTAINER_PLATFORM_LIMIT=docker-host-1 \
  CONTAINER_PLATFORM_ACTION=preflight

make podman-ha \
  CONTAINER_PLATFORM_LIMIT=podman-host-1 \
  CONTAINER_PLATFORM_ACTION=status
```

Mutating actions require explicit confirmation:

```bash
make docker-ha \
  CONTAINER_PLATFORM_LIMIT=docker-host-1 \
  CONTAINER_PLATFORM_ACTION=deploy \
  CONTAINER_PLATFORM_CONFIRM=true

make podman-ha \
  CONTAINER_PLATFORM_LIMIT=podman-host-1 \
  CONTAINER_PLATFORM_ACTION=restart \
  CONTAINER_PLATFORM_CONFIRM=true
```

Use one actual host name for these commands, not the `container_hosts` group;
the role deliberately refuses to run a Compose project on multiple hosts at
once.

The target host must have the checked-out Compose files at the paths supplied
through `librenms_container_manifests`. The default path is configurable; do
not copy production secrets into the Git repository. The role rejects symlinked
Compose or `.env` inputs and requires each `.env` file to use a private mode
(`0400`, `0440`, `0600`, or `0640`) before it invokes the provider.

## Kubernetes application chart

Copy [examples/kubernetes/values-production.yaml.example](../examples/kubernetes/values-production.yaml.example)
outside the repository and replace every example value. Create the referenced
Secret before deployment. The chart fails closed unless:

- `image.requireDigest=true` and `image.digest` is a full SHA-256 digest;
- `database.host` and `redis.sentinel` point at tested services;
- `persistence.enabled=true` or an existing claim is supplied;
- the claim supports the requested shared access mode, normally `ReadWriteMany`;
- the web health endpoint, ingress or route, and TLS policy have been reviewed.

Run the chart preflight and deploy it independently from cluster lifecycle:

```bash
make kubernetes \
  KUBERNETES_ACTION=preflight \
  KUBERNETES_VALUES_FILE=/etc/librenms/kubernetes-values.yaml

make kubernetes \
  KUBERNETES_ACTION=deploy \
  KUBERNETES_VALUES_FILE=/etc/librenms/kubernetes-values.yaml \
  KUBERNETES_CONFIRM=true
```

For OKD, use the Route-capable entry point:

```bash
make okd-app \
  KUBERNETES_ACTION=deploy \
  KUBERNETES_VALUES_FILE=/etc/librenms/okd-values.yaml \
  KUBERNETES_CONFIRM=true
```

Use `KUBERNETES_KUBECONFIG` or `KUBERNETES_CONTEXT` to select a non-default
cluster. The chart does not delete PVCs as part of Helm uninstall; review
retained data separately.

When `production.enabled=true`, the chart fails closed unless the production
values file also supplies explicit resource requests/limits, restrictive pod
security settings, topology spread constraints for web and dispatcher pods,
NetworkPolicy ingress and egress rules, a retained existing shared-storage
claim, and TLS ingress or an OKD Route. The sample file contains illustrative
namespace labels and must be reviewed against the actual cluster before use.

## Cluster adapters

### k3s and RKE2

Both installers require HTTPS and a SHA-256 checksum. Pin the installer
version, review the vendor release, and provide the cluster token through an
Ansible Vault extra-vars file. The Make targets do not accept tokens as plain
Make variables so they are not echoed in the command line. Server bootstrapping
is deliberately two-phase: the first server must be the first host in the
selected limit, it initializes the embedded control plane for k3s, and every
later server must receive the same server URL and token. Use the separate
`k3s_servers`/`k3s_agents` and `rke2_servers`/`rke2_agents` groups from the
sample inventory.

```bash
make k3s \
  K3S_ACTION=preflight \
  K3S_LIMIT=k3s_nodes

make k3s \
  K3S_ACTION=bootstrap \
  K3S_LIMIT=k3s_servers \
  K3S_BOOTSTRAP_HOST=k3s-server-1 \
  K3S_NODE_ROLE=server \
  K3S_VERSION=v1.33.4+k3s1 \
  K3S_INSTALL_CHECKSUM=sha256:<reviewed-installer-sha256> \
  K3S_CONFIRM=true \
  ANSIBLE_EXTRA_ARGS="-e @/root/secure/k3s.yml"
```

Use the equivalent `RKE2_*` variables for RKE2, including
`RKE2_BOOTSTRAP_HOST`. Run the server bootstrap with the server group, then
run the agent join separately with `K3S_NODE_ROLE=agent` or
`RKE2_NODE_ROLE=agent`, a dedicated agent limit, and Vault-supplied endpoint
and token. Bootstrap and removal are explicitly confirmed and the playbooks
run one node at a time.

### MicroK8s

Select the snap channel explicitly. On a secondary node, obtain the join
endpoint and one-time token from the primary operator workflow and pass the
token in an encrypted vars file. The role never scrapes or prints it.

```bash
make microk8s \
  MICROK8S_ACTION=bootstrap \
  MICROK8S_LIMIT=microk8s_primaries \
  MICROK8S_PRIMARY_HOST=microk8s-primary-1 \
  MICROK8S_NODE_ROLE=primary \
  MICROK8S_CHANNEL=1.32/stable \
  MICROK8S_CONFIRM=true
```

The primary operation must target exactly one host. Run
`microk8s add-node` on that primary, review the generated join command, then
run the secondary operation with `MICROK8S_LIMIT=microk8s_joiners`,
`MICROK8S_NODE_ROLE=control-plane` or `worker`,
`MICROK8S_JOIN_ENDPOINT=...`, and a Vault-supplied
`librenms_microk8s_join_token`.

### Kubespray and KubeOne

These profiles invoke the provider's native tooling from the controller. They
do not vendor or rewrite provider inventories. Start with `preflight`, review
the provider's status/plan output, and only then set confirmation for apply or
reset.

```bash
make kubespray \
  KUBESPRAY_ACTION=plan \
  KUBESPRAY_DIRECTORY=/srv/kubespray \
  KUBESPRAY_INVENTORY=/srv/kubespray/inventory/prod/hosts.yaml

make kubeone \
  KUBEONE_ACTION=plan \
  KUBEONE_MANIFEST=/etc/kubeone/production.yaml
```

The LibreNMS chart remains a separate `make kubespray-app` or
`make kubeone-app` operation after the cluster passes its own provider checks.

### Gardener

Gardener is an access adapter, not a shoot-creation workflow. It checks
`gardenctl`, resolves a selected shoot, or exports a selected shoot kubeconfig
to a new mode-0600 file after explicit confirmation. Provider installations with a
different `gardenctl` argument layout can override
`librenms_gardener_status_args` and `librenms_gardener_kubeconfig_args` through
`ANSIBLE_EXTRA_ARGS`.

```bash
make gardener \
  GARDENER_ACTION=status \
  GARDENER_GARDEN=production \
  GARDENER_PROJECT=monitoring \
  GARDENER_SHOOT=librenms

make gardener \
  GARDENER_ACTION=kubeconfig \
  GARDENER_GARDEN=production \
  GARDENER_PROJECT=monitoring \
  GARDENER_SHOOT=librenms \
  GARDENER_KUBECONFIG_DESTINATION=/root/secure/librenms-kubeconfig \
  GARDENER_CONFIRM=true
```

## Verification order

For any provider, use this order:

1. Run the provider adapter in `preflight` or `plan` mode.
2. Verify cluster quorum, node readiness, storage class, secret delivery, and
   external database/Redis health using provider-native checks.
3. Run the Helm chart in `preflight` mode and review the rendered resources.
4. Deploy or update the application with explicit confirmation.
5. Run the chart `status` action, the provider's health checks, and the
   LibreNMS validation and production-readiness workflows appropriate to the
   environment.

Do not call `make site` to deploy these profiles. `site.yml` remains the
package-based LibreNMS workflow and can safely coexist with these optional
entry points as long as they use different hosts and inventories.
