# Contributing

Thanks for contributing. This repository packages other projects' images and
charts as OCM components. It builds no application code, so most changes are
small and declarative.

Read [CLAUDE.md](CLAUDE.md) before changing anything: it records the OCM v2
traps that are easy to fall into and expensive to rediscover.

## Signed commits are required

`main` is protected with `required_signatures`. **An unsigned commit cannot be
merged.** The rule is applied by `make repo-settings` from
[dev-kit](https://github.com/opendefensecloud/dev-kit).

SSH signing is the least friction if you already push over SSH:

```bash
git config --global gpg.format ssh
git config --global user.signingkey ~/.ssh/id_ed25519.pub
git config --global commit.gpgsign true
```

Then add the same key to GitHub as a **signing key** (Settings → SSH and GPG
keys → New SSH key → type *Signing Key*). A key added only as an authentication
key will sign locally but show as *Unverified* on GitHub.

For GPG instead, see
[GitHub's guide](https://docs.github.com/en/authentication/managing-commit-signature-verification).

Check before pushing — `git log --show-signature -1`, or:

```bash
git log -5 --format='%h %G? %s'   # G = good signature, N = unsigned
```

## Sign off your commits (DCO)

Certify that you wrote the change and may submit it under the project's licence,
per the [Developer Certificate of Origin](https://developercertificate.org/):

```bash
git commit -s -m "fix: bump dependency-controller to 0.5.0"
```

`-s` appends a `Signed-off-by:` trailer with your `user.name` and `user.email`.
Use a real name and a reachable address.

> This is not enforced in CI today, so nothing will fail if you forget. Sign off
> anyway — retrofitting it across a history means rewriting commits.

To make it automatic:

```bash
git config --global format.signOff true
```

## Commit messages

[Conventional Commits](https://www.conventionalcommits.org/), enforced twice:
`commitlint` checks every commit in a PR, and a separate check validates the PR
title. Allowed types and examples are documented once, in
[dev-kit's CONTRIBUTING](https://github.com/opendefensecloud/dev-kit/blob/main/docs/CONTRIBUTING.md).

Scope with the component where it applies:

```
feat(dependency-controller): add production values for cert-manager TLS
fix: bump quota-controller chart to 0.2.0
ci: pin zizmor action to a commit sha
```

A wrapped image or chart bump is a `fix` — it produces a new component version.

## What a pull request runs

| Check | Does |
| --- | --- |
| Release workflow | Discovers every component and validates each into a throwaway CTF. **Publishes nothing.** |
| Conventional Commits | PR title and every commit message |
| zizmor | Static analysis of the workflows — unpinned actions, template injection, over-broad permissions |

Publishing happens on merge to `main`, not on the PR. See
[Releasing](README.md#releasing).

## Before you open a PR

```bash
make setup                     # pinned OCM v2 CLI into ./bin
make validate COMPONENT=<name> # builds into a throwaway CTF, publishes nothing
```

`make help` lists the rest.

## Adding a component

Create a directory with a `component-constructor.yaml`; the release workflow
discovers it. There is no matrix to update and no registration step.

Ship the conventions the other components use — `minimal-values.yaml`,
`production-values.yaml`, a `values.yaml.tpl` carrying the
`opendefense.cloud/helm/values-for` label, and a `README.md` — add a
`CODEOWNERS` line, and list it in the root `README.md`.

## Two rules that keep this repository small

**Every fact lives in exactly one place.** Versions live in the constructor and
nowhere else — not in a tag, not in a README heading. Command descriptions live
in the Makefile's `##` comments, which `make help` renders. Rationale lives in
`CLAUDE.md`. A second copy is a copy that will drift.

**Every command CI runs lives in the Makefile.** The workflow calls `make`, so a
local run and a CI run cannot disagree. If you add a CI step, add a target.

## Security

Report vulnerabilities per [SECURITY.md](SECURITY.md). A flaw in a *packaged*
application belongs in that application's repository — this one only wraps it.
