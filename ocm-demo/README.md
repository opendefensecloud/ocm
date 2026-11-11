# ocm-demo

A minimal example component: one Helm chart that deploys an `nginx` Deployment
and Service. SolAr's dev cluster and E2E tests use it to exercise discovery,
values templating and rendering.

- **License**: Apache 2.0
- **Source**: [`charts/demo`](charts/demo), kept for reference only

## Contents

| Resource | Type | Wraps |
| --- | --- | --- |
| `demo-chart` | `helmChart` | `ghcr.io/opendefensecloud/opendefense.cloud/ocm-demo/demo` |
| `helm-values-template` | `yaml` | `values.yaml.tpl` |
| `nginx-image` | `ociImage` | `ghcr.io/linuxserver/nginx` |

`helm-values-template` sets the chart's image from `nginx-image`, so after a
by-value transfer the chart pulls nginx from the target registry.

## Naming and versions

The resource names must not change, because SolAr's tests look them up by name.
The chart was built from `charts/demo` and is pinned by digest, so the
reference cannot move. This repository builds no charts: the copy is only kept
so the source is not lost, and changing it changes nothing published. A new
chart version has to be packaged and pushed by hand, then referenced in the
constructor. Older `v26.x` versions sort above `0.1.0`, see
[Releasing](../README.md#releasing).

## Build

```bash
make validate COMPONENT=ocm-demo   # publishes nothing
make airgap   COMPONENT=ocm-demo   # self-contained CTF bundle
```

## Release

Automatic: merged to `main`, it publishes and signs `0.1.0` once. A new version
needs a new chart, see [Releasing](../README.md#releasing).
