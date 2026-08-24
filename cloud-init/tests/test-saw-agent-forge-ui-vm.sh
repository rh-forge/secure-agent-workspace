#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agent_manifest="$repo_root/cloud-init/kubernetes/agent-server.yml"
forge_route_manifest="$repo_root/cloud-init/kubernetes/agent-forge-ui-route.yml"
agent_vars="$repo_root/cloud-init/ansible/vars/agent-vars.example.yml"
agent_playbook="$repo_root/cloud-init/ansible/agent.yml"
readme="$repo_root/cloud-init/README.md"
tracker="$repo_root/docs/openclaw-saw-demo-alignment-tracker.md"

test -f "$forge_route_manifest" || {
  echo "missing saw-agent Forge UI route manifest: ${forge_route_manifest#$repo_root/}" >&2
  exit 1
}

grep -Fq 'name: forgeui' "$agent_manifest"
grep -Fq 'port: 18090' "$agent_manifest"

grep -Fq 'kind: Route' "$forge_route_manifest"
grep -Fq 'name: saw-agent-forge-ui' "$forge_route_manifest"
grep -Fq 'host: saw-agent-forge-ui.${NS}.dal.dev.cirrus.ibm.com' "$forge_route_manifest"
grep -Fq 'targetPort: forgeui' "$forge_route_manifest"
grep -Fq 'name: saw-agent' "$forge_route_manifest"

grep -Fq 'forge_ui_enabled: true' "$agent_vars"
grep -Fq 'forge_ui_port: 18090' "$agent_vars"
grep -Fq 'forge_ui_container_port: 8080' "$agent_vars"
grep -Fq 'forge_ui_image: "quay.io/rcook/rh-forge-ui:demo1-amd64"' "$agent_vars"

grep -Fq 'forge_ui_enabled_cfg: "{{ forge_ui_enabled | default(false) }}"' "$agent_playbook"
grep -Fq 'forge_ui_port_cfg: "{{ forge_ui_port | default(18090) }}"' "$agent_playbook"
grep -Fq 'forge_ui_image_cfg: "{{ forge_ui_image | default(\"\") }}"' "$agent_playbook"
grep -Fq 'dest: "{{ user_home }}/.local/bin/start-forge-ui"' "$agent_playbook"
grep -Fq 'podman pull "{{ forge_ui_image_cfg }}"' "$agent_playbook"
grep -Fq 'podman run --rm --name forge-ui' "$agent_playbook"
grep -Fq -- '-p 0.0.0.0:{{ forge_ui_port_cfg }}:{{ forge_ui_container_port_cfg }}' "$agent_playbook"
grep -Fq 'dest: "{{ user_home }}/.config/systemd/user/forge-ui.service"' "$agent_playbook"
grep -Fq 'ExecStart=%h/.local/bin/start-forge-ui' "$agent_playbook"
grep -Fq 'Wait for Forge UI readiness' "$agent_playbook"
grep -Fq 'http://127.0.0.1:{{ forge_ui_port_cfg }}/' "$agent_playbook"

grep -Fq 'kubernetes/agent-forge-ui-route.yml' "$readme"
grep -Fq 'quay.io/rcook/rh-forge-ui:demo1-amd64' "$readme"
grep -Fq 'saw-agent-forge-ui.<namespace>.dal.dev.cirrus.ibm.com' "$readme"
grep -Fq 'VM-hosted Forge UI' "$tracker"

if grep -Eq 'forge-secrets|FORGE_GATEWAY_TOKEN|rh-forge-ui-relay|name: relay|name: injector' "$agent_playbook" "$forge_route_manifest" "$agent_manifest"; then
  echo "VM-hosted Forge UI preview must not deploy relay, injector, or gateway tokens" >&2
  exit 1
fi

echo "saw-agent VM-hosted Forge UI preview is configured"
