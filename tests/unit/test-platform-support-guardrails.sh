#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
DEFAULTS_FILE="$ROOT_DIR/roles/librenms_defaults/defaults/main.yml"
BOOTSTRAP_FILE="$ROOT_DIR/playbooks/platform-bootstrap.yml"
REDHAT_VARS_FILE="$ROOT_DIR/roles/common/vars/RedHat.yml"
REDHAT_REPOS_FILE="$ROOT_DIR/roles/common/tasks/redhat_repos.yml"
PACKAGE_SMOKE_FILE="$ROOT_DIR/tests/platform/package-smoke.sh"
RUNTIME_SUPPORT_FILE="$ROOT_DIR/roles/common/tasks/runtime_support.yml"
SELINUX_FILE="$ROOT_DIR/roles/librenms_app/tasks/selinux.yml"
FIREWALLD_FILE="$ROOT_DIR/roles/host_firewall/tasks/firewalld.yml"
FIREWALLD_RULE_FILE="$ROOT_DIR/roles/host_firewall/tasks/firewalld_rich_rule.yml"
LIBRENMS_APP_FILE="$ROOT_DIR/roles/librenms_app/tasks/main.yml"
COMMON_TASKS_FILE="$ROOT_DIR/roles/common/tasks/main.yml"
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
RHEL_PROFILE_FILE="$ROOT_DIR/inventories/ha/group_vars/rhel_external_nfs.yml"
HA_INVENTORY_FILE="$ROOT_DIR/inventories/ha/hosts.yml"
MAKEFILE_FILE="$ROOT_DIR/Makefile"
PLATFORM_ACCEPTANCE_FILE="$ROOT_DIR/playbooks/platform-acceptance.yml"
OPERATIONS_FILE="$ROOT_DIR/docs/operations.md"
ARCHITECTURE_FILE="$ROOT_DIR/docs/architecture.md"
CHECKLIST_FILE="$ROOT_DIR/docs/operator-checklists.md"
READINESS_ASSESSMENT_FILE="$ROOT_DIR/docs/production-readiness-assessment.md"
README_FILE="$ROOT_DIR/README.md"
LAUNCHER_FILE="$ROOT_DIR/scripts/ansible-playbook.sh"
CONTROLLER_BOOTSTRAP_FILE="$ROOT_DIR/scripts/bootstrap-controller.sh"
WORKFLOW_FILE="$ROOT_DIR/.github/workflows/lint.yml"
MANAGED_RUNTIME_PLAYBOOK="$ROOT_DIR/tests/platform/managed-runtime-smoke.yml"
MANAGED_RUNTIME_SCRIPT="$ROOT_DIR/tests/platform/managed-runtime-smoke.sh"
REDIS_SENTINEL_SERVICE_FILE="$ROOT_DIR/roles/redis_sentinel/templates/librenms-redis-sentinel.service.j2"
REDIS_SENTINEL_TASK_FILE="$ROOT_DIR/roles/redis_sentinel/tasks/main.yml"
REDIS_SENTINEL_TASKS_FILE="$ROOT_DIR/roles/redis_sentinel/tasks/main.yml"
MARIADB_TASKS_FILE="$ROOT_DIR/roles/mariadb/tasks/main.yml"

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
require_text "$DEFAULTS_FILE" 'librenms_managed_python_dotenv_version: "1.0.1"'
require_text "$DEFAULTS_FILE" 'librenms_managed_python_setuptools_version: "75.9.1"'
require_text "$DEFAULTS_FILE" 'librenms_managed_python_psutil_version: "7.0.0"'
require_text "$DEFAULTS_FILE" 'librenms_managed_python_command_runner_version: "1.7.6"'
require_text "$DEFAULTS_FILE" 'librenms_supported_architectures:'
require_text "$DEFAULTS_FILE" 'librenms_runtime_python_executable:'
require_text "$DEFAULTS_FILE" 'librenms_rhel8_package_cli_fallback: true'
require_text "$PACKAGE_SMOKE_FILE" 'dnf_retry() {'
require_text "$PACKAGE_SMOKE_FILE" 'dnf --setopt=retries=10 --setopt=timeout=30 "$@"'
require_text "$PACKAGE_SMOKE_FILE" 'dnf clean expire-cache'
require_text "$PACKAGE_SMOKE_FILE" 'dnf_retry -y --setopt=install_weak_deps=False install'
require_text "$DEFAULTS_FILE" 'RedHat: primary'
require_text "$DEFAULTS_FILE" '"Red Hat Enterprise Linux": primary'
require_text "$DEFAULTS_FILE" 'AlmaLinux: primary'
require_text "$DEFAULTS_FILE" 'Rocky: primary'
require_text "$BOOTSTRAP_FILE" 'dnf -y install python3.11 python3.11-pip'
require_text "$BOOTSTRAP_FILE" 'python3 python3-pip python3-venv'
require_text "$BOOTSTRAP_FILE" 'ansible_python="${python_bin}"'
require_text "$BOOTSTRAP_FILE" 'ansible-core 2.21 requires Python 3.9 or newer on targets'
require_text "$BOOTSTRAP_FILE" 'LIBRENMS_ANSIBLE_PYTHON='
require_text "$BOOTSTRAP_FILE" 'python-dotenv=='
require_text "$BOOTSTRAP_FILE" 'command_runner=='
require_text "$BOOTSTRAP_FILE" 'current_command_runner='
require_text "$BOOTSTRAP_FILE" 'run_apt_with_lock_retry()'
require_text "$BOOTSTRAP_FILE" 'Timed out waiting for the APT package-manager lock'
require_text "$DEFAULTS_FILE" 'librenms_managed_python_apt_lock_retries: 60'
require_text "$SITE_FILE" 'ansible.builtin.import_playbook: platform-bootstrap.yml'
if [ "$(grep -c '^  any_errors_fatal: true$' "$SITE_FILE")" -ne 9 ]; then
    printf 'site.yml must fail the full deployment when any host cannot converge.\n' >&2
    exit 1
fi
require_text "$RUNTIME_SUPPORT_FILE" 'Validate supported target architecture'
require_text "$RUNTIME_SUPPORT_FILE" 'Require a primary distribution for production profile'
require_text "$RUNTIME_SUPPORT_FILE" 'Production profile'
require_text "$RUNTIME_SUPPORT_FILE" 'primary production target for this repository'
require_text "$RUNTIME_SUPPORT_FILE" 'librenms_runtime_python_executable'
require_text "$COMMON_TASKS_FILE" 'Validate production platform baseline before package changes'
require_text "$COMMON_TASKS_FILE" 'librenms_platform_min_version'
require_text "$REDHAT_VARS_FILE" "['valkey']"
require_text "$REDHAT_VARS_FILE" '/usr/bin/valkey-cli'
require_text "$REDHAT_VARS_FILE" "'valkey-sentinel'"
require_text "$REDHAT_VARS_FILE" "'/etc/redis/redis.conf'"
require_text "$REDHAT_VARS_FILE" "'/etc/redis/sentinel.conf'"
require_text "$REDHAT_VARS_FILE" "else '/etc/redis.conf'"
require_text "$REDHAT_VARS_FILE" "else '/etc/redis-sentinel.conf'"
require_text "$DEFAULTS_FILE" 'librenms_redis_runtime_dir: /run/redis'
require_text "$REDHAT_VARS_FILE" "{{ '/run/valkey' if (ansible_facts.distribution_major_version | int) >= 10 else '/run/redis' }}"
require_text "$ROOT_DIR/roles/redis_sentinel/templates/redis.conf.j2" 'librenms_redis_runtime_dir'
require_text "$ROOT_DIR/roles/redis_sentinel/templates/sentinel.conf.j2" 'librenms_redis_runtime_dir'
require_text "$ROOT_DIR/roles/redis_sentinel/templates/redis.conf.j2" 'valkey-server.pid'
require_text "$ROOT_DIR/roles/redis_sentinel/templates/sentinel.conf.j2" 'valkey-sentinel.pid'
if grep -Fq 'pidfile /run/redis/' \
    "$ROOT_DIR/roles/redis_sentinel/templates/redis.conf.j2" \
    "$ROOT_DIR/roles/redis_sentinel/templates/sentinel.conf.j2"; then
    printf 'Redis/Valkey templates must not hard-code the Debian runtime directory.\n' >&2
    exit 1
fi
require_text "$REDHAT_VARS_FILE" 'mariadb-server-galera'
require_text "$DEFAULTS_FILE" 'librenms_redhat_mariadb_expected_series: "10.11"'
require_text "$REDHAT_REPOS_FILE" 'Validate the supported RHEL-family MariaDB stream'
require_text "$MARIADB_TASKS_FILE" 'Enforce the supported RHEL-family MariaDB server series'
require_text "$MARIADB_TASKS_FILE" 'Enforce the supported Ubuntu distro MariaDB server series'
require_text "$DEFAULTS_FILE" 'librenms_ubuntu_mariadb_expected_series:'
require_text "$REDHAT_VARS_FILE" "'curl-minimal'"
require_text "$REDHAT_VARS_FILE" 'librenms_curl_package'
require_text "$REDHAT_VARS_FILE" 'iproute'
require_text "$REDHAT_VARS_FILE" 'util-linux'
require_text "$REDHAT_REPOS_FILE" 'Enable RHEL CodeReady Builder repository'
require_text "$REDHAT_REPOS_FILE" 'Locate the native RHEL subscription-manager CLI'
require_text "$REDHAT_REPOS_FILE" 'subscription-manager'
require_text "$DEFAULTS_FILE" 'librenms_rhel_subscription_manager_cli_enabled: true'
require_text "$REDHAT_REPOS_FILE" 'Enable supported PHP module stream'
require_text "$REDHAT_REPOS_FILE" 'Enable supported MariaDB module stream'
require_text "$COMMON_TASKS_FILE" 'Fail early when RHEL-family storage mode is unsupported'
require_text "$COMMON_TASKS_FILE" 'Require shared NFS RRD storage for RHEL-family HA'
require_text "$COMMON_TASKS_FILE" 'Configure the supported PHP stream for Ubuntu 22'
require_text "$COMMON_TASKS_FILE" 'Install Ubuntu 22 PHP repository prerequisites'
require_text "$COMMON_TASKS_FILE" 'librenms_ubuntu_php_repository_keyring'
require_text "$COMMON_TASKS_FILE" 'gpg --batch --show-keys'
require_text "$COMMON_TASKS_FILE" 'Signed-By:'
if grep -Fq 'add-apt-repository' "$COMMON_TASKS_FILE"; then
    printf 'Ubuntu repository setup must not use the fragile add-apt-repository shortcut.\n' >&2
    exit 1
fi
require_text "$DEFAULTS_FILE" 'librenms_ubuntu_php_repository: ppa:ondrej/php'
require_text "$DEFAULTS_FILE" 'librenms_ubuntu_php_repository_source_pattern'
require_text "$DEFAULTS_FILE" 'librenms_ubuntu_php_repository_key_fingerprint'
require_text "$REDHAT_VARS_FILE" 'librenms_php_fpm_service_name: php-fpm'
require_text "$COMMON_TASKS_FILE" 'Local RRD storage cannot be shared safely'
require_text "$COMMON_TASKS_FILE" 'multiple LibreNMS'
require_text "$COMMON_TASKS_FILE" 'web nodes'
require_text "$COMMON_TASKS_FILE" 'production-supported'
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
require_text "$SUPPORT_MATRIX_FILE" 'librenms_redhat_mariadb_stream: "10.11"'
require_text "$SUPPORT_MATRIX_FILE" 'Ubuntu 22.04 uses 10.6, Ubuntu 24.04 uses 10.11, Ubuntu 26.04 uses 11.8'
require_text "$SUPPORT_MATRIX_FILE" 'auto-select or certify that version'
require_text "$SUPPORT_MATRIX_FILE" '-m ansible.builtin.script'
require_text "$SUPPORT_MATRIX_FILE" '-a tests/platform/package-smoke.sh'
require_text "$SUPPORT_MATRIX_FILE" 'make platform-acceptance PLATFORM_ACCEPTANCE_CONFIRM=true'
require_text "$MAKEFILE_FILE" 'PLATFORM_ACCEPTANCE_CONFIRM ?= false'
require_text "$MAKEFILE_FILE" 'playbooks/platform-acceptance.yml'
require_text "$PLATFORM_ACCEPTANCE_FILE" 'ansible.builtin.script:'
require_text "$PLATFORM_ACCEPTANCE_FILE" 'tests/platform/package-smoke.sh'
require_text "$PLATFORM_ACCEPTANCE_FILE" 'serial: 1'
require_text "$HA_INVENTORY_FILE" 'rhel_external_nfs:'
require_text "$RHEL_PROFILE_FILE" 'librenms_rrd_mode: external'
require_text "$RHEL_PROFILE_FILE" 'librenms_external_rrd_fstype: nfs4'
require_text "$RHEL_PROFILE_FILE" 'librenms_external_rrd_source: ""'
require_text "$RHEL_PROFILE_FILE" 'librenms_uid: 60000'
require_text "$RHEL_PROFILE_FILE" 'librenms_gid: 60000'
require_text "$DEFAULTS_FILE" 'librenms_redhat_mariadb_stream: "10.11"'
require_text "$SUPPORT_MATRIX_FILE" 'Python | 3.9 through 3.14'
require_text "$OPERATIONS_FILE" 'shared RRD filesystem'
require_text "$OPERATIONS_FILE" 'NFS/NFSv4 RRD path'
require_text "$ARCHITECTURE_FILE" 'Shared RRD storage'
require_text "$ARCHITECTURE_FILE" 'external RRD storage: an operator-managed NFS/NFSv4 export'
require_text "$CHECKLIST_FILE" 'selected shared RRD storage'
require_text "$READINESS_ASSESSMENT_FILE" 'shared RRD filesystem'
require_text "$README_FILE" 'Ubuntu 22.04, 24.04, 26.04 | Primary'
require_text "$README_FILE" 'Ubuntu 26.04 and RHEL-family 8/9/10 are implemented primary targets'
require_text "$README_FILE" 'Ubuntu 22.04 selects PHP 8.3 from the documented PHP PPA'
require_text "$README_FILE" 'AlmaLinux 8.10+, 9.4+, 10.x | Primary'
require_text "$README_FILE" 'Rocky Linux 8.10+, 9.4+, 10.x | Primary'
require_text "$README_FILE" 'make controller-bootstrap'
require_text "$LAUNCHER_FILE" 'minimum_ansible_core_version="${LIBRENMS_MINIMUM_ANSIBLE_CORE_VERSION:-2.20.0}"'
require_text "$CONTROLLER_BOOTSTRAP_FILE" '--require-hashes'
require_text "$MANAGED_RUNTIME_PLAYBOOK" "ansible_facts.python.executable == '/opt/librenms-ha-ansible/python/bin/python'"
require_text "$MANAGED_RUNTIME_PLAYBOOK" 'ansible.builtin.package:'
require_text "$MANAGED_RUNTIME_PLAYBOOK" 'import command_runner, dotenv, psutil, pymysql, redis, setuptools'
require_text "$MANAGED_RUNTIME_SCRIPT" 'librenms-ha-ansible-controller:local'
require_text "$MANAGED_RUNTIME_SCRIPT" 'PermitRootLogin=yes'
require_text "$MANAGED_RUNTIME_SCRIPT" 'ansible_password:'
require_text "$MANAGED_RUNTIME_SCRIPT" 'chpasswd'
require_text "$MANAGED_RUNTIME_SCRIPT" 'IdentitiesOnly=yes'
require_text "$MANAGED_RUNTIME_SCRIPT" 'PreferredAuthentications=password,publickey'
require_text "$PACKAGE_SMOKE_FILE" 'rocky|almalinux|rhel)'
require_text "$PACKAGE_SMOKE_FILE" '22.04|24.04|26.04'
require_text "$PACKAGE_SMOKE_FILE" 'galera_new_cluster galera_recovery'
require_text "$PACKAGE_SMOKE_FILE" 'get_mariadb_series()'
require_text "$PACKAGE_SMOKE_FILE" '(Distrib|from)'
require_text "$PACKAGE_SMOKE_FILE" 'expected_mariadb_series=10.6'
require_text "$PACKAGE_SMOKE_FILE" 'expected_mariadb_series=11.8'
require_text "$PACKAGE_SMOKE_FILE" '8) minimum_minor=10'
require_text "$PACKAGE_SMOKE_FILE" '9) minimum_minor=4'
require_text "$PACKAGE_SMOKE_FILE" '10) minimum_minor=0'
require_text "$PACKAGE_SMOKE_FILE" 'check_unit()'
require_text "$PACKAGE_SMOKE_FILE" 'check_unit_or_init_script()'
require_text "$PACKAGE_SMOKE_FILE" 'mariadb.service nginx.service'
require_text "$PACKAGE_SMOKE_FILE" 'php8.3-cli php8.3-curl'
require_text "$PACKAGE_SMOKE_FILE" 'epel-release-latest-${major}.noarch.rpm'
require_text "$PACKAGE_SMOKE_FILE" 'codeready-builder|crb'
if grep -Fq 'python3-command-runner' "$PACKAGE_SMOKE_FILE"; then
    printf 'Ubuntu package smoke must use the managed pip runtime for command_runner.\n' >&2
    exit 1
fi
require_text "$MANAGED_RUNTIME_SCRIPT" 'registry.access.redhat.com/*'
require_text "$MANAGED_RUNTIME_SCRIPT" 'registry.redhat.io/*'
require_text "$WORKFLOW_FILE" 'name: ubuntu-22.04'
require_text "$WORKFLOW_FILE" 'name: ubuntu-24.04'
require_text "$WORKFLOW_FILE" 'name: ubuntu-26.04'
require_text "$WORKFLOW_FILE" 'image: rockylinux/rockylinux:8'
require_text "$WORKFLOW_FILE" 'image: rockylinux/rockylinux:9'
require_text "$WORKFLOW_FILE" 'image: rockylinux/rockylinux:10'
require_text "$WORKFLOW_FILE" 'image: almalinux:8'
require_text "$WORKFLOW_FILE" 'image: almalinux:9'
require_text "$WORKFLOW_FILE" 'image: almalinux:10'
require_text "$WORKFLOW_FILE" 'managed-runtime-smoke.sh ubuntu:22.04 3.10 ubuntu-22'
require_text "$WORKFLOW_FILE" 'managed-runtime-smoke.sh ubuntu:24.04 3.12 ubuntu-24'
require_text "$WORKFLOW_FILE" 'managed-runtime-smoke.sh ubuntu:26.04 3.14 ubuntu-26'
require_text "$WORKFLOW_FILE" 'managed-runtime-smoke.sh rockylinux/rockylinux:8 3.11 rocky-8'
require_text "$WORKFLOW_FILE" 'managed-runtime-smoke.sh rockylinux/rockylinux:9 3.9 rocky-9'
require_text "$WORKFLOW_FILE" 'managed-runtime-smoke.sh rockylinux/rockylinux:10 3.12 rocky-10'
require_text "$WORKFLOW_FILE" 'managed-runtime-smoke.sh almalinux:8 3.11 alma-8'
require_text "$WORKFLOW_FILE" 'managed-runtime-smoke.sh almalinux:9 3.9 alma-9'
require_text "$WORKFLOW_FILE" 'managed-runtime-smoke.sh almalinux:10 3.12 alma-10'
require_text "$ROOT_DIR/scripts/ci-ansible-syntax-check.py" 'ANSIBLE_CONFIG'
require_text "$REDIS_SENTINEL_SERVICE_FILE" 'RuntimeDirectory={{ librenms_redis_runtime_user }}'
require_text "$REDIS_SENTINEL_TASK_FILE" 'Inventory Redis nodes:'
require_text "$REDIS_SENTINEL_TASK_FILE" 'Inactive/excluded Redis nodes:'
require_text "$REDIS_SENTINEL_TASKS_FILE" 'Verify Redis or Valkey runtime mapping for Sentinel'
require_text "$REDIS_SENTINEL_TASKS_FILE" 'Verify native Redis or Valkey Sentinel unit exists'
require_text "$REDIS_SENTINEL_TASKS_FILE" '--property=LoadState'
require_text "$REDIS_SENTINEL_TASKS_FILE" 'Fail early when Redis or Valkey Sentinel mapping is incomplete'
require_text "$REDIS_SENTINEL_TASKS_FILE" 'Deploy project-managed Redis Sentinel unit when native unit is unavailable'
require_text "$REDIS_SENTINEL_TASKS_FILE" 'Stop native Redis Sentinel service before project-managed takeover'
require_text "$REDIS_SENTINEL_TASKS_FILE" 'Wait for native Sentinel listener to stop before project-managed takeover'
require_text "$DEFAULTS_FILE" 'librenms_redis_sentinel_allow_custom_service_fallback: true'
require_text "$DEFAULTS_FILE" 'librenms_redis_sentinel_takeover_timeout: 30'
require_text "$GLUSTER_RRD_FILE" "ansible_facts.os_family != 'RedHat'"
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
require_text "$DISPATCHER_OVERRIDE_FILE" "librenms_rrd_mode == 'glusterfs'"
require_text "$DISPATCHER_OVERRIDE_FILE" 'librenms_glusterd_service_name'
require_text "$DISPATCHER_OVERRIDE_FILE" 'librenms_mariadb_service_name'
require_text "$DISPATCHER_OVERRIDE_FILE" 'librenms_haproxy_service_name'
require_text "$SCHEDULER_SERVICE_FILE" "librenms_rrd_mode in ['glusterfs', 'external']"
require_text "$STARTUP_REPAIR_SERVICE_FILE" "librenms_rrd_mode in ['glusterfs', 'external']"

if grep -Fq 'remote-fs.target glusterd.service' "$DISPATCHER_OVERRIDE_FILE"; then
    printf 'The dispatcher override must not require Gluster on external-NFS or local RRD hosts.\n' >&2
    exit 1
fi

rhel8_fallback_files=(
    "$COMMON_TASKS_FILE"
    "$REDHAT_REPOS_FILE"
    "$EXTERNAL_RRD_FILE"
    "$GLUSTER_RRD_FILE"
    "$SELINUX_FILE"
    "$FIREWALLD_FILE"
    "$SYSLOG_FILE"
    "$ROOT_DIR/roles/mariadb/tasks/main.yml"
    "$ROOT_DIR/roles/galera/tasks/main.yml"
    "$ROOT_DIR/roles/redis_sentinel/tasks/main.yml"
    "$ROOT_DIR/roles/haproxy_keepalived/tasks/main.yml"
    "$ROOT_DIR/roles/awx_controller/tasks/main.yml"
)
for rhel8_fallback_file in "${rhel8_fallback_files[@]}"; do
    require_text "$rhel8_fallback_file" 'librenms_rhel8_package_cli_fallback | default(true) | bool'
    require_text "$rhel8_fallback_file" 'dnf'
done

if grep -Fq 'every run first takes a shared GlusterFS' "$OPERATIONS_FILE"; then
    printf 'Operations documentation must describe the selected shared RRD backend, not only GlusterFS.\n' >&2
    exit 1
fi

if grep -Fq 'mounted from GlusterFS and launches a short simultaneous lock probe' "$OPERATIONS_FILE"; then
    printf 'Production-readiness documentation must describe external NFS/NFSv4 storage too.\n' >&2
    exit 1
fi

if grep -Fq "ansible_facts.os_family == 'Debian'" "$POST_REBOOT_FILE"; then
    printf 'Post-reboot convergence must repair managed services on both primary OS families.\n' >&2
    exit 1
fi

rrdcached_runtime_block=$(awk '
    /- name: Check for wildcard rrdcached TCP listener in VIP mode/ { capture=1 }
    capture { print }
    /- name: Enable nginx/ { exit }
' "$LIBRENMS_APP_FILE")
if grep -Fq "ansible_facts.os_family == 'Debian'" <<< "$rrdcached_runtime_block"; then
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
