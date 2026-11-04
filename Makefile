DEV_KIT ?= 1
ifeq ($(DEV_KIT),1)
DEV_KIT_VERSION := v2.1.0

# A stale cache is dropped BEFORE the include: make would otherwise never run
# the recipe, because the file already exists. (ocm-components writes
# .common.mk-version but never compares it, so a bump there is silently ignored.)
ifneq ($(shell cat .common.mk-version 2>/dev/null),$(DEV_KIT_VERSION))
$(shell rm -f common.mk)
endif

-include common.mk

# Downloads to a unique temp file and moves it into place only once curl
# succeeded, so a partial download is never treated as valid.
common.mk:
	@tmp=$$(mktemp) && trap 'rm -f "$$tmp"' EXIT && \
	curl --fail -sSL "https://raw.githubusercontent.com/opendefensecloud/dev-kit/$(DEV_KIT_VERSION)/common.mk" -o "$$tmp" && \
	mv "$$tmp" $@ && printf '%s' '$(DEV_KIT_VERSION)' > .common.mk-version

else
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)
endif

# dev-kit's ocm rule installs the legacy v1 CLI, so v2 is installed here.
# The release binary is fetched directly and its GitHub build attestation is
# verified before it is installed — no piped installer script.
OCM_CLI_VERSION := 0.22.1
OCM_REPO        := open-component-model/open-component-model
OCM_OS          := $(shell uname -s | tr '[:upper:]' '[:lower:]')
OCM_ARCH        := $(shell uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')
OCM := $(LOCALBIN)/ocm

# Same as common.mk above: an existing binary is never rebuilt, so a version
# bump would keep running the old CLI unless the stale one is dropped first.
ifneq ($(shell cat $(LOCALBIN)/.ocm-version 2>/dev/null),$(OCM_CLI_VERSION))
$(shell rm -f $(OCM))
endif

$(OCM): $(LOCALBIN)
	@test -s $@ && grep -q "$(OCM_CLI_VERSION)" $(LOCALBIN)/.ocm-version 2>/dev/null && exit 0; \
	command -v gh >/dev/null || { echo "error: gh is required to verify the OCM CLI attestation" >&2; exit 1; }; \
	tmp=$$(mktemp) && \
	curl -sfL -o "$$tmp" "https://github.com/$(OCM_REPO)/releases/download/v$(OCM_CLI_VERSION)/ocm-$(OCM_OS)-$(OCM_ARCH)" && \
	gh attestation verify "$$tmp" --repo $(OCM_REPO) >/dev/null && \
	install -m 0755 "$$tmp" $@ && rm -f "$$tmp" && \
	echo $(OCM_CLI_VERSION) > $(LOCALBIN)/.ocm-version && \
	echo "installed and verified ocm $(OCM_CLI_VERSION)"

COMPONENTS := $(patsubst %/component-constructor.yaml,%,$(wildcard */component-constructor.yaml))

COMPONENT ?= dependency-controller
REGISTRY  ?= ghcr.io/opendefensecloud

CONSTRUCTOR    = $(COMPONENT)/component-constructor.yaml
# Read from the constructor rather than derived from the directory:
# artifact-conduit/ publishes as opendefense.cloud/arc.
COMPONENT_NAME = $(shell yq -r '.components[0].name' $(CONSTRUCTOR) 2>/dev/null)
CTF            = ./transport-archive
# --config replaces the .ocmconfig lookup instead of merging, so the credentials
# are passed again in front of the by-value uploader.
AIRGAP_CONFIG  = --config .ocmconfig --config airgap.ocmconfig


# Derived from the wrapped chart: chart 0.4.0 -> component 0.4.0. See README.
# A v prefix on the chart tag is dropped, so arc's chart v0.2.2 -> component 0.2.2.
OCM_VERSION ?= $(patsubst v%,%,$(shell yq -r '[.components[0].resources[] | select(.type == "helmChart") | .version] | .[0] // ""' $(CONSTRUCTOR) 2>/dev/null))

.PHONY: _require-version
_require-version:
	@[ -n "$(OCM_VERSION)" ] || { \
		echo "error: could not derive a version for '$(COMPONENT)'." >&2; \
		echo "       $(CONSTRUCTOR) must contain a resource of type helmChart with a version." >&2; \
		exit 1; }

.PHONY: setup
setup: $(OCM)

.PHONY: components
components: ## List discovered components as a JSON array
	@printf '%s\n' $(COMPONENTS) | jq -R -s -c 'split("\n")[:-1]'

.PHONY: version
version: _require-version ## Print the version derived from the wrapped chart
	@echo "$(OCM_VERSION)"

.PHONY: validate
validate: _require-version $(OCM) ## Build COMPONENT into a throwaway CTF. Publishes nothing.
	@d=$$(mktemp -d) && trap 'rm -rf "$$d"' EXIT && \
	OCM_VERSION=$(OCM_VERSION) $(OCM) add component-version \
		--constructor $(CONSTRUCTOR) --repository "ctf::$$d/ctf"

.PHONY: build
build: _require-version $(OCM) ## Build COMPONENT into ./transport-archive
	rm -rf $(CTF)
	OCM_VERSION=$(OCM_VERSION) $(OCM) add component-version \
		--constructor $(CONSTRUCTOR) --repository ctf::$(CTF)

.PHONY: airgap
airgap: _require-version build ## Self-contained by-value CTF bundle
	rm -rf ./transport-archive-airgap
	$(OCM) transfer component-version $(AIRGAP_CONFIG) \
		"ctf::$(CTF)//$(COMPONENT_NAME):$(OCM_VERSION)" \
		ctf::./transport-archive-airgap --recursive

# Descriptor-only: without an uploader config, resources stay by reference.
# By-value needs oci.uploader.transfer.config.ocm.software/v1alpha1 — the
# localblob uploader in airgap.ocmconfig would leave the chart un-pullable.
.PHONY: publish
publish: _require-version build ## Push the COMPONENT descriptor into REGISTRY (resources stay by reference)
	$(OCM) transfer component-version \
		"ctf::$(CTF)//$(COMPONENT_NAME):$(OCM_VERSION)" \
		"$(REGISTRY)"

# Exit status only, so CI gates on it without repeating REGISTRY.
.PHONY: published
published: _require-version $(OCM) ## Succeed if this version is already published
	@$(OCM) get component-version "$(REGISTRY)//$(COMPONENT_NAME):$(OCM_VERSION)" >/dev/null 2>&1

.PHONY: sign
sign: _require-version $(OCM) ## Sign the published component (Sigstore keyless)
	$(OCM) sign component-version \
		"$(REGISTRY)//$(COMPONENT_NAME):$(OCM_VERSION)" --signature opendefense.cloud

.PHONY: verify
verify: _require-version $(OCM) ## Verify the signature and the signer identity
	$(OCM) verify component-version \
		"$(REGISTRY)//$(COMPONENT_NAME):$(OCM_VERSION)" --signature opendefense.cloud

# --dry-run validates the whole graph without moving the ~53 MB.
# Record only; nothing triggers off it. Idempotent.
.PHONY: tag
tag: _require-version ## Create the release tag for COMPONENT
	@t="$(COMPONENT)/v$(OCM_VERSION)"; \
	repo="$${GITHUB_REPOSITORY:-opendefensecloud/ocm}"; sha="$${GITHUB_SHA:-$$(git rev-parse HEAD)}"; \
	if gh api "repos/$$repo/git/ref/tags/$$t" >/dev/null 2>&1; then echo "tag $$t already exists"; \
	else gh api "repos/$$repo/git/refs" -f ref="refs/tags/$$t" -f sha="$$sha" >/dev/null && echo "created tag $$t"; fi

.PHONY: resolve-check
resolve-check: _require-version $(OCM) ## Assert a consumer can resolve everything
	$(OCM) transfer component-version \
		"$(REGISTRY)//$(COMPONENT_NAME):$(OCM_VERSION)" \
		"ctf::$$(mktemp -d)/probe" $(AIRGAP_CONFIG) \
		--recursive --dry-run   # dry-run writes nothing

# Uses a linked `type: sbom` resource if the constructor has one, otherwise the
# BuildKit attestation in the image index. Fails for an image with neither.
.PHONY: sbom
sbom: _require-version $(OCM) ## Download the SBOMs of every COMPONENT image into ./sboms
	@for r in $$(yq -r '.components[0].resources[] | select(.type == "ociImage") | .name' $(CONSTRUCTOR)); do \
		$(OCM) download resource "$(REGISTRY)//$(COMPONENT_NAME):$(OCM_VERSION)" \
			--identity name=$$r --sbom --output ./sboms/$(COMPONENT)/$$r || exit 1; \
	done

# A transfer stores an artifact at <target>/<path without host>, so two sources
# differing only in host would overwrite each other. Static check over every
# constructor, no registry needed.
CONSTRUCTORS ?= $(wildcard */component-constructor.yaml)

.PHONY: lint-constructors
lint-constructors: ## Check all constructors for image path collisions
	@bad=$$(for f in $(CONSTRUCTORS); do yq '.' "$$f" >/dev/null || echo "$$f: cannot be parsed"; done; \
	for f in $(CONSTRUCTORS); do yq -r '.components[].resources[] | select(.access.imageReference) | .access.imageReference' "$$f" 2>/dev/null; done \
	| sed 's/@.*//' | sort -u | awk '{ i = index($$0, "/"); p = substr($$0, i + 1); h = substr($$0, 1, i - 1); \
		if ((p in host) && host[p] != h) print p ": from both " host[p] " and " h; host[p] = h }'); \
	[ -z "$$bad" ] || { echo "$$bad" | sed 's/^/error: /' >&2; exit 1; }; \
	echo "$(words $(CONSTRUCTORS)) constructors OK"
