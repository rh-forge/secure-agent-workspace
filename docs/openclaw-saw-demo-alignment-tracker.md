# OpenClaw SAW demo alignment tracker

This file tracks the gap between this Secure Agent Workspace branch and the
`rh-forge/openclaw-saw-demo` deployment flow. Keep it boring and current:
when a step is verified, check it off or remove it, then commit the update.

## Source refresh

- Upstream reference checkout: `/Users/rcook/git/openclaw-saw-demo`
- Refreshed from `origin/main`: 2026-08-21
- Original upstream commit inspected: `562bd25` (`forwarder files`)
- Latest upstream workstream inspected: PR #6, local branch
  `pr-6-openclaw-saw-demo`, head `ea29d0d`
  (`fix(demo): support clean-room updates from macOS`)
- Source files reviewed:
  - `README.md`
  - `docs/components-and-images.md`
  - `docs/credentials.md`
  - `docs/inference.md`
  - `docs/restart-recovery.md`
  - `docs/troubleshooting.md`
  - `demo.env.example`

## PR #6 deltas to account for

PR #6 changes the target from the older two-VM README into a stricter
`demo-1` clean-room reproduction flow:

- Demo images are selected with `:demo1` tags, imported into the OpenShift
  internal registry, and resolved to immutable digests before use.
- The normal path imports seven credential-free runtime/proxy images from
  `quay.io/redhat-et/*:demo1`; only Forge UI and Forge relay are built
  in-cluster.
- OpenShell gateway, supervisor, and CLI are pinned to `0.0.110` and verified
  on both VMs after setup.
- OpenAI-compatible inference moves behind Gateway B / the integrations VM on
  port `18086`; the agent receives only an opaque inter-VM capability.
- The integrations VM now has seven explicit service ports:
  - `18080` Gmail read
  - `18081` Gmail write
  - `18082` M365 read
  - `18083` M365 write
  - `18084` Slack read
  - `18085` Slack user write
  - `18086` OpenAI-compatible inference
- Gmail tooling inside OpenClaw uses agent loopback `127.0.0.1:18079`.
- OpenClaw receives read capabilities, inference, and Forge ingest only. It
  must not receive provider write tokens, writer binaries, write providers, or
  routes to write-service ports.
- The OpenClaw image includes the Chief of Staff workspace and daily-briefing
  skill for backend ID `default`.
- Restart recovery is now a first-class requirement using user-level recovery
  targets/services and post-restart verification.
- Provider credential scripts changed:
  - `configure-inference-proxy.sh` replaces the older OpenAI-only setup flow.
  - `authorize-and-configure-gmail-read.sh` combines Gmail read authorization
    and provider install.
  - `authorize-gmail-compose.sh` supports compose-only Gmail write bootstrap.
  - `credential-readiness.sh` reports provider readiness without printing
    credential values.

## Already aligned and verified in this branch

- [x] Use demo VM names:
  - `saw-agent`
  - `saw-integ`
- [x] Use demo-facing route name/host pattern:
  - `saw-agent-userport`
- [x] Use persistent disk names selected for this environment:
  - `saw-agent-state-persist`
  - `saw-agent-assets-persist`
  - `saw-integ-persist`
- [x] Use OpenClaw sandbox name `openclaw-saw`.
- [x] Mount persistent OpenClaw state/assets so identity, soul, workspace, and
  sessions survive reboot.
- [x] Keep provider credentials out of the agent VM and route inference through
  the integration VM.
- [x] Configure GLM as the default OpenAI-compatible inference backend:
  - provider label: `glm`
  - model: `rits/zai-org/glm-5-2-fp8`
  - upstream: `https://ete-litellm.ai-models.vpc.res.ibm.com/v1`
- [x] Store the GLM token in the OpenShift secret for `saw-integ`; do not commit
  the token.
- [x] Keep the OpenClaw browser route protected by the existing authenticated
  proxy/trusted-proxy setup.
- [x] Validate the live OpenClaw UI after the name-change and GLM migration.

## Current local divergences from PR #6

These are not failures by themselves; they are places where our known-good
environment intentionally differs from the latest upstream demo workstream.

- [ ] Reconcile VM naming. This branch uses `saw-agent` / `saw-integ`; PR #6's
  `demo.env.example` defaults to `demo1-agent` / `demo1-integ`.
- [ ] Reconcile route/auth. This branch uses the authenticated
  `saw-agent-userport` route; PR #6's Forge UI path uses a demo header injector
  and explicitly says it is not a production auth boundary.
- [ ] Reconcile inference. This branch uses `saw-integ:18083` for the current
  OpenAI-compatible integration proxy; PR #6 reserves `18083` for M365 write
  and moves inference to `18086`.
- [ ] Reconcile model/provider. This branch uses GLM
  `rits/zai-org/glm-5-2-fp8`; PR #6 defaults to `gpt-5.6-sol` through its
  inference proxy flow. Keep GLM unless the user explicitly chooses to move
  back.
- [ ] Reconcile OpenShell version. This branch remains on `0.0.103`; PR #6
  pins and verifies `0.0.110`.
- [ ] Reconcile image flow. This branch currently uses a direct
  `sandbox_image` plus trusted wrapper build on the VM; PR #6 imports
  published `quay.io/redhat-et/*:demo1` images into the internal registry first.
- [ ] Reconcile OpenClaw runtime image. We tested
  `quay.io/rh-forge/openclaw-saw:2026.8.1-beta.2-20260821160256` and reverted
  it because `openclaw --version` exited `137` even under direct rootless
  Podman. Do not reintroduce that image without a new image/runtime fix.

## Demo requirements still left to implement

### Six credential-isolating integration proxies

The upstream demo expects these to live on `saw-integ`, with real service
credentials staying on the integration VM side of the boundary.

- [ ] Gmail read proxy
  - PR #6 image selector: internal `gmail-read-proxy:demo1`, imported from
    `quay.io/redhat-et/gmail-read-proxy:demo1`
  - source lock: `rh-forge/rust-gmail-proxy` `demo1`
  - integration VM port: `18080`
  - agent loopback: `127.0.0.1:18079`
  - credential material: read-only Gmail OAuth grant
  - validation: proxy ready, OpenClaw can read through the governed path
- [ ] Gmail write proxy
  - PR #6 image selector: internal `gmail-write-proxy:demo1`, imported from
    `quay.io/redhat-et/gmail-write-proxy:demo1`
  - source lock: `rh-forge/rust-gmail-proxy` `demo1`
  - integration VM port: `18081`
  - credential material: compose-only Gmail OAuth grant
  - validation: write path can create draft/proposal without granting broad mail
    access to OpenClaw
- [ ] Microsoft 365 read proxy
  - PR #6 image selector: internal `m365-read-proxy:demo1`, imported from
    `quay.io/redhat-et/m365-read-proxy:demo1`
  - source: `rh-forge/rust-m365-proxy/read-proxy`
  - integration VM port: `18082`
  - credential material: delegated read OAuth grant
  - validation: read proxy ready and scoped Graph read request works
- [ ] Microsoft 365 write proxy
  - PR #6 image selector: internal `m365-write-proxy:demo1`, imported from
    `quay.io/redhat-et/m365-write-proxy:demo1`
  - source: `rh-forge/rust-m365-proxy/write-proxy`
  - integration VM port: `18083`
  - credential material: delegated write OAuth grant
  - validation: draft/send proposal flow works through the write boundary
- [ ] Slack read proxy
  - PR #6 image selector: internal `slack-read-proxy:demo1`, imported from
    `quay.io/redhat-et/slack-read-proxy:demo1`
  - source lock: documented `IsaiahStapleton/rust-slack-proxy` `demo1` fork
  - integration VM port: `18084`
  - credential material: read-scoped Slack user token
  - validation: read proxy ready and scoped Slack read request works
- [ ] Slack write proxy
  - PR #6 image selector: internal `slack-write-proxy:demo1`, imported from
    `quay.io/redhat-et/slack-write-proxy:demo1`
  - source lock: documented `IsaiahStapleton/rust-slack-proxy` `demo1` fork
  - integration VM port: `18085`
  - credential material: write-scoped Slack user token
  - validation: approval/front-door write path works without attaching write
    authority directly to OpenClaw

### OpenClaw runtime and image alignment

- [ ] Pin the OpenClaw runtime/image to demo version `2026.8.1-beta.2`.
  - PR #6 normal path imports `quay.io/redhat-et/openclaw-saw:demo1` into the
    internal registry and deploys the internal `openclaw-saw:demo1` image by
    resolved digest.
  - Current status: intentionally deferred. The tested
    `quay.io/rh-forge/openclaw-saw:2026.8.1-beta.2-20260821160256` image was
    not live-compatible in this VM runtime shape; `openclaw --version` exited
    `137` even under direct rootless Podman.
  - Validation gate: deploy fresh `saw-agent`, confirm `/ready`, login as
    `alice`, and complete one successful LLM request before committing.
- [ ] Implement the PR #6 image import/internal-registry flow instead of
  VM-time image builds:
  - `scripts/import-demo-runtime-images.sh`
  - `scripts/build-rh-forge-ui-images.sh`
  - `scripts/configure-internal-registry.sh`
  - internal ImageStreamTags for all nine demo images
- [ ] Keep the normal path Quay-login-free: PR #6 says published `demo1` images
  do not require copying a Quay pull identity into the namespace.

### OpenClaw/provider registration work

- [ ] Add provider definitions for each read proxy in the agent-side OpenClaw
  configuration.
- [ ] Add inference as a Gateway B capability on port `18086`; remove the
  current inference-on-`18083` shape before introducing M365 write.
- [ ] Add Forge ingest as an agent capability.
- [ ] Explicitly deny write capabilities in the OpenClaw sandbox:
  - no Gmail-write provider;
  - no M365-write provider;
  - no Slack-write provider;
  - no writer binaries;
  - no routes to integration write ports `18081`, `18083`, or `18085`.
- [ ] Add per-proxy health/readiness checks to provisioning.
- [ ] Add failure diagnostics that print proxy status/log tails without printing
  secrets.
- [ ] Add tests that reject stale legacy names (`one`, `two`, `sawone`) in
  active manifests, vars, and rendered config.
- [ ] Add tests for the PR #6 locked capability boundary: OpenClaw has read,
  inference, and Forge-ingest only.

### Restart recovery

PR #6 adds restart recovery as a first-class part of the demo.

- [ ] Install recovery scripts and user units on both VMs.
- [ ] Add app/forward recovery configuration for all application sandboxes and
  forwards.
- [ ] Enable recovery targets but do not start them over existing foreground
  processes.
- [ ] Add post-restart verification equivalent to
  `scripts/verify-restart-recovery.sh`.
- [ ] Confirm restart verification checks service status only and does not
  print provider data, message bodies, or approval snapshots.

### Daily briefing / Chief of Staff package

PR #6 moves the target toward a versioned Chief of Staff workspace and
daily-briefing skill installed into OpenClaw backend ID `default`.

- [ ] Add or consume the Chief of Staff workspace from the locked
  `forge-agent-catalog` `demo1` revision.
- [ ] Add a non-secret user profile contract:
  - display name
  - role
  - initials
  - email
  - time zone
- [ ] Persist the installed package under the OpenClaw persistent workspace.
- [ ] Track the installed `forge-agent-catalog` commit for reproducibility.
- [ ] Ensure Home starts empty and offers "Run daily briefing" rather than
  generating fixture drafts or silently starting provider workflows.

### Forge UI and relay

PR #6 treats Forge UI and relay as part of the full demo. They are built
inside OpenShift and remain private in the namespace internal registry.

- [x] Add a UI-only Forge route for side-by-side preview without relay,
  injector, OpenClaw gateway token, or OpenClaw route replacement.
  - Manifest: `cloud-init/kubernetes/forge-ui-ui-only.yml`
  - Route: `rh-forge-ui.${NS}.dal.dev.cirrus.ibm.com`
  - Expected first-step limitation: the static UI may report disconnected relay
    or gateway state until the relay integration is added.
- [x] Add a VM-hosted Forge UI route for namespaces where the operator can
  create Cirrus Server ports/routes but cannot create normal Deployment and
  Service resources.
  - Manifest: `cloud-init/kubernetes/agent-forge-ui-route.yml`
  - saw-agent port: `forgeui` / `18090`
  - Route: `saw-agent-forge-ui.${NS}.dal.dev.cirrus.ibm.com`
  - Ansible unit: `forge-ui.service`
- [ ] Decide whether Forge UI build orchestration belongs in this SAW branch or
  stays in the demo repo orchestration.
- [ ] If included here, add build/deploy flow for:
  - `rh-forge-ui`
  - `rh-forge-ui-relay`
- [ ] Store the OpenClaw gateway token in the relay Secret without printing it.
- [ ] Add route validation for the Forge UI.
- [ ] Document that the PoC demo header injector is not a production
  authentication boundary.
- [ ] Ensure relay state and outbox state are PVC-backed and contain no real
  provider credentials.

## Suggested implementation order

1. Keep the current GLM/name-change baseline as the rollback point.
2. Reconcile the PR #6 port map before adding any proxy:
   - move inference from `18083` to `18086`;
   - reserve `18083` for M365 write.
3. Add the internal-registry image import/auth flow without changing the live
   OpenClaw runtime image.
4. Add one read-only proxy first, preferably Gmail read.
5. Deploy or hot-apply the smallest safe unit and validate:
   - integration proxy ready endpoint
   - agent ready endpoint
   - OpenClaw UI login as `alice`
   - one LLM request
   - one proxy-backed tool request
6. Commit the healthy checkpoint.
7. Add the paired write proxy for the same provider and repeat the full
   validation gate.
8. Repeat for M365 read/write, then Slack read/write.
9. Add restart recovery and verify it with an authorized reboot only after the
   non-reboot checks are stable.
10. Revisit OpenClaw `2026.8.1-beta.2` only through the PR #6 internal-image
    flow or a fixed image that passes `openclaw --version` under direct Podman.
11. Decide on daily briefing and Forge UI as separate checkpoints if they stay
    in this repository.

## Validation gate for every checked item

Before checking off or removing an item:

- [ ] No secret value appears in Git diff, logs, or copied command output.
- [ ] `saw-integ` health/readiness succeeds for the relevant service.
- [ ] `saw-agent` OpenClaw route is reachable.
- [ ] Browser login as `alice` succeeds.
- [ ] OpenClaw can complete a basic LLM response.
- [ ] The new integration/tool path works at least once.
- [ ] Fresh deployment or reboot behavior is understood and documented.
- [ ] A commit records the healthy checkpoint.

## Operational notes

- When rendering Kubernetes manifests with shell variables embedded in
  cloud-init, use namespace-only substitution:

  ```bash
  envsubst '${NS}' < input.yml | oc apply -f -
  ```

  Do not use broad `envsubst`; it can erase cloud-init shell variables such as
  `${vars_device}` and `${checkout}`.

- Keep provider secrets in OpenShift Secrets or on the integration VM. Do not
  commit OAuth tokens, API keys, refresh tokens, front-door bearers, or gateway
  tokens.
- The current GLM implementation still uses some OpenAI-compatible naming
  (`OPENAI_*`, `openai_forwarder.py`) because the proxy speaks the OpenAI API
  shape. Provider-neutral naming can be cleaned up later, but should not block
  the functional proxy work.
