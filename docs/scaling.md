# Scaling and Lifecycle

## Add an app node

1. add the host to the right groups
2. give it a unique `librenms_node_id`
3. keep the same `librenms_app_key`
4. run `playbooks/add-node.yml`

## Remove an app node

1. move the host out of active groups
2. add it to `decommission_nodes`
3. run `playbooks/remove-node.yml`

## Storage warning

If your RRD layer is Gluster-backed, storage membership changes are intentionally not made “one-click easy”.
That is a design choice.
