# argo-workflows

[Argo Workflows](https://github.com/argoproj/argo-workflows), the CNCF
Kubernetes-native workflow engine, packaged from the official argoproj Helm
chart. `artifact-conduit` depends on it; install it into the same cluster first.

- **License**: Apache 2.0 — of the upstream project, not of this packaging
- **Source**: [argoproj/argo-workflows](https://github.com/argoproj/argo-workflows)
- **Configurations**:
  - Minimal (single replica, `server` auth, dev/test)
  - Production (HA, `client` auth, monitoring)

## Contents

| Resource | Type | Wraps |
| --- | --- | --- |
| `argo-workflows-chart` | `helmChart` | `ghcr.io/argoproj/argo-helm/argo-workflows` |
| `argo-workflows-chart-values-template` | `yaml` | `values.yaml.tpl` |
| `argo-workflows-controller-image` | `ociImage` | `quay.io/argoproj/workflow-controller` |
| `argo-workflows-server-image` | `ociImage` | `quay.io/argoproj/argocli` |
| `argo-workflows-executor-image` | `ociImage` | `quay.io/argoproj/argoexec` |
| `argo-workflows-minimal-config` | `yaml` | `minimal-values.yaml` |
| `argo-workflows-production-config` | `yaml` | `production-values.yaml` |

## Configuration notes

| | Minimal | Production |
| --- | --- | --- |
| Controller / server replicas | 1 / 1 | 2 / 2 |
| Auth mode | `server` (no token) | `client` (Kubernetes RBAC) |
| Max concurrent workflows (`parallelism`) | chart default | 50 |
| Prometheus monitoring | off | on |
| PodDisruptionBudgets, anti-affinity, zone spread | off | on |

For SSO, override `server.authModes: [sso]` and `server.sso.*` (issuer, client
ID/secret references, redirect URL).

## Build

```bash
make validate COMPONENT=argo-workflows   # publishes nothing
make airgap   COMPONENT=argo-workflows   # self-contained CTF bundle
```

## Release

Automatic. The component version is the chart version, so a Renovate bump
merged to `main` publishes and signs it — see
[Releasing](../README.md#releasing).
