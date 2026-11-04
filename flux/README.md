# flux

[Flux](https://github.com/fluxcd/flux2), the GitOps toolkit SolAr deploys
through, packaged from the
[flux2 community Helm chart](https://github.com/fluxcd-community/helm-charts).

- **License**: Apache 2.0 — of the upstream project, not of this packaging
- **Source**: [fluxcd/flux2](https://github.com/fluxcd/flux2)

## Contents

| Resource | Type | Wraps |
| --- | --- | --- |
| `flux-chart` | `helmChart` | `ghcr.io/fluxcd-community/charts/flux2` |
| `flux-chart-values-template` | `yaml` | `values.yaml.tpl` |
| `helm-controller-image` | `ociImage` | `ghcr.io/fluxcd/helm-controller` |
| `cli-image` | `ociImage` | `ghcr.io/fluxcd/flux-cli` |
| `image-automation-controller-image` | `ociImage` | `ghcr.io/fluxcd/image-automation-controller` |
| `image-reflector-controller-image` | `ociImage` | `ghcr.io/fluxcd/image-reflector-controller` |
| `kustomize-controller-image` | `ociImage` | `ghcr.io/fluxcd/kustomize-controller` |
| `notification-controller-image` | `ociImage` | `ghcr.io/fluxcd/notification-controller` |
| `source-controller-image` | `ociImage` | `ghcr.io/fluxcd/source-controller` |
| `source-watcher-image` | `ociImage` | `ghcr.io/fluxcd/source-watcher` |

The ocm-components version also shipped Flux's plain `install.yaml` through a
`wget` access. It is not carried over: no Renovate manager could bump it (it
had already drifted behind the images), and SolAr deploys the chart.

## Build

```bash
make validate COMPONENT=flux   # publishes nothing
make airgap   COMPONENT=flux   # self-contained CTF bundle
```

## Release

Automatic. The component version is the chart version, so a Renovate bump
merged to `main` publishes and signs it — see
[Releasing](../README.md#releasing).
