# solar-agent

The agent of [Solution Arsenal (SolAr)](https://github.com/opendefensecloud/solution-arsenal):
runs on a target cluster, watches the Flux releases SolAr delivered there and
reports their state back to SolAr as a `TargetReport`.

- **License**: Apache 2.0 (of the upstream project, not of this packaging)
- **Source**: [opendefensecloud/solution-arsenal](https://github.com/opendefensecloud/solution-arsenal)
- **Requires**: a running `solution-arsenal` with agent credentials enabled

## Contents

| Resource | Type | Wraps |
| --- | --- | --- |
| `solar-agent-chart` | `helmChart` | `ghcr.io/opendefensecloud/charts/solar-agent` |
| `helm-values-template` | `yaml` | `values.yaml.tpl` |
| `solar-agent-image` | `ociImage` | `ghcr.io/opendefensecloud/solar-agent` |

The image and chart are built and published by the source repository; this
directory only packages them as an OCM component.

## Usage

SolAr delivers the agent like any catalog component: a `Release` annotated
`solar.opendefense.cloud/target-credential: "true"`, bound to Targets through a
`Profile`. SolAr renders each Target's connection values (apiserver kubeconfig,
token, Target name) into the chart, so there are no minimal or production
values here. See [Setting up the solar-agent](https://github.com/opendefensecloud/solution-arsenal/blob/main/docs/operator-manual/solar-agent.md).

`values.yaml.tpl` only sets the image. It calls `pullSecretFor`, which SolAr's
renderer provides, so it renders in SolAr and not with plain `ocm-kit`.

The resource names must not change: the values template and SolAr's tests
look them up by name.

## Build

```bash
make validate COMPONENT=solar-agent   # publishes nothing
make airgap   COMPONENT=solar-agent   # self-contained CTF bundle
```

## Release

Automatic. The component version is the chart version, so a Renovate bump
merged to `main` publishes and signs it, see
[Releasing](../README.md#releasing).
