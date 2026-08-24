#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
agent_playbook="$repo_root/cloud-init/ansible/agent.yml"
agent_vars="$repo_root/cloud-init/ansible/vars/agent-vars.example.yml"
integration_vars="$repo_root/cloud-init/ansible/vars/integrations-vars.example.yml"
readme="$repo_root/cloud-init/README.md"

# GLM is exposed to OpenClaw as its own logical provider/model while still using
# OpenAI-compatible chat/completions transport through the saw-integ proxy.
grep -Fq "glm:" "$agent_playbook"
grep -Fq "type: openai" "$agent_playbook"
grep -Fq "'providers': {" "$agent_playbook"
grep -Fq "inference_provider_cfg: {" "$agent_playbook"
grep -Fq "'primary': inference_provider_cfg ~ '/' ~ inference_model_cfg" "$agent_playbook"
grep -Fq "'api': 'openai-completions'" "$agent_playbook"
grep -Fq "'baseUrl': 'https://inference.local/v1'" "$agent_playbook"
grep -Fq "'rits/zai-org/glm-5-2-fp8':" "$agent_playbook"

grep -Fq -- "--custom-provider-id \"{{ inference_provider_cfg }}\"" "$agent_playbook"
grep -Fq -- "--custom-compatibility openai" "$agent_playbook"

if grep -Fq "sk-iv7934" "$repo_root/cloud-init"; then
  echo "GLM provider key must not be committed" >&2
  exit 1
fi

grep -Fq "inference_provider: glm" "$agent_vars"
grep -Fq "inference_model: rits/zai-org/glm-5-2-fp8" "$agent_vars"
grep -Fq 'https://saw-integ.${NS}.svc.cluster.local:18083/v1' "$agent_vars"
grep -Fq 'inference_https_proxy: ""' "$agent_vars"

grep -Fq "integration_proxy_upstream_url: https://ete-litellm.ai-models.vpc.res.ibm.com/v1" "$integration_vars"
grep -Fq "integration_proxy_openai_key: \"\"" "$integration_vars"

grep -Fq "OpenAI-compatible provider API key" "$readme"
grep -Fq "integration_proxy_openai_key" "$readme"
grep -Fq "rits/zai-org/glm-5-2-fp8" "$readme"
grep -Fq "ete-litellm.ai-models.vpc.res.ibm.com" "$readme"

echo "saw-agent GLM runtime config is baked without committing provider credentials"
