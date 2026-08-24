#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agent_playbook="$repo_root/cloud-init/ansible/agent.yml"

grep -Fq 'openclaw_forward_port_cfg: 18788' "$agent_playbook"
grep -Fq -- '--port {{ openclaw_forward_port_cfg }} \' "$agent_playbook"
grep -Fq 'ExecStart=/usr/local/bin/openshell forward start 127.0.0.1:{{ openclaw_forward_port_cfg }} {{ sandbox_name }}' "$agent_playbook"
grep -Fq 'OAUTH2_PROXY_HTTP_ADDRESS=0.0.0.0:{{ openclaw_proxy_port_cfg }}' "$agent_playbook"
grep -Fq 'OAUTH2_PROXY_UPSTREAMS=http://127.0.0.1:{{ openclaw_forward_port_cfg }}' "$agent_playbook"
grep -Fq 'openclaw_home_host_path: "{{ user_home }}/.local/share/openshell/openclaw-home"' "$agent_playbook"
grep -Fq 'enable_bind_mounts = true' "$agent_playbook"
grep -Fq 'Ensure persistent OpenClaw home exists' "$agent_playbook"
grep -Fq 'mode: "0777"' "$agent_playbook"
grep -Fq -- '--driver-config-json "${driver_config_json}" \' "$agent_playbook"
grep -Fq '"source":"{{ openclaw_home_host_path }}"' "$agent_playbook"
grep -Fq '"target":"/sandbox/.openclaw"' "$agent_playbook"
grep -Fq '"selinux_label":"shared"' "$agent_playbook"

if grep -Fq 'openclaw_proxy_bind_ip.stdout' "$agent_playbook"; then
  echo "agent playbook still depends on a discovered VM IP for OpenClaw proxy binding" >&2
  exit 1
fi

grep -Fq 'dest: "{{ user_home }}/.local/bin/ensure-openclaw-sandbox"' "$agent_playbook"
grep -Fq 'ExecStart=%h/.local/bin/ensure-openclaw-sandbox' "$agent_playbook"
grep -Fq 'sandbox_state="$(' "$agent_playbook"
grep -Fq 'if [ "${sandbox_state}" = "Ready" ]; then' "$agent_playbook"
grep -Fq '/usr/local/bin/openshell sandbox delete {{ sandbox_name }}' "$agent_playbook"
grep -Fq 'OpenShell gateway was not ready after waiting for sandbox list' "$agent_playbook"
grep -Fq 'for attempt in $(/usr/bin/seq 1 30); do' "$agent_playbook"
grep -Fq 'openshell-default--{{ sandbox_name }}-' "$agent_playbook"
grep -Fq '/usr/bin/podman ps -a --format' "$agent_playbook"
grep -Fq 'for attempt in $(/usr/bin/seq 1 3); do' "$agent_playbook"
grep -Fq 'exec /usr/local/bin/openshell sandbox create \' "$agent_playbook"
grep -Fq -- '--name {{ sandbox_name }} \' "$agent_playbook"

if grep -Fq 'ExecStart=/usr/bin/bash -lc' "$agent_playbook"; then
  echo "sandbox state machine should live in a script, not inline systemd ExecStart shell" >&2
  exit 1
fi

grep -Fq 'Start openclaw services' "$agent_playbook"
grep -Fq 'failed_when: false' "$agent_playbook"
grep -Fq 'Verify openclaw services are active' "$agent_playbook"
grep -Fq 'systemctl --user is-active' "$agent_playbook"

echo "saw-agent OpenClaw listener split is configured"
