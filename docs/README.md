# Documentation Index

Use this page as the first stop for operator and maintainer documentation.

## Recommended Reading Order

1. [Architecture and Operating Model](architecture.md) - cluster roles, traffic flow, HA boundaries, and why the automation is conservative around stateful services.
2. [Support Matrix and Production Readiness](support-matrix.md) - supported distro tiers, production gates, known limits, and expected behavior during node loss.
3. [LibreNMS HA Operations Runbook](operations.md) - first deployment, convergence, validation, backups, maintenance, full restart, failover drills, and OS upgrades.
4. [LibreNMS HA Command Map](command-map.md) - which playbook or Make target to run for common tasks and symptoms.
5. [LibreNMS HA Operator Checklists](operator-checklists.md) - copyable checklists for maintenance, hard power-off testing, restart validation, and incident triage.
6. [Failure Scenario Runbook](failure-scenarios.md) - targeted troubleshooting for VIP, Galera, Redis Sentinel, GlusterFS, LibreNMS dispatcher, and validation failures.

## Task Map

| Task | Start here |
|---|---|
| Understand the HA design | [Architecture and Operating Model](architecture.md) |
| Check whether a distro is production-ready | [Support Matrix and Production Readiness](support-matrix.md) |
| Deploy or rerun the cluster safely | [LibreNMS HA Operations Runbook](operations.md) |
| Choose the correct command | [LibreNMS HA Command Map](command-map.md) |
| Shut down one node intentionally | [LibreNMS HA Operator Checklists](operator-checklists.md) |
| Recover from failed validation | [Failure Scenario Runbook](failure-scenarios.md) |
| Add or remove capacity | [Scaling and Lifecycle](scaling.md) |
| Run the project in containers | [Docker Support](docker.md) |
| Use AWX instead of the CLI | [Optional AWX Controller](awx-controller.md) |
| Prepare a project release | [Maintainer Release Checklist](release-checklist.md) |

## Operator Runbooks

- [LibreNMS HA Operations Runbook](operations.md)
- [LibreNMS HA Command Map](command-map.md)
- [LibreNMS HA Operator Checklists](operator-checklists.md)
- [Failure Scenario Runbook](failure-scenarios.md)

## Platform And Lifecycle

- [Support Matrix and Production Readiness](support-matrix.md)
- [Scaling and Lifecycle](scaling.md)
- [Docker Support](docker.md)
- [Optional AWX Controller](awx-controller.md)

## Maintainer Docs

- [Maintainer Release Checklist](release-checklist.md)

