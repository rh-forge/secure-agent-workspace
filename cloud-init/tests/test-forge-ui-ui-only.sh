#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
manifest="$repo_root/cloud-init/kubernetes/forge-ui-ui-only.yml"
readme="$repo_root/cloud-init/README.md"
tracker="$repo_root/docs/openclaw-saw-demo-alignment-tracker.md"

test -f "$manifest" || {
  echo "missing Forge UI-only manifest: ${manifest#$repo_root/}" >&2
  exit 1
}

grep -Fq 'kind: Deployment' "$manifest"
grep -Fq 'name: rh-forge-ui' "$manifest"
grep -Fq 'app.kubernetes.io/component: forge-ui' "$manifest"
grep -Fq 'component: ui-only' "$manifest"
grep -Fq 'image-registry.openshift-image-registry.svc:5000/${NS}/rh-forge-ui:demo1' "$manifest"
grep -Fq 'containerPort: 8080' "$manifest"
grep -Fq 'name: ui-http' "$manifest"
grep -Fq 'readinessProbe:' "$manifest"
grep -Fq 'livenessProbe:' "$manifest"
grep -Fq 'automountServiceAccountToken: false' "$manifest"
grep -Fq 'allowPrivilegeEscalation: false' "$manifest"
grep -Fq 'runAsNonRoot: true' "$manifest"
grep -Fq 'seccompProfile:' "$manifest"
grep -Fq 'drop:' "$manifest"
grep -Fq 'kind: Service' "$manifest"
grep -Fq 'type: ClusterIP' "$manifest"
grep -Fq 'kind: Route' "$manifest"
grep -Fq 'host: rh-forge-ui.${NS}.dal.dev.cirrus.ibm.com' "$manifest"
grep -Fq 'termination: edge' "$manifest"

if grep -Eq 'name: (relay|openclaw|injector)|forge-secrets|OPENCLAW_GATEWAY|FORGE_RELAY|OPENCLAW_URL|GATEWAY_TOKEN' "$manifest"; then
  echo "Forge UI-only manifest must not deploy relay, OpenClaw, injector, or gateway secrets" >&2
  exit 1
fi

grep -Fq 'forge-ui-ui-only.yml' "$readme"
grep -Fq 'rh-forge-ui.<namespace>.dal.dev.cirrus.ibm.com' "$readme"
grep -Fq 'UI-only Forge route' "$tracker"

echo "Forge UI-only side-by-side route is configured"
