# Cirrus cloud-init assets

GitHub Gist delivery is deprecated and unsupported for this deployment.

Cloud-init bootstrap assets must be versioned under this `cloud-init/`
directory and downloaded from a named branch or immutable commit in this
repository. Secrets must be supplied through the OpenShift Secret mounts and
must never be embedded in either the repository URL or cloud-init user data.

## Secret handling

Do not commit passwords, provider keys, bearer tokens, rendered Secret
manifests, or local operator credential files to this repository.

The saw-integ VM payload Secrets are the only places where runtime credentials enter
the deployment:

- `Secret/saw-agent-vars` receives only agent-side configuration plus the internal
  bearer used to call saw-integ. It must not contain a real OpenAI/provider key.
- `Secret/saw-integ-vars` receives the OpenAI/provider key, integration TLS material,
  and the internal bearer expected by the integration proxy.

Keycloak administrator credentials are not required by either VM and must not
be added to `saw-agent-vars`, `saw-integ-vars`, cloud-init user data, or Git. If an
operator needs to create or update the existing Keycloak realm/client, use
those admin credentials only from a local password manager, local ignored file,
or approved external secret store, then discard any temporary files. The
resulting public OIDC values that are safe to place in `saw-agent-vars` are the
issuer URL, realm, and public client IDs.

Before launching a VM from these assets, make sure the existing Keycloak realm
has:

- the public OpenShell CLI/dashboard client IDs referenced by `saw-agent-vars`;
- the admitted OpenClaw route callback URL registered as an allowed redirect;
- the admitted OpenClaw route origin registered as an allowed web origin; and
- the expected test/user identity, such as `alice`, with the required realm
  roles.

## Required secret inputs

An operator may need the following sensitive values. Keep them in a password
manager, an approved external secret store, or local files under an ignored
directory such as `cloud-init/.secrets/`.

| Secret value | Required where | Purpose | Commit to Git? |
| --- | --- | --- | --- |
| OpenAI-compatible provider API key | `Secret/saw-integ-vars` only, as `integration_proxy_openai_key` | Allows saw-integ to call the upstream OpenAI-compatible provider. The default demo target is GLM at `https://ete-litellm.ai-models.vpc.res.ibm.com/v1`. | No |
| Internal bearer, 64 hex chars | Both `Secret/saw-agent-vars` as `inference_api_key` and `Secret/saw-integ-vars` as `integration_proxy_expected_bearer` | Allows saw-agent to call only saw-integ's integration proxy | No |
| Integration CA certificate | Both `Secret/saw-agent-vars` and `Secret/saw-integ-vars` as `integration_proxy_ca_pem` | Lets saw-agent trust saw-integ's HTTPS integration proxy | No, unless it is intentionally public test CA material |
| Integration TLS certificate | `Secret/saw-integ-vars` as `integration_proxy_tls_cert_pem` | Server certificate for saw-integ's HTTPS integration proxy | No, unless it is intentionally public test cert material |
| Integration TLS private key | `Secret/saw-integ-vars` as `integration_proxy_tls_key_pem` | Private key for saw-integ's HTTPS integration proxy | Never |
| Keycloak private CA certificate | `Secret/saw-agent-vars` as `keycloak_ca_pem`, only when the issuer uses private PKI | Lets saw-agent trust the OIDC issuer | No, unless your organization classifies that CA as public |
| Keycloak admin username/password | Local operator use only, if Keycloak client/user setup is not already complete | Configures the existing realm/client/users out-of-band | Never |

The following values are not secrets and may be documented in the PR:

- Keycloak issuer URL, realm, and public client IDs.
- OpenClaw route origin and callback URL.
- OpenClaw allowed browser identities, for example `alice`.
- The internal Service URL from saw-agent to saw-integ.

## Reference names and how to change them

Several names in these assets are intentionally coupled across OpenShift,
KubeVirt/Cirrus, cloud-init, TLS, and Ansible. They are safe to change, but
change the complete reference set together.

| Reference | Default | Used by | If you change it |
| --- | --- | --- | --- |
| Agent VM `Server`/Service name | `saw-agent` | `kubernetes/agent-server.yml`, `Route/saw-agent-userport`, operator commands | Rename the Server, route target service, route hostname convention, and any operator commands that reference `server/saw-agent`, `vmi/saw-agent`, or `svc/saw-agent`. |
| Integration VM `Server`/Service name | `saw-integ` | `kubernetes/integrations-server.yml`, saw-agent `inference_endpoint_url`, integration TLS SANs | Rename the Server and update saw-agent to call `https://<new-name>.<namespace>.svc.cluster.local:18083/v1`; regenerate the integration TLS certificate for the new DNS names. |
| Browser route name and host | `saw-agent-userport`, `saw-agent-userport.<namespace>.dal.dev.cirrus.ibm.com` | Route creation, Keycloak redirect URI/web origin, `openclaw_route_origin`, `openclaw_proxy_redirect_url` | Update Keycloak redirect/web-origin settings and the corresponding values in `Secret/saw-agent-vars`. |
| saw-agent state PVC | `saw-agent-state-persist` | `kubernetes/agent-server.yml` | Update the `persistent-state` PVC claim name before creating `Server/saw-agent`. Existing data stays with the old PVC unless copied or recreated through the storage workflow. |
| saw-agent asset PVC | `saw-agent-assets-persist` | `kubernetes/agent-server.yml` | Update the `persistent-assets` PVC claim name before creating `Server/saw-agent`. This disk holds rootless container storage and OpenClaw sandbox assets. |
| saw-integ persistence PVC | `saw-integ-persist` | `kubernetes/integrations-server.yml` | Update the `persistent-state` PVC claim name before creating `Server/saw-integ`. This disk holds the integration proxy state and provider key file. |
| saw-agent disk serials | `SAWAGENTSTATE`, `SAWAGENTASSETS` | `kubernetes/agent-server.yml`, `ansible/agent.yml` | Change both the Cirrus mount serial and the Ansible disk discovery serial in the same commit. |
| saw-integ disk serial | `SAWINTEGPERSIST` | `kubernetes/integrations-server.yml`, `ansible/site.yml` | Change both the Cirrus mount serial and the Ansible disk discovery serial in the same commit. |
| Secret names | `saw-agent-vars`, `saw-integ-vars` | Server mounts in `kubernetes/*-server.yml` | Rename the Secret resources and update the `secretName` values on the matching Server manifests. |
| OpenClaw sandbox name | `openclaw-saw` | `ansible/vars/agent-vars.example.yml`, persisted OpenShell/Podman state | Changing this creates a different sandbox identity. Preserve data by migrating the old sandbox state or intentionally starting fresh. |

The integration VM name is the most sensitive reference. Kubernetes Service DNS
solves changing VM IPs, but the DNS name itself is part of the integration
certificate trust chain. A saw-agent endpoint URL that says `saw-integ` must match a TLS
certificate that is valid for `saw-integ`, `saw-integ.<namespace>.svc`, and
`saw-integ.<namespace>.svc.cluster.local`.

## Deployment process

The examples below assume a namespace stored in `NS`. They deliberately write
all rendered Secret material into `cloud-init/.secrets/`, which is ignored by
Git.

### 1. Select namespace and route values

```bash
cd cloud-init

export NS='rh-vm-test1'
export ROUTE_HOST="saw-agent-userport.${NS}.dal.dev.cirrus.ibm.com"
export ROUTE_ORIGIN="https://${ROUTE_HOST}"
export ROUTE_CALLBACK="${ROUTE_ORIGIN}/oauth2/callback"
```

### 2. Configure Keycloak out-of-band

Before browser login, the existing Keycloak realm/client must allow:

```text
allowed redirect URI: <ROUTE_CALLBACK>
allowed web origin:   <ROUTE_ORIGIN>
allowed user:         alice, or the value in openclaw_proxy_allowed_users
```

Use Keycloak admin credentials only in the Keycloak admin console, a local
ignored script, or an approved secret-management workflow. Do not store those
credentials in either VM Secret.

### 3. Prepare local Secret payload files

```bash
install -d -m 0700 .secrets
cp ansible/vars/agent-vars.example.yml .secrets/saw-agent-vars.yml
cp ansible/vars/integrations-vars.example.yml .secrets/saw-integ-vars.yml
chmod 0600 .secrets/saw-agent-vars.yml .secrets/saw-integ-vars.yml
```

Edit `.secrets/saw-agent-vars.yml`:

- replace every `${NS}` with the target namespace;
- set `openclaw_route_origin` to `ROUTE_ORIGIN`;
- set `openclaw_proxy_redirect_url` to `ROUTE_CALLBACK`;
- set `openclaw_proxy_allowed_users` to the users allowed through the browser
  proxy;
- set `inference_api_key` to the generated internal bearer;
- set `integration_proxy_ca_pem` to the generated integration CA certificate;
- set `keycloak_ca_pem` only if the Keycloak issuer uses a private CA.

Edit `.secrets/saw-integ-vars.yml`:

- replace every `${NS}` with the target namespace;
- set `integration_proxy_expected_bearer` to the same internal bearer used in
  `.secrets/saw-agent-vars.yml`;
- set `integration_proxy_openai_key` to the provider API key. The default
  OpenAI-compatible provider is `rits/zai-org/glm-5-2-fp8` through
  `https://ete-litellm.ai-models.vpc.res.ibm.com/v1`;
- set `integration_proxy_ca_pem`, `integration_proxy_tls_cert_pem`, and
  `integration_proxy_tls_key_pem` to the generated integration TLS material.

One safe way to generate the internal bearer is:

```bash
openssl rand -hex 32
```

The integration TLS certificate must be valid for:

```text
DNS:saw-integ
DNS:saw-integ.<namespace>.svc
DNS:saw-integ.<namespace>.svc.cluster.local
IP:127.0.0.1
```

### 4. Create or update the OpenShift Secrets

```bash
oc -n "$NS" create secret generic saw-agent-vars \
  --from-file=vars.yml=.secrets/saw-agent-vars.yml \
  --dry-run=client -o yaml | oc apply -f -

oc -n "$NS" create secret generic saw-integ-vars \
  --from-file=vars.yml=.secrets/saw-integ-vars.yml \
  --dry-run=client -o yaml | oc apply -f -
```

Never commit `.secrets/saw-agent-vars.yml`, `.secrets/saw-integ-vars.yml`, or YAML rendered
from these commands.

### 5. Launch the saw-agent and saw-integ Cirrus Servers

Do not render these Server manifests with broad `envsubst`. The cloud-init
payload intentionally contains guest-side shell variables such as
`${vars_device}` and `${checkout}`; broad environment substitution will replace
those with empty strings and make cloud-init fail before provisioning starts.
Use the targeted `${NS}` replacement below.

```bash
perl -pe 's/\$\{NS\}/$ENV{NS}/g' kubernetes/agent-server.yml | oc apply -f -
perl -pe 's/\$\{NS\}/$ENV{NS}/g' kubernetes/integrations-server.yml | oc apply -f -

oc -n "$NS" wait --for=condition=Ready vmi/saw-agent --timeout=10m
oc -n "$NS" wait --for=condition=Ready vmi/saw-integ --timeout=10m
```

### 6. Create the browser Route after Service saw-agent exists

The Route targets only `Service/saw-agent` port `userport`. There is intentionally
no Route to saw-integ.

saw-agent reserves the browser-facing userport for the authenticated proxy. The
raw OpenClaw gateway forward stays localhost-only on `127.0.0.1:18788`, and
oauth2-proxy listens on `0.0.0.0:18789` before proxying to that local forward.
This avoids binding the browser route to a guest IP address that can change
when the VM is recreated.

```bash
oc -n "$NS" wait --for=jsonpath='{.metadata.name}'=saw-agent service/saw-agent --timeout=10m

oc -n "$NS" create route edge saw-agent-userport \
  --service=saw-agent \
  --port=userport \
  --hostname="$ROUTE_HOST" \
  --insecure-policy=Redirect \
  --dry-run=client -o yaml | oc apply -f -

oc -n "$NS" get route saw-agent-userport
```

### 7. Verify provisioning and access

On saw-agent:

```bash
tail -f /var/log/saw-provision.log
```

On saw-integ:

```bash
tail -f /var/log/saw-provision.log
curl -sk https://127.0.0.1:18083/readyz
```

From the operator workstation, verify the internal integration proxy through
the cluster Service:

```bash
oc -n "$NS" port-forward svc/saw-integ 28083:18083
curl -sk https://127.0.0.1:28083/readyz
```

Finally open the browser route:

```text
https://saw-agent-userport.<namespace>.dal.dev.cirrus.ibm.com/
```

Sign in as an allowed Keycloak user, then send a prompt in OpenClaw. A working
deployment reaches OpenClaw through saw-agent and sends model traffic from saw-agent
to saw-integ over the internal `Service/saw-integ:18083` path.

## Optional VM-hosted Forge UI-only side-by-side preview

The preferred path in this Cirrus namespace is to host the static Forge UI
inside saw-agent, then expose it through a second saw-agent `Server` port and
Route. This avoids requiring permission to create arbitrary Kubernetes
Deployments and Services.

The VM-hosted preview does not deploy relay, injector, gateway-token wiring, or
an additional OpenClaw instance. A disconnected relay/gateway state in the page
is expected until the relay integration is added later.

The Forge UI image must be pullable by rootless Podman from inside saw-agent.
The example vars default to the AMD64 image published for the VM-hosted preview:

```text
quay.io/rcook/rh-forge-ui:demo1-amd64
```

If that image is private, configure rootless Podman auth for the `openshell`
user before enabling the service, or temporarily make the repository public
while validating the preview.

Deploy the VM-hosted route after `Server/saw-agent` has been applied:

```bash
cd cloud-init

export NS='rh-vm-test1'

perl -pe 's/\$\{NS\}/$ENV{NS}/g' kubernetes/agent-forge-ui-route.yml | oc apply -f -

oc -n "$NS" get route saw-agent-forge-ui \
  -o jsonpath='https://{.spec.host}{"\n"}'
```

The VM-hosted Forge UI route host is:

```text
saw-agent-forge-ui.<namespace>.dal.dev.cirrus.ibm.com
```

The existing OpenClaw route remains:

```text
https://saw-agent-userport.<namespace>.dal.dev.cirrus.ibm.com/
```

Remove only the VM-hosted Forge UI route with:

```bash
perl -pe 's/\$\{NS\}/$ENV{NS}/g' kubernetes/agent-forge-ui-route.yml | oc delete -f -
```

## Optional Kubernetes Deployment-hosted Forge UI-only preview

This path is useful only when the operator has permission to create normal
Kubernetes `Deployment`, `Service`, and `ServiceAccount` resources in the
namespace. In the observed Cirrus namespace, the VM/Server route above is the
path that matches the available permissions.

The Forge UI can be exposed beside the current OpenClaw route before relay,
gateway-token, or OpenClaw replacement work is enabled. This preview deploys
only the static UI container. A disconnected relay/gateway state in the page is
expected until the relay integration is added later.

The UI image must already exist in the OpenShift internal registry as
`image-registry.openshift-image-registry.svc:5000/${NS}/rh-forge-ui:demo1`.
This repository does not build that image in the UI-only step.

The side-by-side Forge UI route host is:

```text
rh-forge-ui.<namespace>.dal.dev.cirrus.ibm.com
```

```bash
cd cloud-init

export NS='rh-vm-test1'

perl -pe 's/\$\{NS\}/$ENV{NS}/g' kubernetes/forge-ui-ui-only.yml | oc apply -f -

oc -n "$NS" rollout status deployment/rh-forge-ui --timeout=5m
oc -n "$NS" get route rh-forge-ui \
  -o jsonpath='https://{.spec.host}{"\n"}'
```

The existing OpenClaw route remains:

```text
https://saw-agent-userport.<namespace>.dal.dev.cirrus.ibm.com/
```

Remove only the side-by-side UI preview with:

```bash
perl -pe 's/\$\{NS\}/$ENV{NS}/g' kubernetes/forge-ui-ui-only.yml | oc delete -f -
```

## Experimental VM persistence

The `feat/openclaw-demo-alignment` branch prototypes persistence for saw-agent and saw-integ.
It expects existing block PVCs in the same namespace as the `Server` resources:

| VM | PVC | Purpose |
| --- | --- | --- |
| saw-agent | `saw-agent-state-persist` | OpenShell gateway/config/state |
| saw-agent | `saw-agent-assets-persist` | rootless Podman container storage for OpenClaw sandbox assets |
| saw-integ | `saw-integ-persist` | integration proxy configuration and provider credential file |

These PVCs are created outside this repository by the Cirrus/MTOS storage flow.
In the observed environment they are ordinary Kubernetes
`PersistentVolumeClaim` objects annotated with `cirrus.ibm.com/volume-type:
ocsBlock` and submitted by the `mtos-pipeline:mtos-controller` service account.
No namespace-scoped Cirrus disk/volume CRD was found. After the PVC exists, the
regular OpenShift/KubeVirt path attaches it to the VM launcher pod.

The observed PVC shape is:

```yaml
storageClassName: ocs-storagecluster-ceph-rbd
volumeMode: Block
accessModes:
  - ReadWriteMany
```

While iterating, refresh a persistent disk by deleting the consuming `Server`,
waiting for its VM/VMI to disappear, refreshing or recreating the PVC through
the same Cirrus/MTOS flow, then reapplying the `Server`. Do not delete these
PVCs casually with raw `oc delete pvc`: the backing StorageClass uses a
delete-style reclaim policy, so PVC deletion should be treated as data loss.

### saw-agent persistence

During saw-agent cloud-init:

- `saw-agent-state-persist` is attached with disk serial `SAWAGENTSTATE`;
- `saw-agent-assets-persist` is attached with disk serial `SAWAGENTASSETS`;
- cloud-init leaves both persistent disks untouched so VM startup stays close to
  the known-good bootstrap path.

During saw-agent agent provisioning:

- each disk is formatted only when it has no filesystem;
- the state disk is mounted at `/var/lib/saw-agent-state`;
- the asset disk is mounted at `/var/lib/saw-agent-assets`;
- `/etc/openshell` and OpenShell user config/state directories are
  bind-mounted from the state disk;
- `/home/openshell/.local/share/openshell/openclaw-home` is bind-mounted into
  the OpenClaw sandbox at `/sandbox/.openclaw` through OpenShell's Podman
  driver config. That host path is itself backed by `saw-agent-state-persist`, so
  `SOUL.md`, `IDENTITY.md`, avatars, sessions, and related OpenClaw files
  survive sandbox replacement;
- rootless Podman container storage is bind-mounted from the asset disk.

User systemd unit files are intentionally not persisted. They are reproducible
deployment artifacts and must be regenerated after the OpenShell binaries exist
on each fresh VM root disk. Persisting them can make stale enabled units start
too early during boot and fail before provisioning reinstalls `/usr/local/bin`.

The OpenClaw sandbox unit intentionally reuses an existing Ready sandbox instead
of deleting it on every provisioning run. If OpenShell reports a persisted
sandbox as non-Ready after reboot, provisioning can replace the sandbox runtime
without losing OpenClaw identity assets because OpenClaw's home directory is a
state-PVC-backed bind mount rather than disposable container writable-layer
state.

### saw-integ persistence

saw-integ expects an existing block PVC named `saw-integ-persist` in the same namespace
as `Server/saw-integ`.

During saw-integ cloud-init:

- the `saw-integ-persist` PVC is attached with disk serial `SAWINTEGPERSIST`;
- cloud-init leaves the persistent disk untouched so VM startup stays close to
  the known-good bootstrap path.

During saw-integ integration provisioning:

- the disk is formatted only when it has no filesystem;
- the disk is mounted at `/var/lib/saw-persist`;
- `/var/lib/saw-persist/etc-saw-integration` is bind-mounted to
  `/etc/saw-integration`;
- `/var/lib/saw-persist/var-lib-saw-integration` is bind-mounted to
  `/var/lib/saw-integration`.

The integration playbook then preserves any existing non-empty
`/etc/saw-integration/openai.key`. If that file is missing or zero bytes, the
playbook initializes it from `Secret/saw-integ-vars`.

This means the provider key can survive saw-integ recreation without allowing a
blank or placeholder value in `Secret/saw-integ-vars` to overwrite a working
persisted key. Other integration configuration, such as `proxy.env` and TLS
material, is still reconciled from `Secret/saw-integ-vars` so saw-agent and saw-integ stay
aligned when the internal bearer or certificates are intentionally rotated.
