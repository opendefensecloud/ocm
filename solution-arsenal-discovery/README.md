# solution-arsenal-discovery

The registry scanner of [Solution Arsenal (SolAr)](https://github.com/opendefensecloud/solution-arsenal):
receives OCI registry webhooks, scans for OCM components and registers them
with the SolAr API server.

- **License**: Apache 2.0 — of the upstream project, not of this packaging
- **Source**: [opendefensecloud/solution-arsenal](https://github.com/opendefensecloud/solution-arsenal)
- **Requires**: a running `solution-arsenal`
- **Configurations**:
  - Minimal (single instance, scan-only, dev/test)
  - Production (2 replicas, webhook enabled, anti-affinity)

## Contents

| Resource | Type | Wraps |
| --- | --- | --- |
| `solution-arsenal-discovery-chart` | `helmChart` | `ghcr.io/opendefensecloud/charts/solar-discovery` |
| `helm-values-template` | `yaml` | `values.yaml.tpl` |
| `solution-arsenal-discovery-image` | `ociImage` | `ghcr.io/opendefensecloud/solar-discovery` |
| `solution-arsenal-discovery-minimal-config` | `yaml` | `minimal-values.yaml` |
| `solution-arsenal-discovery-production-config` | `yaml` | `production-values.yaml` |

The image and chart are built and published by the source repository; this
directory only packages them as an OCM component.

## Quick Start

```bash
# The pinned version lives in component-constructor.yaml (make version).
helm install solar-discovery oci://ghcr.io/opendefensecloud/charts/solar-discovery \
  --namespace solar-system \
  --values solution-arsenal-discovery/minimal-values.yaml
```

## Build

```bash
make validate COMPONENT=solution-arsenal-discovery   # publishes nothing
make airgap   COMPONENT=solution-arsenal-discovery   # self-contained CTF bundle
```

## Release

Automatic. The component version is the chart version, so a Renovate bump
merged to `main` publishes and signs it — see
[Releasing](../README.md#releasing).
