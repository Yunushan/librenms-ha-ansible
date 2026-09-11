#!/usr/bin/env bash

compose_pull_images_with_retry() {
    local max_attempts="${COMPOSE_PULL_RETRY_ATTEMPTS:-4}"
    local retry_delay="${COMPOSE_PULL_RETRY_DELAY_SECONDS:-5}"
    local image
    local attempt
    local -a images

    case "${max_attempts}" in
        ''|*[!0-9]*|0)
            printf 'COMPOSE_PULL_RETRY_ATTEMPTS must be a positive integer.\n' >&2
            return 2
            ;;
    esac
    case "${retry_delay}" in
        ''|*[!0-9]*)
            printf 'COMPOSE_PULL_RETRY_DELAY_SECONDS must be a non-negative integer.\n' >&2
            return 2
            ;;
    esac

    mapfile -t images < <(compose config --images | sort -u)
    if [ "${#images[@]}" -eq 0 ]; then
        printf 'Docker Compose did not resolve any integration-test images.\n' >&2
        return 1
    fi

    for image in "${images[@]}"; do
        for ((attempt = 1; attempt <= max_attempts; attempt++)); do
            if docker pull "${image}"; then
                break
            fi

            if ((attempt == max_attempts)); then
                printf 'Failed to pull %s after %s attempts.\n' \
                    "${image}" "${max_attempts}" >&2
                return 1
            fi

            printf 'Pulling %s failed (attempt %s/%s); retrying in %ss.\n' \
                "${image}" "${attempt}" "${max_attempts}" "${retry_delay}" >&2
            sleep "${retry_delay}"
        done
    done
}
