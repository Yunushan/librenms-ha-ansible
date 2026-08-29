#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly SITE_FILE="${ROOT_DIR}/playbooks/site.yml"
readonly MAKEFILE="${ROOT_DIR}/Makefile"
readonly PLATFORM_INVENTORY="${ROOT_DIR}/inventories/platforms/hosts.yml"
readonly OPTIONAL_DOCS="${ROOT_DIR}/docs/optional-platforms.md"
readonly CHART_DIR="${ROOT_DIR}/charts/librenms-ha"

fail() {
    printf 'Optional platform guardrail test failed: %s\n' "$1" >&2
    exit 1
}

require_file() {
    [ -f "$1" ] || fail "missing required file: $1"
}

contains() {
    local file="$1"
    local expected="$2"

    grep -Fq -- "$expected" "$file" ||
        fail "$file does not contain: $expected"
}

main() {
    local playbook role template

    for playbook in docker podman kubernetes okd k3s rke2 microk8s kubespray kubeone gardener; do
        require_file "${ROOT_DIR}/playbooks/${playbook}.yml"
    done

    for role in container_platform kubernetes_platform k3s_platform rke2_platform microk8s_platform kubespray_platform kubeone_platform gardener_platform; do
        require_file "${ROOT_DIR}/roles/${role}/defaults/main.yml"
        require_file "${ROOT_DIR}/roles/${role}/tasks/main.yml"
        require_file "${ROOT_DIR}/roles/${role}/meta/main.yml"
    done

    contains "$PLATFORM_INVENTORY" 'container_hosts:'
    contains "$PLATFORM_INVENTORY" 'k3s_nodes:'
    contains "$PLATFORM_INVENTORY" 'k3s_servers:'
    contains "$PLATFORM_INVENTORY" 'k3s_agents:'
    contains "$PLATFORM_INVENTORY" 'rke2_nodes:'
    contains "$PLATFORM_INVENTORY" 'rke2_servers:'
    contains "$PLATFORM_INVENTORY" 'rke2_agents:'
    contains "$PLATFORM_INVENTORY" 'microk8s_nodes:'
    contains "$PLATFORM_INVENTORY" 'microk8s_primaries:'
    contains "$PLATFORM_INVENTORY" 'microk8s_joiners:'
    contains "$PLATFORM_INVENTORY" 'okd_controllers:'
    contains "$PLATFORM_INVENTORY" 'kubespray_controller:'
    contains "$PLATFORM_INVENTORY" 'kubeone_controller:'
    contains "$PLATFORM_INVENTORY" 'gardener_controller:'

    if grep -Eq 'container_platform|kubernetes_platform|k3s_platform|rke2_platform|microk8s_platform|kubespray_platform|kubeone_platform|gardener_platform' "$SITE_FILE"; then
        fail 'optional platform roles must not be imported by playbooks/site.yml'
    fi

    contains "$MAKEFILE" 'PLATFORM_INVENTORY ?= inventories/platforms/hosts.yml'
    contains "$MAKEFILE" 'CONTAINER_PLATFORM_LIMIT ?='
    contains "$MAKEFILE" 'KUBERNETES_CONNECTION_TIMEOUT ?= 30'
    contains "$MAKEFILE" '--timeout $(KUBERNETES_CONNECTION_TIMEOUT)'
    contains "$MAKEFILE" '-e "librenms_kubernetes_timeout=$(KUBERNETES_TIMEOUT)"'
    contains "$MAKEFILE" 'docker-ha:'
    contains "$MAKEFILE" 'podman-ha:'
    contains "$MAKEFILE" 'kubernetes:'
    contains "$MAKEFILE" 'k3s:'
    contains "$MAKEFILE" 'rke2:'
    contains "$MAKEFILE" 'microk8s:'
    contains "$MAKEFILE" 'kubespray:'
    contains "$MAKEFILE" 'kubeone:'
    contains "$MAKEFILE" 'gardener:'
    contains "$MAKEFILE" 'K3S_INSTALL_CHECKSUM'
    contains "$MAKEFILE" 'K3S_BOOTSTRAP_HOST'
    contains "$MAKEFILE" 'RKE2_INSTALL_CHECKSUM'
    contains "$MAKEFILE" 'RKE2_BOOTSTRAP_HOST'
    contains "$MAKEFILE" 'MICROK8S_PRIMARY_HOST'
    contains "$MAKEFILE" 'KUBERNETES_CONFIRM=true'
    contains "$MAKEFILE" 'test-optional-platform-guardrails'
    contains "$MAKEFILE" 'test-helm-chart:'
    contains "$ROOT_DIR/roles/container_platform/defaults/main.yml" 'librenms_container_examples_root: /opt/librenms-ha-ansible/examples/docker-ha'
    contains "$ROOT_DIR/roles/container_platform/tasks/main.yml" 'Verify container services remain running after lifecycle action'
    contains "$ROOT_DIR/roles/container_platform/tasks/main.yml" "--status', 'running', '--services"
    contains "$ROOT_DIR/roles/kubernetes_platform/tasks/main.yml" 'follow: false'
    contains "$ROOT_DIR/roles/kubeone_platform/tasks/main.yml" 'follow: false'
    contains "$ROOT_DIR/roles/kubespray_platform/tasks/main.yml" 'follow: false'
    contains "$ROOT_DIR/roles/gardener_platform/tasks/main.yml" 'follow: false'
    contains "$ROOT_DIR/roles/k3s_platform/tasks/main.yml" 'Refuse a symlinked k3s installer destination'
    contains "$ROOT_DIR/roles/rke2_platform/tasks/main.yml" 'Refuse a symlinked RKE2 installer destination'
    contains "$ROOT_DIR/roles/k3s_platform/tasks/main.yml" 'not librenms_k3s_uninstall.stat.islnk'
    contains "$ROOT_DIR/roles/k3s_platform/tasks/main.yml" 'Verify k3s agent service status'
    contains "$ROOT_DIR/roles/rke2_platform/tasks/main.yml" 'not librenms_rke2_uninstall.stat.islnk'
    contains "$ROOT_DIR/roles/rke2_platform/tasks/main.yml" 'Verify RKE2 agent service status'
    contains "$ROOT_DIR/roles/rke2_platform/tasks/main.yml" 'librenms_rke2_kubectl_path'
    contains "$ROOT_DIR/roles/rke2_platform/tasks/main.yml" '--kubeconfig'
    contains "$ROOT_DIR/roles/rke2_platform/defaults/main.yml" 'librenms_rke2_uninstall_path: /usr/local/bin/rke2-uninstall.sh'
    contains "$ROOT_DIR/roles/rke2_platform/defaults/main.yml" 'librenms_rke2_kubectl_path: /var/lib/rancher/rke2/bin/kubectl'
    contains "$ROOT_DIR/roles/rke2_platform/defaults/main.yml" 'librenms_rke2_kubeconfig_path: /etc/rancher/rke2/rke2.yaml'
    contains "$ROOT_DIR/roles/container_platform/tasks/main.yml" "item.stat.mode | default('') in"
    contains "$ROOT_DIR/examples/docker-ha/librenms/compose.yml" 'LIBRENMS_IMAGE:?Set LIBRENMS_IMAGE'
    contains "$ROOT_DIR/examples/docker-ha/redis-sentinel/compose.yml" 'REDIS_IMAGE:?Set REDIS_IMAGE'
    contains "$ROOT_DIR/examples/docker-ha/haproxy/compose.yml" 'HAPROXY_IMAGE:?Set HAPROXY_IMAGE'
    contains "$ROOT_DIR/roles/k3s_platform/tasks/main.yml" 'no_log: true'
    contains "$ROOT_DIR/roles/k3s_platform/tasks/main.yml" 'ansible_play_hosts_all[0] == librenms_k3s_bootstrap_host'
    contains "$ROOT_DIR/roles/k3s_platform/tasks/main.yml" "librenms_k3s_node_role != 'agent'"
    contains "$ROOT_DIR/roles/k3s_platform/tasks/main.yml" 'librenms_k3s_token | string | trim | length > 0'
    contains "$ROOT_DIR/roles/k3s_platform/templates/config.yaml.j2" 'cluster-init: true'
    contains "$ROOT_DIR/roles/rke2_platform/tasks/main.yml" 'no_log: true'
    contains "$ROOT_DIR/roles/rke2_platform/tasks/main.yml" 'ansible_play_hosts_all[0] == librenms_rke2_bootstrap_host'
    contains "$ROOT_DIR/roles/rke2_platform/tasks/main.yml" "librenms_rke2_node_role != 'agent'"
    contains "$ROOT_DIR/roles/rke2_platform/tasks/main.yml" 'librenms_rke2_token | string | trim | length > 0'
    contains "$ROOT_DIR/roles/microk8s_platform/tasks/main.yml" 'ansible_play_hosts_all | length == 1'
    contains "$ROOT_DIR/roles/microk8s_platform/tasks/main.yml" 'Verify MicroK8s worker readiness'

    contains "$OPTIONAL_DOCS" 'Do not call `make site`'
    contains "$OPTIONAL_DOCS" 'K3S_INSTALL_CHECKSUM'
    contains "$OPTIONAL_DOCS" 'K3S_BOOTSTRAP_HOST'
    contains "$OPTIONAL_DOCS" 'MICROK8S_PRIMARY_HOST'
    contains "$OPTIONAL_DOCS" 'ReadWriteMany'
    contains "$OPTIONAL_DOCS" 'Gardener'

    for template in _helpers.tpl deployment-web.yaml statefulset-dispatcher.yaml pvc.yaml pdb.yaml ingress.yaml route.yaml networkpolicy.yaml; do
        require_file "${CHART_DIR}/templates/${template}"
    done
    require_file "${CHART_DIR}/values.schema.json"
    contains "${CHART_DIR}/templates/_helpers.tpl" 'image.digest must be a full sha256 digest'
    contains "${CHART_DIR}/templates/validate.yaml" 'persistence.enabled=false requires persistence.existingClaim'
    contains "${CHART_DIR}/templates/validate.yaml" 'production requires persistence.accessModes to include ReadWriteMany'
    contains "${CHART_DIR}/templates/validate.yaml" 'production requires networkPolicy.enabled=true'
    contains "${CHART_DIR}/templates/validate.yaml" 'production networkPolicy.egress rules must restrict their destination'
    contains "${CHART_DIR}/templates/validate.yaml" 'production ingress TLS entries require secretName'
    contains "${CHART_DIR}/templates/validate.yaml" 'production web.resources.requests must not be empty'
    contains "${CHART_DIR}/templates/validate.yaml" 'production requires podSecurityContext.runAsNonRoot=true'
    contains "${CHART_DIR}/templates/validate.yaml" 'production requires containerSecurityContext.allowPrivilegeEscalation=false'
    contains "${CHART_DIR}/values.yaml" 'requireDigest: true'
    contains "${CHART_DIR}/values.yaml" 'production:'
    contains "${CHART_DIR}/values.yaml" 'topologySpreadConstraints: []'
    contains "${CHART_DIR}/values.yaml" 'ReadWriteMany'
    contains "${ROOT_DIR}/examples/kubernetes/values-production.yaml.example" 'existingClaim:'
    contains "${ROOT_DIR}/examples/kubernetes/values-production.yaml.example" 'production:'
    contains "${ROOT_DIR}/examples/kubernetes/values-production.yaml.example" 'networkPolicy:'
    if grep -Fq -- '--timeout $(KUBERNETES_TIMEOUT)' "$MAKEFILE"; then
        fail 'Ansible connection timeout must be an integer separate from Helm duration'
    fi
    if grep -Fq -- "librenms_kubernetes_release ~ '-librenms-ha-web'" "$ROOT_DIR/roles/kubernetes_platform/tasks/main.yml" ||
        grep -Fq -- "librenms_kubernetes_release ~ '-librenms-ha-dispatcher'" "$ROOT_DIR/roles/kubernetes_platform/tasks/main.yml"; then
        fail 'Kubernetes rollout checks must not assume the default Helm resource names'
    fi

    contains "${ROOT_DIR}/roles/k3s_platform/defaults/main.yml" 'librenms_k3s_install_checksum'
    contains "${ROOT_DIR}/roles/rke2_platform/defaults/main.yml" 'librenms_rke2_install_checksum'
    contains "${ROOT_DIR}/roles/microk8s_platform/tasks/main.yml" 'librenms_microk8s_join_token'
    contains "${ROOT_DIR}/roles/microk8s_platform/tasks/main.yml" 'Wait for a joined MicroK8s node'
    contains "${ROOT_DIR}/roles/gardener_platform/tasks/main.yml" 'no_log: true'
    contains "${ROOT_DIR}/roles/kubespray_platform/tasks/main.yml" '--check'
    contains "${ROOT_DIR}/roles/kubeone_platform/tasks/main.yml" "'apply'"
    contains "${ROOT_DIR}/roles/kubeone_platform/tasks/main.yml" "'status'"
    if grep -Eq "'install'|--dry-run" "${ROOT_DIR}/roles/kubeone_platform/tasks/main.yml"; then
        fail 'KubeOne adapter must use current status/apply commands, not install or dry-run'
    fi
    contains "${ROOT_DIR}/roles/gardener_platform/defaults/main.yml" 'resolve'
    contains "${ROOT_DIR}/roles/gardener_platform/defaults/main.yml" '--raw'

    printf 'Optional platform guardrail test passed.\n'
}

main "$@"
