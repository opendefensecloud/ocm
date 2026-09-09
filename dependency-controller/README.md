# dependency-controller

Cross-workspace referential integrity for kcp via declarative dependency rules
and deletion-protection webhooks.

- **License**: Apache 2.0 — of the upstream project, not of this packaging
- **Source**: [opendefensecloud/dependency-controller](https://github.com/opendefensecloud/dependency-controller)
- **Configurations**:
  - Minimal (single replica each, self-managed webhook TLS, dev/test)
  - Production (2 controller / 3 webhook replicas, cert-manager TLS, anti-affinity)

## Contents

| Resource | Type | Wraps |
| --- | --- | --- |
| `dependency-controller-chart` | `helmChart` | `ghcr.io/opendefensecloud/charts/dependency-controller` |
| `dependency-controller-image` | `ociImage` | `ghcr.io/opendefensecloud/dependency-controller` |
| `dependency-webhook-image` | `ociImage` | `ghcr.io/opendefensecloud/dependency-webhook` |
| `dependency-controller-minimal-config` | `yaml` | `minimal-values.yaml` |
| `dependency-controller-production-config` | `yaml` | `production-values.yaml` |

The image and chart are built and published by the source repository; this
directory only packages them as an OCM component.

## Quick Start

The webhook sits in the admission path and will not start without TLS, so the
minimal config needs a Secret holding `tls.crt`, `tls.key` and `ca.crt`:

```bash
kubectl create namespace dependency-system

kubectl -n dependency-system create secret generic dependency-webhook-tls \
  --from-file=tls.crt --from-file=tls.key --from-file=ca.crt

# The pinned version lives in component-constructor.yaml (make version).
helm install dependency-controller \
  oci://ghcr.io/opendefensecloud/charts/dependency-controller \
  --namespace dependency-system \
  --values dependency-controller/minimal-values.yaml \
  --set webhook.tls.existingSecret=dependency-webhook-tls
```

For production use cert-manager instead — see *Configuration notes*.

## Configuration notes

The webhook sits in the admission path: if it is unavailable, writes to every
protected resource are blocked. Production therefore runs **3 webhook
replicas** so a rolling update or node drain cannot take it offline.

The chart removed the top-level `image.repository` / `image.tag` keys after
0.4.0. Set `controller.image.*` and `webhook.image.*` instead — overrides of
the old keys are **silently ignored**.

Both configs leave `webhook.tls` unset:

- **Minimal** needs `webhook.tls.existingSecret` pointing at a Secret with
  `tls.crt`, `tls.key` and `ca.crt`. The webhook will not start without it.
- **Production** needs `webhook.tls.certManager.issuerRef.name` set to a
  ClusterIssuer that exists in the target cluster, and cert-manager installed.

## Build

```bash
make validate COMPONENT=dependency-controller   # publishes nothing
make airgap   COMPONENT=dependency-controller   # self-contained CTF bundle
```

## Release

Automatic. The component version is the chart version, so a Renovate bump
merged to `main` publishes and signs it. Nothing to tag by hand — see
[Releasing](../README.md#releasing).
