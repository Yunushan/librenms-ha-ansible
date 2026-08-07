#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DEFAULTS_FILE="$ROOT_DIR/roles/librenms_defaults/defaults/main.yml"
BOOTSTRAP_FILE="$ROOT_DIR/playbooks/platform-bootstrap.yml"
REDHAT_VARS_FILE="$ROOT_DIR/roles/common/vars/RedHat.yml"
REDHAT_REPOS_FILE="$ROOT_DIR/roles/common/tasks/redhat_repos.yml"
RUNTIME_SUPPORT_FILE="$ROOT_DIR/roles/common/tasks/runtime_support.yml"
SELINUX_FILE="$ROOT_DIR/roles/librenms_app/tasks/selinux.yml"
FIREWALLD_FILE="$ROOT_DIR/roles/host_firewall/tasks/firewalld.yml"
FIREWALLD_RULE_FILE="$ROOT_DIR/roles/host_firewall/tasks/firewalld_rich_rule.yml"
LIBRENMS_APP_FILE="$ROOT_DIR/roles/librenms_app/tasks/main.yml"
POST_REBOOT_FILE="$ROOT_DIR/roles/post_reboot/tasks/main.yml"
HA_STATUS_FILE="$ROOT_DIR/roles/ha_status/tasks/main.yml"
RUNTIME_WAIT_FILE="$ROOT_DIR/roles/librenms_app/templates/librenms-ha-runtime-wait.sh.j2"
DAILY_SERVICE_FILE="$ROOT_DIR/roles/librenms_app/templates/librenms-daily.service.j2"
DISPATCHER_OVERRIDE_FILE="$ROOT_DIR/roles/librenms_app/templates/librenms-dispatcher.systemd-override.conf.j2"
SCHEDULER_SERVICE_FILE="$ROOT_DIR/roles/librenms_app/templates/librenms-scheduler.service.j2"
STARTUP_REPAIR_SERVICE_FILE="$ROOT_DIR/roles/librenms_app/templates/librenms-ha-startup-repair.service.j2"
PRODUCTION_READINESS_FILE="$ROOT_DIR/roles/production_readiness/tasks/main.yml"
SYSLOG_FILE="$ROOT_DIR/roles/librenms_syslog/tasks/main.yml"
SYSLOG_TEMPLATE="$ROOT_DIR/roles/librenms_syslog/templates/rsyslog-librenms.conf.j2"
EXTERNAL_RRD_FILE="$ROOT_DIR/roles/external_rrd/tasks/main.yml"
GLUSTER_RRD_FILE="$ROOT_DIR/roles/glusterfs_rrd/tasks/main.yml"
SITE_FILE="$ROOT_DIR/playbooks/site.yml"
SUPPORT_MATRIX_FILE="$ROOT_DIR/docs/support-matrix.md"
README_FILE="$ROOT_DIR/README.md"
LAUNCHER_FILE="$ROOT_DIR/scripts/ansible-playbook.sh"
CONTROLLER_BOOTSTRAP_FILE="$ROOT_DIR/scripts/bootstrap-controller.sh"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/lint.yml"
MANAGED_RUNTIME_PLAYBOOK="$ROOT_DIR/tests/platform/managed-runtime-smoke.yml"
MANAGED_RUNTIME_SCRIPT="$ROOT_DIR/tests/platform/managed-runtime-smoke.sh"
REDIS_SENTINEL_SERVICE_FILE="$ROOT_DIR/roles/redis_sentinel/templates/librenms-redis-sentinel.service.j2"

require_text() {
    local file="$1"
    local expected="$2"

    if ! grep -Fq -- "$expected" "$file"; then
        printf 'Missing platform support guardrail in %s: %s\n' \
            "$file" "$expected" >&2
        exit 1
    fi
}

require_text "$DEFAULTS_FILE" '"26": "26.04"'
require_text "$DEFAULTS_FILE" '"8": "8.10"'
require_text "$DEFAULTS_FILE" '"9": "9.4"'
require_text "$DEFAULTS_FILE" 'librenms_managed_python_root:'
require_text "$DEFAULTS_FILE" 'librenms_supported_architectures:'
require_text "$DEFAULTS_FILE" 'librenms_runtime_python_executable:'
require_text "$DEFAULTS_FILE" 'RedHat: primary'
require_text "$DEFAULTS_FILE" '"Red Hat Enterprise Linux": primary'
require_text "$DEFAULTS_FILE" 'AlmaLinux: primary'
require_text "$DEFAULTS_FILE" 'Rocky: primary'
require_text "$BOOTSTRAP_FILE" 'dnf -y install python3.11 python3.11-pip'
require_text "$BOOTSTRAP_FILE" 'python3 python3-pip python3-venv'
require_text "$BOOTSTRAP_FILE" 'ansible_python="${python_bin}"'
require_text "$BOOTSTRAP_FILE" 'ansible-core 2.20+ requires Python 3.9 or newer on targets'
require_text "$BOOTSTRAP_FILE" 'LIBRENMS_ANSIBLE_PYTHON='
require_text "$SITE_FILE" 'ansible.builtin.import_playbook: platform-bootstrap.yml'
require_text "$RUNTIME_SUPPORT_FILE" 'Validate supported target architecture'
require_text "$RUNTIME_SUPPORT_FILE" 'librenms_runtime_python_executable'
require_text "$REDHAT_VARS_FILE" "['valkey']"
require_text "$REDHAT_VARS_FILE" '/usr/bin/valkey-cli'
require_text "$REDHAT_VARS_FILE" "'valkey-sentinel'"
require_text "$REDHAT_VARS_FILE" "'/etc/redis/redis.conf'"
require_text "$REDHAT_VARS_FILE" "'/etc/redis/sentinel.conf'"
require_text "$REDHAT_VARS_FILE" "else '/etc/redis.conf'"
require_text "$REDHAT_VARS_FILE" "else '/etc/redis-sentinel.conf'"
require_text "$REDHAT_VARS_FILE" 'mariadb-server-galera'
require_text "$REDHAT_VARS_FILE" "'curl-minimal'"
require_text "$REDHAT_VARS_FILE" 'librenms_curl_package'
require_text "$REDHAT_VARS_FILE" 'iproute'
require_text "$REDHAT_VARS_FILE" 'util-linux'
require_text "$REDHAT_REPOS_FILE" 'Enable RHEL CodeReady Builder repository'
require_text "$REDHAT_REPOS_FILE" 'Enable supported PHP module stream'
require_text "$REDHAT_REPOS_FILE" 'Enable supported MariaDB module stream'
require_text "$SELINUX_FILE" 'httpd_sys_rw_content_t'
require_text "$SELINUX_FILE" "['httpd_use_nfs']"
require_text "$SELINUX_FILE" 'semanage fcontext -l -C'
require_text "$FIREWALLD_FILE" '--get-target'
require_text "$FIREWALLD_RULE_FILE" '--query-rich-rule='
require_text "$FIREWALLD_RULE_FILE" '--add-rich-rule='
require_text "$SYSLOG_FILE" 'Verify the LibreNMS syslog helper has the vendor SELinux context'
require_text "$SYSLOG_FILE" 'semanage fcontext -l -C'
require_text "$SYSLOG_FILE" '--query-port='
require_text "$SYSLOG_TEMPLATE" 'binary="{{ librenms_syslog_omprog_binary }}"'
require_text "$EXTERNAL_RRD_FILE" 'Verify external RRD storage is writable by LibreNMS'
require_text "$SITE_FILE" 'Configure externally managed shared RRD storage'
require_text "$SUPPORT_MATRIX_FILE" 'RHEL / Red Hat Enterprise Linux (8.10+, 9.4+, 10.x)'
require_text "$SUPPORT_MATRIX_FILE" 'RHEL-family 8/9/10 require externally managed NFS/NFSv4 storage'
require_text "$SUPPORT_MATRIX_FILE" 'Python | 3.9 through 3.14'
require_text "$README_FILE" 'Ubuntu 22.04, 24.04, 26.04 | Primary'
require_text "$README_FILE" 'AlmaLinux 8.10+, 9.4+, 10.x | Primary'
require_text "$README_FILE" 'Rocky Linux 8.10+, 9.4+, 10.x | Primary'
require_text "$README_FILE" 'make controller-bootstrap'
require_text "$LAUNCHER_FILE" 'minimum_ansible_core_version="${LIBRENMS_MINIMUM_ANSIBLE_CORE_VERSION:-2.20.0}"'
require_text "$CONTROLLER_BOOTSTRAP_FILE" '--require-hashes'
require_text "$MANAGED_RUNTIME_PLAYBOOK" "ansible_facts.python.executable == '/opt/librenms-ha-ansible/python/bin/python'"
require_text "$MANAGED_RUNTIME_PLAYBOOK" 'ansible.builtin.package:'
require_text "$MANAGED_RUNTIME_SCRIPT" 'librenms-ha-ansible-controller:local'
require_text "$WORKFLOW_FILE" 'managed-runtime-smoke.sh ubuntu:26.04 3.14 ubuntu-26'
require_text "$WORKFLOW_FILE" 'managed-runtime-smoke.sh rockylinux/rockylinux:8 3.11 rocky-8'
require_text "$WORKFLOW_FILE" 'managed-runtime-smoke.sh rockylinux/rockylinux:10 3.12 rocky-10'
require_text "$REDIS_SENTINEL_SERVICE_FILE" 'RuntimeDirectory={{ librenms_redis_runtime_user }}'
require_text "$GLUSTER_RRD_FILE" "ansible_os_family != 'RedHat'"
require_text "$GLUSTER_RRD_FILE" 'do not provide a production-supported glusterfs-server package'
require_text "$LIBRENMS_APP_FILE" '- name: Disable rrdcached on ineligible nodes'
require_text "$DEFAULTS_FILE" "librenms_rrd_mode in ['glusterfs', 'external']"
require_text "$PRODUCTION_READINESS_FILE" "librenms_rrd_mode in ['glusterfs', 'external']"
require_text "$PRODUCTION_READINESS_FILE" "in ['nfs', 'nfs4']"
require_text "$HA_STATUS_FILE" '- name: Check shared RRD mount type and write access'
require_text "$HA_STATUS_FILE" "not in ['nfs', 'nfs4']"
require_text "$RUNTIME_WAIT_FILE" '[ "${RRD_MODE}" = "external" ]'
require_text "$DAILY_SERVICE_FILE" "librenms_rrd_mode in ['glusterfs', 'external']"
require_text "$DISPATCHER_OVERRIDE_FILE" "librenms_rrd_mode in ['glusterfs', 'external']"
require_text "$SCHEDULER_SERVICE_FILE" "librenms_rrd_mode in ['glusterfs', 'external']"
require_text "$STARTUP_REPAIR_SERVICE_FILE" "librenms_rrd_mode in ['glusterfs', 'external']"

if grep -Fq "ansible_os_family == 'Debian'" "$POST_REBOOT_FILE"; then
    printf 'Post-reboot convergence must repair managed services on both primary OS families.\n' >&2
    exit 1
fi

rrdcached_runtime_block=$(awk '
    /- name: Check for wildcard rrdcached TCP listener in VIP mode/ { capture=1 }
    capture { print }
    /- name: Enable nginx/ { exit }
' "$LIBRENMS_APP_FILE")
if grep -Fq "ansible_os_family == 'Debian'" <<< "$rrdcached_runtime_block"; then
    printf 'RRDCacheD runtime convergence must not be limited to Debian.\n' >&2
    exit 1
fi

if grep -REn --include='*.yml' --include='*.j2' \
    "(^|[[:space:]\"'])redis-cli([[:space:]\"']|$)" \
    "$ROOT_DIR/roles" | grep -v 'librenms_redis_cli_binary'; then
    printf 'Runtime roles must use librenms_redis_cli_binary for EL10 Valkey.\n' >&2
    exit 1
fi

if grep -Fq 'disable_gpg_check: true' "$REDHAT_REPOS_FILE"; then
    printf 'RedHat repository setup must not disable package signature checks.\n' >&2
    exit 1
fi

if grep -REn --include='*.yml' --include='*.yaml' \
    'ansible\.posix\.firewalld:|community\.general\.sefcontext:' \
    "$ROOT_DIR/roles"; then
    printf 'EL8 roles must not depend on Python 3.6-only firewall or SELinux bindings.\n' >&2
    exit 1
fi

printf 'Platform support guardrail test passed.\n'
