# artifact-conduit

[Artifact Conduit (ARC)](https://github.com/opendefensecloud/artifact-conduit):
a gateway for procuring artifacts and transferring them across security zones,
with automated scanning and validation on the way.

- **License**: Apache 2.0 — of the upstream project, not of this packaging
- **Source**: [opendefensecloud/artifact-conduit](https://github.com/opendefensecloud/artifact-conduit)
- **Docs**: [arc.opendefense.cloud](https://arc.opendefense.cloud)
- **Requires**: cert-manager, `argo-workflows`
- **Configurations**:
  - Minimal (single instance, dev/test)
  - Production (HA with replicas)

## Contents

| Resource | Type | Wraps |
| --- | --- | --- |
| `arc-chart` | `helmChart` | `ghcr.io/opendefensecloud/charts/arc` |
| `arc-chart-values-template` | `yaml` | `values.yaml.tpl` |
| `arc-apiserver-image` | `ociImage` | `ghcr.io/opendefensecloud/arc-apiserver` |
| `arc-controller-manager-image` | `ociImage` | `ghcr.io/opendefensecloud/arc-controller-manager` |
| `etcd-image` | `ociImage` | `quay.io/coreos/etcd` |
| `arc-minimal-config` | `yaml` | `minimal-values.yaml` |
| `arc-production-config` | `yaml` | `production-values.yaml` |

## Naming and versions

The directory is `artifact-conduit/`, but the component is published as
`opendefense.cloud/arc`, the name consumers already use. The Makefile reads the
name from the constructor, so the two may differ.

ARC's charts are tagged with a `v` prefix since 0.2.1. The component version
drops it like every other component's (chart `v0.3.2` -> component `0.3.2`), and
the chart resource keeps the tag that exists in the registry. Its images are
published both with and without the prefix, and the constructor uses the
unprefixed tags. `renovate.json` carries a matching exception for the chart.

## Build

```bash
make validate COMPONENT=artifact-conduit   # publishes nothing
make airgap   COMPONENT=artifact-conduit   # self-contained CTF bundle
```

## Release

Automatic. The component version is the chart version, so a Renovate bump
merged to `main` publishes and signs it — see
[Releasing](../README.md#releasing).
