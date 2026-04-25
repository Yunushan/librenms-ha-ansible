#!/usr/bin/env python3
"""Local inventory sanity checks before running Ansible against hosts."""

from __future__ import annotations

import argparse
import ipaddress
import sys
from pathlib import Path
from typing import Any

import yaml


DEFAULT_PLACEHOLDERS = (
    "CHANGE_ME",
    "example.com",
    "public",
)

MANAGED_GROUPS = (
    "librenms_nodes",
    "librenms_web",
    "librenms_db",
    "librenms_redis",
    "lb_nodes",
    "gluster_nodes",
)


def load_yaml(path: Path) -> dict[str, Any]:
    if not path.exists():
        raise FileNotFoundError(path)
    with path.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}
    if not isinstance(data, dict):
        raise ValueError(f"{path} did not contain a YAML mapping")
    return data


def children_root(inventory: dict[str, Any]) -> dict[str, Any]:
    return inventory.get("all", {}).get("children", {})


def group_definition(inventory: dict[str, Any], group: str) -> dict[str, Any]:
    return children_root(inventory).get(group, {})


def group_hosts(inventory: dict[str, Any], group: str) -> list[str]:
    hosts = group_definition(inventory, group).get("hosts", {})
    if isinstance(hosts, dict):
        return list(hosts.keys())
    if isinstance(hosts, list):
        return list(hosts)
    return []


def host_vars(inventory: dict[str, Any], host: str) -> dict[str, Any]:
    for group in children_root(inventory).values():
        hosts = group.get("hosts", {}) if isinstance(group, dict) else {}
        if isinstance(hosts, dict) and host in hosts:
            return hosts.get(host) or {}
    return {}


def var_bool(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    return str(value).strip().lower() in {"1", "yes", "true", "on"}


def var_int(value: Any, default: int = 0) -> int:
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return default


def active_hosts(inventory: dict[str, Any], group: str) -> list[str]:
    inactive = set(group_hosts(inventory, "decommission_nodes"))
    inactive.update(group_hosts(inventory, "maintenance_nodes"))
    return [host for host in group_hosts(inventory, group) if host not in inactive]


def managed_hosts(inventory: dict[str, Any]) -> list[str]:
    hosts: list[str] = []
    for group in MANAGED_GROUPS:
        hosts.extend(active_hosts(inventory, group))
    return list(dict.fromkeys(hosts))


def has_placeholder(value: Any, placeholders: tuple[str, ...]) -> bool:
    rendered = str(value)
    return any(marker in rendered for marker in placeholders)


def add_placeholder_errors(
    errors: list[str],
    vars_data: dict[str, Any],
    allow_placeholders: bool,
) -> None:
    if allow_placeholders:
        return

    checked_names = (
        "librenms_app_key",
        "librenms_fqdn",
        "librenms_db_password",
        "librenms_redis_password",
        "librenms_redis_sentinel_password",
        "librenms_keepalived_auth_pass",
        "librenms_snmp_v2c_community",
        "librenms_snmp_v3_users",
    )
    bad = [
        name
        for name in checked_names
        if has_placeholder(vars_data.get(name, ""), DEFAULT_PLACEHOLDERS)
    ]
    if bad:
        errors.append("replace placeholder values: " + ", ".join(bad))


def validate_inventory(
    inventory: dict[str, Any],
    vars_data: dict[str, Any],
    allow_placeholders: bool,
) -> list[str]:
    errors: list[str] = []
    hosts = managed_hosts(inventory)

    if not active_hosts(inventory, "librenms_nodes"):
        errors.append("librenms_nodes must contain at least one active host")

    addresses = [
        str(host_vars(inventory, host).get("ansible_host", host))
        for host in hosts
    ]
    duplicate_addresses = sorted(
        {address for address in addresses if addresses.count(address) > 1}
    )
    if duplicate_addresses:
        errors.append("duplicate ansible_host values: " + ", ".join(duplicate_addresses))

    node_ids = [
        str(host_vars(inventory, host).get("librenms_node_id", host))
        for host in active_hosts(inventory, "librenms_nodes")
    ]
    duplicate_node_ids = sorted({node_id for node_id in node_ids if node_ids.count(node_id) > 1})
    if duplicate_node_ids:
        errors.append("duplicate librenms_node_id values: " + ", ".join(duplicate_node_ids))

    mode = str(vars_data.get("librenms_mode", "standalone"))
    vip_enabled = var_bool(vars_data.get("librenms_vip_enabled", False))
    vip_ip = str(vars_data.get("librenms_vip_ip", "")).strip()

    if mode == "ha":
        web_hosts = active_hosts(inventory, "librenms_web") or active_hosts(
            inventory,
            "librenms_nodes",
        )
        if len(active_hosts(inventory, "librenms_nodes")) < 2:
            errors.append("HA mode expects at least two librenms_nodes")
        if len(web_hosts) < 2:
            errors.append("HA mode expects at least two web-capable nodes")
        if len(active_hosts(inventory, "lb_nodes")) < 2:
            errors.append("HA mode expects at least two lb_nodes")
        if not vip_enabled or not vip_ip:
            errors.append("HA mode expects librenms_vip_enabled=true and librenms_vip_ip")

    if vip_ip:
        try:
            ipaddress.ip_address(vip_ip)
        except ValueError:
            errors.append(f"librenms_vip_ip is not a valid IP address: {vip_ip}")
        if vip_ip in addresses:
            errors.append("librenms_vip_ip must not equal any node ansible_host")

    if str(vars_data.get("librenms_db_mode", "local")) == "galera":
        if len(active_hosts(inventory, "librenms_db")) < 3:
            errors.append("Galera mode expects at least three librenms_db hosts")

    if str(vars_data.get("librenms_redis_mode", "local")) == "sentinel":
        redis_hosts = active_hosts(inventory, "librenms_redis")
        redis_quorum = var_int(vars_data.get("librenms_redis_quorum", 2), 2)
        if len(redis_hosts) < 3:
            errors.append("Redis Sentinel mode expects at least three librenms_redis hosts")
        if redis_quorum < 2 or redis_quorum > len(redis_hosts):
            errors.append(
                "librenms_redis_quorum must be at least 2 and no larger than "
                "the active Redis node count",
            )

    if str(vars_data.get("librenms_rrd_mode", "local")) == "glusterfs":
        if len(active_hosts(inventory, "gluster_nodes")) < 3:
            errors.append("GlusterFS RRD mode expects at least three gluster_nodes")

    vip_cidr = var_int(vars_data.get("librenms_vip_cidr", 24), 24)
    if vip_cidr < 1 or vip_cidr > 32:
        errors.append("librenms_vip_cidr must be between 1 and 32")

    vrid = var_int(vars_data.get("librenms_keepalived_vrid", 51), 51)
    if vrid < 1 or vrid > 255:
        errors.append("librenms_keepalived_vrid must be between 1 and 255")

    if vip_enabled:
        auth_pass = str(vars_data.get("librenms_keepalived_auth_pass", ""))
        skip_placeholder_length = allow_placeholders and has_placeholder(
            auth_pass,
            DEFAULT_PLACEHOLDERS,
        )
        if not skip_placeholder_length and (len(auth_pass) < 1 or len(auth_pass) > 8):
            errors.append("librenms_keepalived_auth_pass must be 1-8 characters")

    add_placeholder_errors(errors, vars_data, allow_placeholders)
    return errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--inventory",
        default="inventories/ha/hosts.yml",
        type=Path,
        help="inventory YAML file to validate",
    )
    parser.add_argument(
        "--group-vars",
        default="inventories/ha/group_vars/all.yml",
        type=Path,
        help="group_vars/all.yml file to validate with the inventory",
    )
    parser.add_argument(
        "--allow-placeholders",
        action="store_true",
        help="allow CHANGE_ME/example placeholder values",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    inventory = load_yaml(args.inventory)
    vars_data = load_yaml(args.group_vars)
    errors = validate_inventory(inventory, vars_data, args.allow_placeholders)

    if errors:
        print("Inventory validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(f"Inventory validation passed: {args.inventory}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
