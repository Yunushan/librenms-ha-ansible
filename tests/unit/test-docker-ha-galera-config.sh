#!/usr/bin/env bash
set -euo pipefail

readonly ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly SOURCE_DIR="${ROOT_DIR}/examples/docker-ha/mariadb-galera"
temporary_dir=""

fail() {
    printf 'Docker Galera example configuration test failed: %s\n' "$1" >&2
    exit 1
}

require_docker_compose() {
    command -v docker >/dev/null 2>&1 || fail 'Docker CLI is required.'
    docker compose version >/dev/null 2>&1 || fail 'Docker Compose v2 is required.'
}

cleanup() {
    [ -z "${temporary_dir}" ] || rm -rf "${temporary_dir}"
}

main() {
    local error_output

    require_docker_compose
    temporary_dir="$(mktemp -d)"
    trap cleanup EXIT
    cp "${SOURCE_DIR}/compose.yml" "${SOURCE_DIR}/.env.example" "${temporary_dir}/"
    cp "${temporary_dir}/.env.example" "${temporary_dir}/.env"
    sed -i '/^MARIADB_GALERA_IMAGE=/d' "${temporary_dir}/.env"

    error_output="${temporary_dir}/missing-image.err"
    if docker compose --project-directory "${temporary_dir}" config >/dev/null 2>"${error_output}"; then
        fail 'Compose accepted a missing Galera image value.'
    fi
    grep -Fq 'MARIADB_GALERA_IMAGE' "${error_output}" ||
        fail 'Compose did not explain that MARIADB_GALERA_IMAGE is required.'

    cat >>"${temporary_dir}/.env" <<'EOF'
MARIADB_GALERA_IMAGE=registry.example.com/mariadb-galera@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
EOF
    docker compose --project-directory "${temporary_dir}" config --quiet

    printf 'Docker Galera example configuration test passed.\n'
}

main "$@"
