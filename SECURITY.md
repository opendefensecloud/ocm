# Security Policy

Due to the nature of the Open Defense Cloud products the maintainers take security very seriously.

## Report against the right repository

**This repository contains no application code.** It packages container images
and Helm charts that are built, released and maintained elsewhere as OCM
components. A vulnerability in a packaged application is a vulnerability in the
repository that produces it, not here.

| Finding is in | Report to |
| --- | --- |
| A packaged application — one of its images or its Helm chart | The repository that builds it. Each component's `README.md` names its source. |
| The packaging itself — see below | [this repository](https://github.com/opendefensecloud/ocm/security/advisories/new) |

**In scope here** is the supply chain this repository *is*: the release
workflow, the `Makefile`, the component constructors, the signing
configuration in `.ocmconfig`. Concretely: A component that references an
image it should not, a signature or verification setting that fails to bind an
artifact to its signer, a workflow that leaks a token or lets untrusted input
reach a shell, or a published component whose contents do not match what its
constructor declares.

Version pins for wrapped artifacts are maintained by Renovate. If a wrapped
image is outdated, open a normal issue or let the bump land. This is not a
vulnerability in this repository.

## Supported Versions

A component carries the version of the artifact it packages, so the supported
versions of a packaged application are whatever its own project supports.

This repository backports nothing. A fix to the packaging ships in the next
component version.

## Reporting a Vulnerability

The Open Defense Cloud uses GitHub to allow submission of private security reports.
Please report any security finding **in the packaging** via
[this link](https://github.com/opendefensecloud/ocm/security/advisories/new).
Maintainers will triage your report as soon as possible and get in touch with
you via your report in case they have more questions.

As a security researcher, please report vulnerabilities to the OpenDefenseCloud in a [coordinated vulnerability disclosure](https://cheatsheetseries.owasp.org/cheatsheets/Vulnerability_Disclosure_Cheat_Sheet.html)
fashion. In return, maintainers pledge to engage in good faith and collaborate with security researchers to address and publish vulnerabilities found as soon as possible.

Please understand that the maintainers also do not accept results of dependency scanners without proof that the detected CVE / vulnerability can be used against the affected component's purpose.

## Security Advisories

Advisories are managed through GitHub. Public disclosure of vulnerabilities happens through GitHub.
Please visit [Security Advisories](https://github.com/opendefensecloud/ocm/security/advisories) to review security bulletins published by the maintainers.
