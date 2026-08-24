#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agent_playbook="$repo_root/cloud-init/ansible/agent.yml"
agent_vars="$repo_root/cloud-init/ansible/vars/agent-vars.example.yml"

# The runtime config baked into cloud-init must match the live-good config that
# was validated in the OpenClaw UI: OpenClaw talks to OpenShell's inference
# route as an OpenAI-compatible completions provider, while oauth2-proxy supplies
# authenticated user identity via trusted-proxy headers.
grep -Fq "'baseUrl': 'https://inference.local/v1'" "$agent_playbook"
grep -Fq "'api': 'openai-completions'" "$agent_playbook"
grep -Fq 'id: "{{ inference_model_cfg }}"' "$agent_playbook"
grep -Fq "reasoning: false" "$agent_playbook"
grep -Fq "openclaw config patch" "$agent_playbook"
grep -Fq "openclaw config unset gateway.auth.token || true" "$agent_playbook"
grep -Fq "'mode': 'trusted-proxy'" "$agent_playbook"
grep -Fq "'userHeader': 'x-forwarded-preferred-username'" "$agent_playbook"
grep -Fq "'requiredHeaders': ['x-forwarded-proto', 'x-forwarded-host']" "$agent_playbook"
grep -Fq "'allowUsers': (openclaw_proxy_allowed_users | mandatory)" "$agent_playbook"
grep -Fq "'allowLoopback': true" "$agent_playbook"
grep -Fq "'trustedProxies': ['127.0.0.1', '::1']" "$agent_playbook"
grep -Fq "'allowedOrigins': [openclaw_route_origin_cfg]" "$agent_playbook"

if grep -Fq "openai-responses" "$agent_playbook"; then
  echo "agent playbook must not bake the failing openai-responses runtime provider for the live OpenClaw gateway" >&2
  exit 1
fi

if grep -Fq "supportsTemperature" "$agent_playbook"; then
  echo "agent playbook still carries responses-style compatibility metadata" >&2
  exit 1
fi

grep -Fq "inference_model: rits/zai-org/glm-5-2-fp8" "$agent_vars"
grep -Fq "inference_provider: glm" "$agent_vars"
grep -Fq 'https://saw-integ.${NS}.svc.cluster.local:18083/v1' "$agent_vars"
grep -Fq 'inference_https_proxy: ""' "$agent_vars"

echo "saw-agent OpenClaw runtime config is baked for the live-good provider and trusted proxy"
