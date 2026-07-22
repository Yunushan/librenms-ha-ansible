# CI Dependency Lock

`requirements-ci.in` declares the three direct Python tools used by the CI
quality gates. `requirements-ci.txt` is the generated, fully pinned lock file
and includes SHA-256 hashes for every transitive package artifact.

GitHub Actions and the Ansible controller image install only
`requirements-ci.txt` with `--require-hashes`. The Python smoke checks reject a
lock that is missing hashes or no longer matches the direct pins.

## Refreshing the lock

Use a disposable Python 3.12 virtual environment, review the resulting diff,
then run the full quality gate:

```bash
python3.12 -m venv .venv-lock
. .venv-lock/bin/activate
python -m pip install --upgrade pip pip-tools
pip-compile --generate-hashes --resolver=backtracking --strip-extras \
  --output-file requirements-ci.txt requirements-ci.in
python -m pip install --require-hashes --requirement requirements-ci.txt
make ci
```

Do not edit `requirements-ci.txt` by hand. Change the direct version pin in
`requirements-ci.in`, regenerate the lock, and review every dependency or hash
change before merging.

## Integration container images

The HAProxy web and Redis Sentinel integration Compose files pin their official
container images by both version tag and immutable manifest digest. The
three-node MariaDB Galera integration uses the same policy. This keeps the
integration environment reproducible even if a registry tag is republished.
The Galera fixture uses the image-provided MariaDB backup SST method, avoiding
an unpinned external transfer utility.

When intentionally upgrading one of those images, resolve its multi-platform
manifest digest from the registry, update the tag and digest together, and run
`make ci`. The production-safety check rejects a missing or unexpected digest.
