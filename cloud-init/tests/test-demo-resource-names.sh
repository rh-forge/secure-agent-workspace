#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agent_manifest="$repo_root/cloud-init/kubernetes/agent-server.yml"
integrations_manifest="$repo_root/cloud-init/kubernetes/integrations-server.yml"
agent_route_manifest="$repo_root/cloud-init/kubernetes/agent-userport-route.yml"
agent_vars="$repo_root/cloud-init/ansible/vars/agent-vars.example.yml"
integrations_vars="$repo_root/cloud-init/ansible/vars/integrations-vars.example.yml"
agent_playbook="$repo_root/cloud-init/ansible/agent.yml"
site_playbook="$repo_root/cloud-init/ansible/site.yml"
features_dir="$repo_root/cloud-init/features"
readme="$repo_root/cloud-init/README.md"

for path in "$agent_manifest" "$integrations_manifest" "$agent_route_manifest" "$agent_vars" "$integrations_vars"; do
  test -f "$path" || {
    echo "missing expected demo asset: ${path#$repo_root/}" >&2
    exit 1
  }
done

grep -Fq 'name: saw-agent' "$agent_manifest"
grep -Fq 'hostname: saw-agent' "$agent_manifest"
grep -Fq 'app.kubernetes.io/component: saw-agent' "$agent_manifest"
grep -Fq 'secretName: saw-agent-vars' "$agent_manifest"
grep -Fq 'serial: SAWAGENTSTATE' "$agent_manifest"
grep -Fq 'serial: SAWAGENTASSETS' "$agent_manifest"
grep -Fq 'claimName: saw-agent-state-persist' "$agent_manifest"
grep -Fq 'claimName: saw-agent-assets-persist' "$agent_manifest"

grep -Fq 'kind: Route' "$agent_route_manifest"
grep -Fq 'name: saw-agent-userport' "$agent_route_manifest"
grep -Fq 'app.kubernetes.io/component: saw-agent' "$agent_route_manifest"
grep -Fq 'host: saw-agent-userport.${NS}.dal.dev.cirrus.ibm.com' "$agent_route_manifest"
grep -Fq 'name: saw-agent' "$agent_route_manifest"
grep -Fq 'targetPort: userport' "$agent_route_manifest"

grep -Fq 'name: saw-integ' "$integrations_manifest"
grep -Fq 'hostname: saw-integ' "$integrations_manifest"
grep -Fq 'app.kubernetes.io/component: saw-integ' "$integrations_manifest"
grep -Fq 'secretName: saw-integ-vars' "$integrations_manifest"
grep -Fq 'serial: SAWINTEGPERSIST' "$integrations_manifest"
grep -Fq 'claimName: saw-integ-persist' "$integrations_manifest"

grep -Fq 'hostname: saw-agent' "$agent_vars"
if ! grep -Fq 'sandbox_name: openclaw-saw' "$agent_vars"; then
  echo "saw-agent vars must use the OpenClaw SAW demo sandbox name openclaw-saw" >&2
  exit 1
fi
grep -Fq 'hostname: saw-integ' "$integrations_vars"
grep -Fq 'https://saw-integ.${NS}.svc.cluster.local:18083/v1' "$agent_vars"

grep -Fq 'SAWAGENTSTATE' "$agent_playbook"
grep -Fq 'SAWAGENTASSETS' "$agent_playbook"
grep -Fq 'SAWINTEGPERSIST' "$site_playbook"
grep -Fq 'saw-agent' "$readme"
grep -Fq 'saw-integ' "$readme"

if grep -R 'feat/two-persist-pvc' "$agent_manifest" "$integrations_manifest"; then
  echo "cloud-init still bootstraps from the known-good PVC branch instead of the clean demo branch" >&2
  exit 1
fi

if grep -R -E \
  --exclude='test-demo-resource-names.sh' \
  'one-userport|one-state-persist|one-assets-persist|two-persist|one-vars|two-vars|two-vm|one-vm|VM one|VM two|Server one|Server two|Service/one|Service/two|vmi/one|vmi/two|svc/one|svc/two|ONESTATE|ONEASSETS|TWOPERSIST|one_|two_|_one|_two' \
  "$repo_root/cloud-init"; then
  echo "demo assets still contain stale one/two resource names" >&2
  exit 1
fi

if grep -R -E \
  --exclude='test-demo-resource-names.sh' \
  'sandbox_name: sawone|sandbox=sawone|\\bsawone\\b' \
  "$repo_root/cloud-init"; then
  echo "demo assets still contain the pre-demo OpenClaw sandbox name" >&2
  exit 1
fi

echo "OpenClaw SAW demo resource names are configured"
