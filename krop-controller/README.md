# krop-controller

A kcp multicluster-runtime control plane: it watches `ResourceGraphDefinition`
blueprints in a provider workspace, compiles each into an APIExport, and
reconciles the generated instance kind across consumer workspaces.

- **License**: Apache 2.0
- **Source**: [opendefensecloud/krop-controller](https://github.com/opendefensecloud/krop-controller)
- **Configurations**:
  - Minimal (single replica, no leader election, dev/test)
  - Production (2 replicas with leader election, anti-affinity)

## Contents

| Resource | Type | Wraps |
| --- | --- | --- |
| `krop-controller-chart` | `helmChart` | `ghcr.io/opendefensecloud/charts/krop-controller` |
| `krop-controller-image` | `ociImage` | `ghcr.io/opendefensecloud/krop-controller` |
| `krop-controller-minimal-config` | `yaml` | `minimal-values.yaml` |
| `krop-controller-production-config` | `yaml` | `production-values.yaml` |

The image and chart are built and published by the source repository; this
directory only packages them as an OCM component.

Unlike the other components this one wraps a **single image** — there is no
admission webhook, and therefore no TLS or cert-manager dependency.

## Quick Start

The controller talks to a kcp **provider workspace** through a workspace-scoped
kubeconfig, so it needs a Secret holding one:

```bash
kubectl create namespace krop-system

kubectl -n krop-system create secret generic krop-kcp-kubeconfig \
  --from-file=kubeconfig

# The pinned version lives in component-constructor.yaml (make version).
helm install krop-controller \
  oci://ghcr.io/opendefensecloud/charts/krop-controller \
  --namespace krop-system \
  --values krop-controller/minimal-values.yaml \
  --set kcp.kubeconfigSecret.name=krop-kcp-kubeconfig
```

## Configuration notes

**`replicaCount: 2` requires `controller.leaderElect: true`.** Without it every
replica runs the reconciler and they contend over the same blueprints. The
production config sets both; the minimal config runs one replica and leaves
leader election off.

**The kubeconfig Secret is not optional in practice.** Left empty the controller
falls back to in-cluster config, which is not workspace-scoped and fails the
binary's own validation against a real kcp front-proxy.

`hostKubeconfig` is separate and usually stays empty: resources a blueprint
routes to `target: host` are written to the cluster the pod runs in. Set it only
to point the host target at a *different* cluster.

**The chart ships a CRD** (`ResourceGraphDefinition`) in `crds/`. Helm installs
those on first install but never upgrades or removes them, so a CRD change in a
later chart version has to be applied by hand.

RBAC in the hosting cluster is deliberately absent — the controller's authority
lives in kcp and is expressed as kcp-native RBAC bound to its ServiceAccount
identity. See the source repository's `docs/permissions.md`.

## Build

```bash
make validate COMPONENT=krop-controller   # publishes nothing
make airgap   COMPONENT=krop-controller   # self-contained CTF bundle
```

## Release

Automatic. The component version is the chart version, so a Renovate bump
merged to `main` publishes and signs it. Nothing to tag by hand — see
[Releasing](../README.md#releasing).
