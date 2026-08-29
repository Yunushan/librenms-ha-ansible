# Kubernetes LibreNMS Profile

This directory contains values examples for the optional Helm chart at
`charts/librenms-ha`. The chart runs LibreNMS web and dispatcher workloads; it
expects MariaDB/Galera, Redis/Sentinel, a Secret, and shared RRD-capable
storage to be supplied by the cluster operator.

Copy the production example outside the repository, replace all placeholder
values, create the referenced Secret, and run the chart through
`playbooks/kubernetes.yml` or the provider-specific application target. Never
commit production passwords, kubeconfigs, image credentials, or example
placeholder digests.
