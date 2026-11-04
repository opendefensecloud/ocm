# solution-arsenal

[Solution Arsenal (SolAr)](https://github.com/opendefensecloud/solution-arsenal):
an OCM-based application catalog and fleet rollout manager, run as a Kubernetes
extension API server with its own etcd.

- **License**: Apache 2.0 — of the upstream project, not of this packaging
- **Source**: [opendefensecloud/solution-arsenal](https://github.com/opendefensecloud/solution-arsenal)
- **Requires**: cert-manager
- **Configurations**:
  - Minimal (single instance, dev/test, kind/minikube)
  - Production (HA, metrics enabled)

## Contents

| Resource | Type | Wraps |
| --- | --- | --- |
| `solution-arsenal-chart` | `helmChart` | `ghcr.io/opendefensecloud/charts/solar` |
| `solution-arsenal-helm-values-template` | `yaml` | `values.yaml.tpl` |
| `solution-arsenal-apiserver-image` | `ociImage` | `ghcr.io/opendefensecloud/solar-apiserver` |
| `solution-arsenal-controller-manager-image` | `ociImage` | `ghcr.io/opendefensecloud/solar-controller-manager` |
| `solution-arsenal-renderer-image` | `ociImage` | `ghcr.io/opendefensecloud/solar-renderer` |
| `solution-arsenal-ui-image` | `ociImage` | `ghcr.io/opendefensecloud/solar-ui` |
| `etcd-image` | `ociImage` | `quay.io/coreos/etcd` |
| `solution-arsenal-minimal-config` | `yaml` | `minimal-values.yaml` |
| `solution-arsenal-production-config` | `yaml` | `production-values.yaml` |

The images and chart are built and published by the source repository; this
directory only packages them as an OCM component. Discovery
(`solution-arsenal-discovery`) is a separate component.

## Quick Start

```bash
# The pinned version lives in component-constructor.yaml (make version).
helm install solar oci://ghcr.io/opendefensecloud/charts/solar \
  --namespace solar-system --create-namespace \
  --values solution-arsenal/minimal-values.yaml
```

## Build

```bash
make validate COMPONENT=solution-arsenal   # publishes nothing
make airgap   COMPONENT=solution-arsenal   # self-contained CTF bundle
```

## Release

Automatic. The component version is the chart version, so a Renovate bump
merged to `main` publishes and signs it — see
[Releasing](../README.md#releasing).
