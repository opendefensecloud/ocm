# CLAUDE.md

Guidance for Claude Code (claude.ai/code) when working in this repository.

## Repository Overview

A monorepo that packages cloud-native applications as OCM (Open Component
Model) components and publishes them to ghcr. Each top-level directory holding a
`component-constructor.yaml` is one component.

This repository **packages**; it does not build. Images and Helm charts are
produced and released by their own source repositories (e.g.
`opendefensecloud/dependency-controller`). Nothing here compiles code.

> **This repo uses OCM v2**, the successor toolchain to the v1 CLI still used by
> [opendefensecloud/ocm-components](https://github.com/opendefensecloud/ocm-components).
> Their commands do not work here — see *OCM v2 vs v1* below before copying
> anything across.

## Repository Structure

Flat, one directory per component, uniform:

```text
<component>/
├── component-constructor.yaml   # OCM descriptor — the only place a version lives
├── values.yaml.tpl              # image localization, rendered by ocm-kit
├── minimal-values.yaml          # dev/test configuration
├── production-values.yaml       # production HA configuration
└── README.md
```

`values.yaml.tpl` is linked to the chart resource by the
`opendefense.cloud/helm/values-for` label and rendered by
[`ocm-kit`](https://github.com/opendefensecloud/ocm-kit) (`helmvalues`), which
substitutes the *localized* image references after a transfer. Consumed by
`oscp` and `solution-arsenal` — not an RGD concern.

All components use the OCM name prefix `opendefense.cloud/<component>`.

**Adding a component needs no registration.** The release workflow discovers
every directory containing a `component-constructor.yaml`. Do not add a matrix
entry — there is no matrix. (ocm-components maintains one by hand, which is why
its own CLAUDE.md has to remind contributors to update it.)

## Development Environment

`make setup` installs the pinned OCM v2 CLI into `./bin`. `make help` lists
every target. Also needs `yq` (version derivation) and `helm`.

The Makefile includes `common.mk` from `opendefensecloud/dev-kit` for
`repo-settings` and `update-action-pins`. **CI sets `DEV_KIT=0`** — the
bootstrap fetches `common.mk` from a mutable tag, which does not belong in a job
that signs artifacts. Note `make help` comes from `common.mk`, so it does not
exist under `DEV_KIT=0`.

**dev-kit cannot install OCM v2.** Its recipe pipes `ocm.software/install.sh`,
which is hardwired to the legacy repository — passing a v2 version is silently
ignored and installs v1 latest. This repo installs v2 itself via
`install-cli.sh`. Do not "fix" this by reverting to the dev-kit rule.

## Versioning

**A component's version is the version of the artifact it wraps.** Chart 0.4.0
means component 0.4.0. It is read from the `helmChart` resource
(`make version`); nothing else tracks it — no tag file, no manifest, no version
in a README heading.

Consequence, accepted deliberately: a packaging-only fix has no version of its
own and ships with the next upstream bump.

Never add a second place where a version lives. A README heading carrying a
version drifts the moment Renovate bumps — this already happened in
ocm-components (`cert-manager (v1.20.1)` in the README, `v1.20.2` in the
constructor).

## Releasing

Fully automatic. A Renovate bump merged to `main` is published and signed by the
same run; the tag is written afterwards as a record.

```text
Renovate PR → merge to main → published + signed → tagged
```

Publishing is **idempotent**: a version already in the registry is skipped.

There is deliberately **no tag trigger**. A tag pushed by a workflow using
`GITHUB_TOKEN` does not start another workflow run, so a tag-then-release split
would silently never publish.

The tag is a lightweight, unsigned ref and `required_signatures` covers branches
only — never treat it as provenance. Do not reach for a `sources` entry either;
see the traps table.

## Publishing model

**Descriptor-only** — `make publish` pushes the descriptor; images and charts
stay as references to where they already live in ghcr. Consumers build their own
self-contained bundle with `transfer --copy-resources --recursive`.

A dangling reference cannot be published: OCM resolves every external resource
at build time to compute its digest, so `make validate` fails if a wrapped
artifact is missing.

## Signing

Sigstore keyless via ambient GitHub OIDC. **There are no signing secrets.**
`.ocmconfig` carries the registry credentials and selects the Sigstore signer
over the RSA default. The **verifier lives in `sigstore-verify.yaml`** and is
passed with `--verifier-spec`; a `verifier:` key in `.ocmconfig` is silently
ignored. Signing does not work offline.

The signature is stored inside the component descriptor, not as a registry
artifact — there is nothing for GitHub's package UI to display.

## OCM v2 vs v1 — traps that cost real time

Measured against v1 0.42.0 and v2 0.15.0. Do not rediscover these:

| | |
|---|---|
| `--output` | Every `-o` mode crashes `ocm add component-version` on OCI access types (`cannot encode from unregistered type: ociArtifact`). Also fails with `OCIImage/v1`, so it is the serializer. Pass no `-o`. |
| `--upload-as` | Required for a by-value publish and **not** the default. v2 defaults to `localBlob`, which writes only the descriptor repository and leaves the chart un-pullable. v1 promoted resources by default — the defaults are inverted. |
| `${VAR}` | Expanded natively via `os.Expand`; v1's `--addenv`/envsubst is gone. **An unset variable becomes `""` silently**, yielding `version: ""` rather than an error. |
| `--version` | Gone. v2 takes the version from the constructor, which is why constructors here carry `version: ${OCM_VERSION}` and ocm-components' do not. |
| signing keys | No `--private-key` flag. The signer lives in `signing.config.ocm.software/v1alpha1`; keys come from the credentials graph. |
| normalisation | v2 uses `jsonNormalisation/v4alpha1` + RSASSA-PSS. **v2 signatures do not verify with v1 tooling.** |
| resolvers | `ocm.config.ocm.software/v1` with `prefix`/`priority` is deprecated. Use `resolvers.config.ocm.software/v1alpha1` with `componentNamePattern` globs — first match wins, no fallback. |
| `ocm-setup-action` | v1-only; cannot resolve v2 release assets. |
| verifier spec | The `verifier:` key inside `signing.config.ocm.software/v1alpha1` is **silently ignored**. `ocm verify` logs "no verifier specification file given, using default RSASSA-PSS" and then fails on the Sigstore bundle's media type. The verifier must be a separate file passed with `--verifier-spec`; only the `signer:` is read from the config. |
| docker credentials | OCM does **not** find `~/.docker/config.json` on its own for pushes. Without an explicit `DockerConfig/v1` credentials entry it requests a push token anonymously and ghcr answers 403. A public *pull* works either way, which makes the omission easy to miss. |
| `sources` | **Not covered by the signature.** Measured: two builds differing only in the source commit produce an identical signed digest, and the constructor warns `source content is recorded without a digest and is not verifiable`. Use a resource if it must be signed. |
| source access types | **Not validated at all** — `totalerUnsinn/v9` builds fine. The registered type is `GitHub/v1`; the lowercase `gitHub` is a v1 alias. A typo here is silent. |

## Working here

- **Every command CI runs lives in the Makefile.** The workflow calls `make`, so
  a local run and a CI run cannot drift. If you add a step, add a target.
- **Do not duplicate facts.** Versions live in the constructor, command
  descriptions in `make help`, rationale here. A second copy drifts.
- **Actions are pinned by commit SHA**, enforced by `zizmor` on every PR. Run
  `make update-action-pins` rather than editing pins by hand.
- **Signed commits are required** on `main` (`required_signatures` ruleset) and
  **conventional commits are enforced** (commitlint + PR title check). See
  `CONTRIBUTING.md`.
- Renovate maintains the wrapped versions through jsonata managers over
  `component-constructor.yaml`; do not add `# renovate:` annotations. Six things
  differ from the shared config and are load-bearing:
  - a manager for charts published as `ociArtifact` — the ocm-components one only
    matches `access.type: helm` and would never bump ours;
  - `pinDigests: false` inside constructors — a digest suffix breaks the
    manager's `$split` on `:`;
  - a manager for `OCM_CLI_VERSION` in the Makefile — the shared preset's
    `tools.lock` manager tracks the v1 CLI;
  - `allowedVersions` restricting constructors to unprefixed versions — the image
    repositories publish both `0.5.0` and `v0.5.0`, the chart repository only the
    former, so without it a component mixes both formats;
  - `groupName`/`groupSlug` set to `{{parentDir}}` — one PR per component. The
    shared preset puts every minor update into a single branch, which would
    publish two components off one merge. **Both** keys are required: the preset
    pins `groupSlug`, and `groupName` alone does not override it — the branch
    then comes out named after the literal, un-expanded template;
  - `minimumReleaseAge: null` for constructors — the docker datasource builds its
    release list from the registry tag list, which carries no dates, so no
    release ever gets a `releaseTimestamp` and the window can never be satisfied.
    Updates sit at `pendingChecks: true` indefinitely.

## Not yet adopted

Recorded so they are not mistaken for oversights:

- **RGD / KRO bootstrap.** Two ocm-components components (`cert-manager`,
  `cloudnative-pg`) ship `rgd-template.yaml` + `bootstrap.yaml` for
  self-contained deployment. Nothing here does, and the source repository has
  none to adopt — an RGD would have to be written here.
  Note this is unrelated to `values.yaml.tpl`: seven ocm-components components
  carry a template and no RGD.
- **Per-component tests on kind.** ocm-components' CLAUDE.md requires them; no
  component here has any.
- **SBOM resources.** Deliberate — the wrapped images already carry SBOM
  attestations that survive transfer, and the explicit-attachment contract is an
  open spec PR. See the SBOM section in `README.md` before adding one.
