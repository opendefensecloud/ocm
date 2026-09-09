DEV_KIT ?= 1
ifeq ($(DEV_KIT),1)
DEV_KIT_VERSION := v1.0.8

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
OCM_CLI_VERSION := 0.15.0
OCM_REPO        := open-component-model/open-component-model
OCM_OS          := $(shell uname -s | tr '[:upper:]' '[:lower:]')
OCM_ARCH        := $(shell uname -m | sed 's/x86_64/amd64/; s/aarch64/arm64/')
OCM := $(LOCALBIN)/ocm

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
COMPONENT_NAME = opendefense.cloud/$(COMPONENT)
CTF            = ./transport-archive

# Derived from the wrapped chart: chart 0.4.0 -> component 0.4.0. See README.
OCM_VERSION ?= $(shell yq -r '[.components[0].resources[] | select(.type == "helmChart") | .version] | .[0] // ""' $(CONSTRUCTOR) 2>/dev/null)

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
    # No -o flag: every output mode crashes on OCI access types in 0.15.0.
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
    # --upload-as omitted: no-op against a CTF target.
	$(OCM) transfer component-version \
		"ctf::$(CTF)//$(COMPONENT_NAME):$(OCM_VERSION)" \
		ctf::./transport-archive-airgap \
		--copy-resources --recursive

# Descriptor-only. For by-value add --copy-resources --recursive --upload-as
# ociArtifact — that flag is required and is NOT the default. See README.
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
		"$(REGISTRY)//$(COMPONENT_NAME):$(OCM_VERSION)" --signature opendefense.cloud \
		--verifier-spec sigstore-verify.yaml

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
		"ctf::$$(mktemp -d)/probe" \
		--copy-resources --recursive --dry-run   # dry-run writes nothing
