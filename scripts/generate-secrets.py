#!/usr/bin/env python3
"""Generate a simple YAML snippet with strong random secrets for this repo."""

import base64
import os
import secrets
import string


def rand(length: int = 32) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


def laravel_key() -> str:
    return "base64:" + base64.b64encode(os.urandom(32)).decode("ascii")


print(f'librenms_app_key: "{laravel_key()}"')
print(f'librenms_db_password: "{rand(28)}"')
print(f'librenms_redis_password: "{rand(28)}"')
print(f'librenms_redis_sentinel_password: "{rand(28)}"')
print(f'librenms_keepalived_auth_pass: "{rand(16)}"')
print(f'librenms_snmp_v2c_community: "{rand(20)}"')
print("librenms_snmp_v3_users:")
print("  - username: lnmsv3")
print('    auth_protocol: "SHA"')
print(f'    auth_password: "{rand(20)}"')
print('    priv_protocol: "AES"')
print(f'    priv_password: "{rand(20)}"')
print('    access: "ro"')
