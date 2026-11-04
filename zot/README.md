# zot

[zot](https://zotregistry.dev), an OCI-native container registry, packaged from
its official Helm chart.

- **License**: Apache 2.0 — of the upstream project, not of this packaging
- **Source**: [project-zot/zot](https://github.com/project-zot/zot)

## Contents

| Resource | Type | Wraps |
| --- | --- | --- |
| `zot-chart` | `helmChart` | `ghcr.io/project-zot/helm-charts/zot` |
| `zot-chart-values-template` | `yaml` | `values.yaml.tpl` |
| `zot-image` | `ociImage` | `ghcr.io/project-zot/zot` |
| `alpine-image` | `ociImage` | `docker.io/library/alpine` |

`alpine-image` is the image the chart's test hook runs. It comes from Docker
Hub, whose anonymous pull limit can make `make validate` flaky in CI.

## Build

```bash
make validate COMPONENT=zot   # publishes nothing
make airgap   COMPONENT=zot   # self-contained CTF bundle
```

## Release

Automatic. The component version is the chart version, so a Renovate bump
merged to `main` publishes and signs it — see
[Releasing](../README.md#releasing).
