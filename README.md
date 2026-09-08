# ocm

[![Build status](https://github.com/opendefensecloud/ocm/actions/workflows/release.yml/badge.svg)](https://github.com/opendefensecloud/ocm/actions/workflows/release.yml)
[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/opendefensecloud/ocm/badge)](https://scorecard.dev/viewer/?uri=github.com/opendefensecloud/ocm)

A monorepo for OCMv2 components.

Packages cloud-native applications (container images, Helm charts and their
configuration) as [Open Component Model](https://ocm.software/) components and
publishes them to ghcr. It builds no application code; images and charts come
from their own source repositories.

> [!WARNING]
> **OCM v2.** The predecessor
> [opendefensecloud/ocm-components](https://github.com/opendefensecloud/ocm-components)
> is pinned to the legacy v1 CLI and its commands do not work here. Layout and
> conventions are kept the same so components can move over with little churn.

## Components

| Component | Wraps | Docs |
| --- | --- | --- |
| `opendefense.cloud/dependency-controller` | controller + webhook images, Helm chart | [README](dependency-controller/README.md) |

## Layout

One directory per component, discovered automatically:

```text
<component>/
├── component-constructor.yaml   # OCM descriptor — the only place a version lives
├── values.yaml.tpl              # image localization, rendered by ocm-kit
├── minimal-values.yaml          # dev/test configuration
├── production-values.yaml       # production HA configuration
└── README.md
```

Everything else is shared: `Makefile` (all commands), `.ocmconfig` (signing),
`renovate.json` (version bumps), `.github/workflows/` (release, Scorecard,
commit and workflow linting).

## Adding a component

Create a directory with a `component-constructor.yaml` — the release workflow
discovers it, there is no matrix to update. Then follow the conventions above
and see [CONTRIBUTING.md](CONTRIBUTING.md).

## Usage

```bash
make setup                       # install the pinned OCM v2 CLI into ./bin
make validate COMPONENT=<name>   # build into a throwaway CTF, publishes nothing
make help                        # every target
```

Targets take `COMPONENT=<name>` and `REGISTRY=<ref>`; `OCM_VERSION` is derived
from the wrapped chart. The Makefile pulls `common.mk` from
[dev-kit](https://github.com/opendefensecloud/dev-kit) for `repo-settings` and
`update-action-pins`.

## Publishing model

`make publish` is **descriptor-only**: the descriptor is pushed, images and
charts stay as references to where they already live in ghcr. Copying them by
value would duplicate bytes inside the same registry.

Consumers build their own self-contained bundle when they need one:

```bash
ocm transfer component-version \
  ghcr.io/opendefensecloud/ocm//opendefense.cloud/dependency-controller:<version> \
  ctf::./bundle --copy-resources --recursive
```

A dangling reference cannot be published: OCM resolves every external resource
at build time to compute its digest, so `make validate` already fails if a
wrapped image or chart is missing. `make resolve-check` re-validates the whole
graph after publishing.

Published paths keep the source image path under the target repository, so the
chart lands at `<REGISTRY>/opendefensecloud/charts/<component>`. The doubled
`opendefensecloud` is expected.

## Releasing

**A component's version is the version of the artifact it wraps.** Chart 0.4.0
means component 0.4.0 read from the `helmChart` resource (`make version`).
There is no second version line to keep in sync.

```text
Renovate bumps the chart/image → merge to main → published + signed → tagged
```

Nothing is tagged by hand and there is no release PR. A push to `main`
publishes every component whose version is not in the registry yet, so the
workflow is safe to re-run. Pull requests validate but publish nothing.

The tag `<component>/v<version>` is a convenience — it lets you check out the
packaging state of a release. It triggers nothing and is an unsigned ref, so the
provenance that counts lives in the descriptor instead: a `sources` entry
records the packaging commit and is covered by the signature.

> [!IMPORTANT]
> A packaging-only fix has **no version of its own** and ships with the next
> upstream release.

## Signing

Sigstore keyless, configured in `.ocmconfig`. **There are no signing secrets:**
`permissions: id-token: write` provides an ambient OIDC token that the signing
handler forwards to cosign, and Fulcio issues a short-lived certificate bound to
the workflow identity.

Verification pins *who* may have signed — excerpt from `.ocmconfig`:

```yaml
certificateOIDCIssuer: https://token.actions.githubusercontent.com
certificateIdentity: https://github.com/opendefensecloud/ocm/.github/workflows/release.yml@refs/heads/main
```

Signing does not work offline; locally you need `SIGSTORE_ID_TOKEN` set.

`.ocmconfig` exists *only* for this. Registry credentials and resolvers are not
needed because v2 resolves the Docker config itself, and no component declares
`componentReferences`.

## Migrating from the v1 repositories

OCM v2 changes enough that v1 commands do not carry over — `--output` crashes on
OCI resources, `--upload-as` defaults the wrong way, `--version` is gone, and v2
signatures do not verify with v1 tooling. The measured list is in
[CLAUDE.md](CLAUDE.md#ocm-v2-vs-v1--traps-that-cost-real-time).

## Licence

The Apache 2.0 [LICENSE](LICENSE) covers **this repository's own content** —
component constructors, values files, the Makefile, workflows and documentation.

**It does not cover the packaged applications.** Each wrapped image and Helm
chart keeps the licence of the project that produces it; see the component's
`README.md` for which, and that project's repository for the terms.

Publishing here is descriptor-only, so this repository redistributes no
third-party artifacts — it references them where they already live. A consumer
who builds a by-value bundle (`transfer --copy-resources`) does redistribute
them, and the upstream licences apply to that copy.
