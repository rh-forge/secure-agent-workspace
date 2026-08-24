#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agent_manifest="$repo_root/cloud-init/kubernetes/agent-server.yml"
debug_server="$repo_root/cloud-init/files/saw-provision-debug-server.py"
kubernetes_dir="$repo_root/cloud-init/kubernetes"

grep -Fq 'name: provisionlog' "$agent_manifest"
grep -Fq 'port: 18080' "$agent_manifest"
grep -Fq 'saw-provision-debug-server' "$agent_manifest"
grep -Fq 'saw-provision-log-http.service' "$agent_manifest"
grep -Fq '/var/log/saw-provision.log' "$debug_server"
grep -Fq 'sk-<redacted>' "$debug_server"
grep -Fq 'PRIVATE KEY' "$debug_server"

if rg -n 'provisionlog|18080|saw-provision-log-http' "$kubernetes_dir" --glob '*route*.yml'; then
  echo "saw-agent provisioning diagnostics must not be exposed through an OpenShift Route" >&2
  exit 1
fi

echo "saw-agent provisioning diagnostics are available only through the internal service port"
