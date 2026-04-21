# Support Matrix

## Upstream install examples vs this repository

Upstream LibreNMS documentation currently publishes package/install examples for:

- Ubuntu 24.04
- Ubuntu 22.04
- Debian 12
- Debian 13
- CentOS 8

This repository extends beyond that with family mappings and override-friendly variables.

## Tiers

### Primary
These are the cleanest paths for most users.

- Ubuntu
- Debian

### Primary-ish
These usually work through the same family logic.

- Linux Mint

### Strong best-effort
Good family-level fit, but still verify in lab.

- AlmaLinux
- Rocky Linux
- Fedora

### Best-effort
Supported by package/service mappings in this repo, but expect some distro-specific adjustment.

- CentOS / CentOS Stream
- Arch Linux
- Manjaro Linux
- Alpine Linux
- Gentoo

## What to override first if your distro differs

- package lists
- PHP-FPM service name
- Redis service name
- Redis sentinel service behavior on non-systemd hosts
- MariaDB config path
- SNMP persistent config path

## Optional AWX controller

The optional AWX controller path is best tested on a dedicated Ubuntu or Debian controller VM. The default role path installs k3s and then deploys AWX through the upstream AWX Operator.

Other Linux families may work if k3s and `kubectl` are available, but treat them as best-effort until validated in a lab.
