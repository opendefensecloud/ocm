# quota-controller

Per-workspace consumption quotas for kcp, enforced through the
`quota-provider` APIExport and an admission webhook.

- **License**: Apache 2.0 — of the upstream project, not of this packaging
- **Source**: [opendefensecloud/quota-controller](https://github.com/opendefensecloud/quota-controller)
- **Configurations**:
  - Minimal (single replica each, self-managed webhook TLS, dev/test)
  - Production (2 controller / 3 webhook replicas, cert-manager TLS, anti-affinity)

## Contents

| Resource | Type | Wraps |
| --- | --- | --- |
| `quota-controller-chart` | `helmChart` | `ghcr.io/opendefensecloud/charts/quota-controller` |
| `quota-controller-image` | `ociImage` | `ghcr.io/opendefensecloud/quota-controller` |
| `quota-webhook-image` | `ociImage` | `ghcr.io/opendefensecloud/quota-webhook` |
| `quota-controller-minimal-config` | `yaml` | `minimal-values.yaml` |
| `quota-controller-production-config` | `yaml` | `production-values.yaml` |

The images and chart are built and published by the source repository; this
directory only packages them as an OCM component.

## Quick Start

The webhook sits in the admission path and will not start without TLS, and the
controller mounts `ca.crt` from the *same* Secret, so the minimal config needs
a Secret holding `tls.crt`, `tls.key` and `ca.crt`:

```bash
kubectl create namespace quota-system

kubectl -n quota-system create secret generic quota-webhook-tls \
  --from-file=tls.crt --from-file=tls.key --from-file=ca.crt

# The pinned version lives in component-constructor.yaml (make version).
helm install quota-controller \
  oci://ghcr.io/opendefensecloud/charts/quota-controller \
  --namespace quota-system \
  --values quota-controller/minimal-values.yaml \
  --set webhook.tls.existingSecret=quota-webhook-tls
```

For production use cert-manager instead — see *Configuration notes*.

## Configuration notes

The webhook sits in the admission path: if it is unavailable, writes to every
quota-guarded resource are blocked. Production therefore runs **3 webhook
replicas** so a rolling update or node drain cannot take it offline.

**cert-manager needs no ClusterIssuer here.** With
`webhook.tls.certManager.enabled` the chart bootstraps its own chain — a
selfSigned `Issuer`, a CA `Certificate`, a CA `Issuer`, then the serving
`Certificate` — so only cert-manager itself has to be installed. This differs
from `dependency-controller`, which expects an existing ClusterIssuer.

`existingSecret` and `certManager.enabled` are mutually exclusive: setting the
former suppresses the whole cert-manager chain.

There is no top-level `image` key. Repository and tag live under
`controller.image.*` and `webhook.image.*`, and are rewritten to the localized
references by `values.yaml.tpl` after a transfer.

`controller.reservationTTL` and `webhook.reservationTTL` must match, and
`controller.resyncInterval` must not exceed the TTL, or the accounting sweep
reclaims slots the webhook still considers held.

Both `kcp.workspace` and `apiExportName` must match the workspace the chart is
installed into; the kubeconfig's current context has to point there already.
When the controller runs outside kcp, set `controller.kubeconfig.secretName`
and `webhook.kubeconfig.secretName`.

## Build

```bash
make validate COMPONENT=quota-controller   # publishes nothing
make airgap   COMPONENT=quota-controller   # self-contained CTF bundle
```

## Release

Automatic. The component version is the chart version, so a Renovate bump
merged to `main` publishes and signs it. Nothing to tag by hand — see
[Releasing](../README.md#releasing).
