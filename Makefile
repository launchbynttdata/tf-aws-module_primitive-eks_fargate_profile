# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Include custom values from .lcafenv. Repository root is assumed to be the working directory.
# Including overriding values in this file is preferred over modifying the contents below.
LCAF_ENV_FILE = .lcafenv
-include $(LCAF_ENV_FILE)

# Source repository for repo manifests
REPO_MANIFESTS_URL ?= https://github.com/launchbynttdata/launch-common-automation-framework.git
# Branch of source repository for repo manifests. Other tags not currently supported.
REPO_BRANCH ?= refs/tags/1.8.1
# Path to seed manifest in repository referenced in REPO_MANIFESTS_URL
REPO_MANIFEST ?= manifests/terraform_modules/seed/manifest.xml

# Settings to pull in Nexient version of (google) repo utility that supports environment substitution:
REPO_URL ?= https://github.com/launchbynttdata/git-repo.git
# Branch of the repository referenced by REPO_URL to use
REPO_REV ?= main
export REPO_REV REPO_URL

# Example variable to substituted after init, but before sync in repo manifests.
GITBASE ?= https://github.com/launchbynttdata/
GITREV ?= main
export GITBASE GITREV

# Set to true in a pipeline context
IS_PIPELINE ?= false

IS_AUTHENTICATED ?= false

JOB_NAME ?= job
JOB_EMAIL ?= job@job.job

COMPONENTS_DIR = components
# -include $(COMPONENTS_DIR)/Makefile

MODULE_DIR ?= ${COMPONENTS_DIR}/module

SHELL := /bin/bash

# ---------------------------------------------------------------------------
# Common orchestration targets
# ---------------------------------------------------------------------------
.PHONY: help
help: # print all available targets in this Makefile
	@echo "Available targets:" && \
	awk -F':' '/^[A-Za-z0-9][A-Za-z0-9_\/.\-]*:([^=]|$$)/ {print $$1}' $(MAKEFILE_LIST) | \
		sort -u | sed 's/^/  /'

.PHONY: check
check: # run all lint and test targets
	$(MAKE) lint
	$(MAKE) test

.PHONY: lint
lint::
	@true

.PHONY: test
test::
	@true

# ---------------------------------------------------------------------------
# Platform development environment targets (previously from components/platform)
# ---------------------------------------------------------------------------
export
OS := $(shell uname -s)

DOCKER ?= docker
COMPOSE ?= docker compose

DTIME := $(shell date +'%s')

.PHONY: platform/devenv/configure
platform/devenv/configure:
	@echo $(OS)
	@if [ "${OS}" = "Darwin" ]; then \
		echo "Configuring local dev environment for macOS" && \
		$(MAKE) platform/devenv/configure-mac; \
	elif [ "${OS}" = "Linux" ]; then \
		echo "Configuring local dev environment for linux or WSL" && \
		$(MAKE) platform/devenv/configure-linux-wsl; \
	else \
		$(MAKE) platform/devenv/not-supported; \
	fi

.PHONY: platform/devenv/configure-mac
platform/devenv/configure-mac: DHOME = $(HOME)/.docker
platform/devenv/configure-mac: platform/devenv/configure-common
	# macOS specific configure steps here
	@echo "Your local dev env is configured for macOS"

.PHONY: platform/devenv/configure-linux-wsl
platform/devenv/configure-linux-wsl: DHOME = $(shell wslpath -a $$(cmd.exe /C 'echo %USERPROFILE%'))/.docker
platform/devenv/configure-linux-wsl: platform/devenv/linux-setup platform/devenv/configure-common
	# linux specific configure steps here
	@echo "Your local dev env is configured for linux or WSL"

.PHONY: platform/devenv/not-supported
platform/devenv/not-supported:
	@echo "ERROR: Operating system not supported!"
	@echo "INFO:  Local dev setup is currently only supported for macOS, linux or WSL on Windows"

.PHONY: platform/devenv/configure-common
platform/devenv/configure-common: platform/devenv/configure-shell platform/devenv/configure-global-pkgs platform/devenv/configure-local-pkgs platform/devenv/configure-docker-buildx

.PHONY: platform/devenv/linux-setup
platform/devenv/linux-setup:
	@sudo apt-get update && \
	sudo -s apt-get install -y build-essential --fix-missing && \
	default_shell="$$(grep "^$$USER:" /etc/passwd | cut -d: -f7)" && \
	if [ $${default_shell} = "/bin/bash" ]; then \
		sudo -s apt-get install -y zsh && \
		ZSH_PATH=$$(which zsh) && \
		sudo chsh -s $$ZSH_PATH $$USER; \
	fi && \
	sudo apt-get install -y python3.10-venv; \
	touch $${HOME}/.zshrc;

.PHONY: platform/devenv/configure-shell
platform/devenv/configure-shell:
	@if [ -d $${HOME}/.dso_zsh ]; then \
		rm -rf $${HOME}/.dso_zsh; \
	fi
	@git clone https://github.com/launchbynttdata/dso-zsh.git $${HOME}/.dso_zsh;
	@if [ ! -d $${HOME}/.m2 ]; then \
		mkdir -p $${HOME}/.m2; \
	fi
	@cp -p $${HOME}/.dso_zsh/settings.xml $${HOME}/.m2/settings.xml
	@if [ ! -d $${HOME}/.oh-my-zsh ]; then \
		rm -rf $${HOME}/.oh-my-zsh; \
		unset ZSH && curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | /bin/bash; \
		git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git $${HOME}/.oh-my-zsh/custom/plugins/fast-syntax-highlighting; \
		git clone https://github.com/djui/alias-tips.git $${HOME}/.oh-my-zsh/custom/plugins/alias-tips; \
	fi
	@if [ -f $${HOME}/.zshrc ]; then \
		mv $${HOME}/.zshrc $${HOME}/.zshrc-$$(date +'%s'); \
	fi
	@cp $${HOME}/.dso_zsh/.zshrc $${HOME}/.zshrc;
	@if [ -d $${HOME}/.dso_magicdust ]; then \
		rm -rf $${HOME}/.dso_magicdust; \
	fi
	@git clone https://github.com/launchbynttdata/magicdust.git $${HOME}/.dso_magicdust;
	@if [ -d $${HOME}/.dso_magicdust ]; then \
		cd $${HOME}/.dso_magicdust; \
		python3 -m venv $${HOME}/.venv-dso; \
		source $${HOME}/.venv-dso/bin/activate; \
		python setup.py install; \
		pip install . ; \
		echo "source $${HOME}/.venv-dso/bin/activate" >> $${HOME}/.zshrc ; \
		echo "source $${HOME}/.venv-dso/bin/activate" >> $${HOME}/.bashrc ; \
	fi

.PHONY: platform/devenv/configure-global-pkgs
platform/devenv/configure-global-pkgs:
	@curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /bin/bash
	@BREW='eval "$$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'; \
	if [ "${OS}" = "Darwin" ]; then \
		if [ "$$(/usr/bin/uname -m)" = "arm64" ]; then \
			BREW='eval "$$(/opt/homebrew/bin/brew shellenv)"'; \
		else \
			BREW='eval "$$(/usr/local/bin/brew shellenv)"'; \
		fi; \
	fi; \
	eval $$BREW; \
	echo $$BREW >> $${HOME}/.bashrc; \
	echo $$BREW >> $${HOME}/.zshrc; \
	brew install gcc unzip jq yq aws-sso-util coursier jinja2-cli fzf aws-sso-util

.PHONY: platform/devenv/configure-docker-buildx
platform/devenv/configure-docker-buildx:
	-$(DOCKER) buildx create --use

.PHONY: platform/devenv/configure-local-pkgs
platform/devenv/configure-local-pkgs:
	# @if [ ! -d $${HOME}/.asdf ] || [ ! -d $${HOME}/.asdf/.git ]; then \
	# 	git clone https://github.com/asdf-vm/asdf.git $${HOME}/.asdf --branch v0.11.3; \
	# fi
	# ASDF='. "$${HOME}/.asdf/asdf.sh"' && \
	# echo $$ASDF >> $${HOME}/.bashrc; \
	# ASDF_COMPLETIONS='. "$${HOME}/.asdf/completions/asdf.bash"' && \
	# echo $$ASDF_COMPLETIONS >> $${HOME}/.bashrc; \
	# source $${HOME}/.bashrc && \
	# cut -d' ' -f1 .tool-versions | xargs -I{} asdf plugin add {}
	# asdf install

# ---------------------------------------------------------------------------
# Release automation targets (previously from components/platform)
# ---------------------------------------------------------------------------
mode ?= auto

.PHONY: predict
predict:
	sbot predict version

.PHONY: release
release:
	sbot update version
	sbot release version -m $(mode)
	sbot push version

# ---------------------------------------------------------------------------
# Go test & lint targets (previously from components/module/tasks/golang)
# ---------------------------------------------------------------------------

# Binaries
GO ?= go
GOLANGCI_LINT ?= golangci-lint
TEE ?= tee
GREP ?= grep
FIND ?= find

# Variables
GO_TEST_DIRECTORIES ?= tests
GO_LINT_TIMEOUT ?= 5m
GO_TEST_TIMEOUT ?= 2h
GO_TEST_READONLY_DIRECTORY ?= post_deploy_functional_readonly
TEST_RUN_ONLY_READONLY = #intentionally empty
TEST_RUN_EXCLUDE_READONLY = -v
GOLANGCI_LINT_CONFIG ?= .golangci.yaml
DISABLE_MAKE_CHECK_LINT ?= false
GO_CURRENT_DIR = $(notdir $(shell pwd))

# If ARM_SUBSCRIPTION_ID is not already set, attempt to fetch it via az.
export ARM_SUBSCRIPTION_ID ?= $(shell command -v az >/dev/null 2>&1 && az account show | jq -r .id)

# Checks for Go files in the GO_TEST_DIRECTORIES. If they exist, runs the default configuration for golangci-lint
# https://golangci-lint.run/usage/quick-start/
define go_lint
	$(FIND) $(1)/ -name '*.go' | $(GREP) -q '\.go' || exit 0; $(GOLANGCI_LINT) run -c $(GOLANGCI_LINT_CONFIG) --timeout $(GO_LINT_TIMEOUT) -v ./$(1)/...;

endef

# Check for Go files. If they exist, run tests. Either runs only readonly tests(default) or tests except readonly ones
define go_test
	$(FIND) $(1)/ -name '*.go' |$(GREP) $(2) $(GO_TEST_READONLY_DIRECTORY) | $(GREP) -q '\.go' || exit 0; $(GO) test -v -count=1 -timeout=$(GO_TEST_TIMEOUT) $$($(GO) list ./$(1)/...|$(GREP) $(2)  $(GO_TEST_READONLY_DIRECTORY)) ;

endef

# Tasks
.PHONY: go/test/environment/az
go/test/environment/az:
ifeq (,$(ARM_SUBSCRIPTION_ID))
	$(error "ARM_SUBSCRIPTION_ID was not set and `az` was not found in your PATH.")
else
	@echo "Terratest will use Azure Subscription ID $$ARM_SUBSCRIPTION_ID"
endif

.PHONY: go/test/environment/aws
go/test/environment/aws:
	@echo "No environment configuration for AWS is defined."

.PHONY: go/test/environment/gcp
go/test/environment/gcp:
	@echo "No environment configuration for GCP is defined."

# Performs any environmental setup required for a cloud provider based on the name of the repository.
.PHONY: go/test/environment
go/test/environment:
ifneq (,$(findstring tf-aws,$(GO_CURRENT_DIR)))
	$(MAKE) go/test/environment/aws
else ifneq (,$(findstring tf-az,$(GO_CURRENT_DIR)))
	$(MAKE) go/test/environment/az
else ifneq (,$(findstring tf-gcp,$(GO_CURRENT_DIR)))
	$(MAKE) go/test/environment/gcp
else
	@echo "Unrecognized module type, no environmental setup will be performed."
endif

.PHONY: go/list
go/list :
	@echo -n "Test dirs: "
	@echo $(GO_TEST_DIRECTORIES) | tr ' ' '\n' | sort

.PHONY: go/lint
go/lint :
	$(foreach test_dir,$(GO_TEST_DIRECTORIES),$(call go_lint,$(test_dir)))

.PHONY: go/test
go/test : go/test/environment
	$(foreach test_dir,$(GO_TEST_DIRECTORIES),$(call go_test,$(test_dir),$(TEST_RUN_EXCLUDE_READONLY)))

.PHONY: go/readonly_test
go/readonly_test:
	$(foreach test_dir,$(GO_TEST_DIRECTORIES),$(call go_test,$(test_dir),$(TEST_RUN_ONLY_READONLY)))

.PHONY: lint
lint::
ifeq ($(DISABLE_MAKE_CHECK_LINT),false)
	$(MAKE) go/lint
else
	$(info "make go/lint has been disabled!")
endif

.PHONY: test
test:: tfmodule/plan
	$(MAKE) go/test

# ---------------------------------------------------------------------------
# Terraform module targets (previously from components/module/tasks/modules)
# ---------------------------------------------------------------------------

# Binaries
TERRAFORM ?= terraform
RM ?= rm -rf
CONFTEST ?= conftest
REGULA ?= regula
TFLINT ?= tflint
FIND ?= find

# Variables
ALL_TF_MODULES = $(shell $(call list_terraform_modules))
ALL_EXAMPLES = $(shell $(call list_examples))
POLICY_DIRECTORY ?= components/policy
TFLINT_CONFIG ?= .tflint.hcl
VAR_FILE ?= test.tfvars
# Temporary value until we can relocate policies and validate; will be defaulted
# to 'high' in the future with the option to change this via .lcafenv
REGULA_SEVERITY ?= off
AWS_PROFILE ?= default
AWS_REGION ?= us-east-2

# Functions
define check_terraform_fmt
	echo && echo "Formatting Terraform files ...";
	$(TERRAFORM) fmt -recursive;

endef

define clean_terraform_module
	$(RM) $(1)/.terraform* $(1)/terraform.*;

endef

define conftest_terraform_module
	echo && echo "Conftest $(1) ...";
	echo $(CONFTEST) test $(1)/terraform.tfplan.json --all-namespaces -p $(POLICY_DIRECTORY) -p $(MODULE_DIR)/custom_policy/policy;
	$(CONFTEST) test $(1)/terraform.tfplan.json --all-namespaces -p $(POLICY_DIRECTORY) -p $(MODULE_DIR)/custom_policy/policy;

endef

define regula_terraform_module
	echo && echo "Regula $(1) ...";
	echo $(REGULA) run $(1)/terraform.tfplan.json --input-type tf-plan --severity $(REGULA_SEVERITY) --include $(POLICY_DIRECTORY) --include $(MODULE_DIR)/custom_policy/policy
	$(REGULA) run $(1)/terraform.tfplan.json --input-type tf-plan --severity $(REGULA_SEVERITY) --include $(POLICY_DIRECTORY) --include $(MODULE_DIR)/custom_policy/policy

endef

define init_terraform_module
	echo && echo "Initializing $(1) ...";
	$(TERRAFORM) -chdir=$(1) init -backend=false -input=false;

endef

define list_terraform_modules
	$(FIND) . -path "*/.terraform" -prune -o -name "main.tf" -not -path '*pipeline*' -not -path '*examples*' -exec dirname {} \;;

endef

define list_examples
	$(FIND) ./examples -path "*/.terraform" -prune -o -name "main.tf" -not -path '*pipeline*' -exec dirname {} \; 2>/dev/null
endef

define aws_provider
provider "aws" {\n  region  = "$(AWS_REGION)"\n  profile = "$(AWS_PROFILE)"\n}\n\nprovider "aws" {\n  alias   = "global"\n  region  = "us-east-1"\n  profile = "$(AWS_PROFILE)"\n}\n
endef

define azurerm_provider
provider "azurerm" {\n  skip_provider_registration = true\n  features {\n    resource_group {\n      prevent_deletion_if_contains_resources = false\n    }\n  }\n}\n
endef

define azapi_provider
provider "azapi" {\n  use_cli = true\n  use_msi = false\n}\n
endef

define azuredevops_provider
provider "azuredevops" {}\n
endef

define provider_file_path
$(1)/provider.tf
endef

define add_provider_details
	$(if $(findstring hashicorp/aws,$(2)),grep -qs "aws" $(1) || bash -c 'echo -e "$(call aws_provider)"' >> $(1),)
	$(if $(findstring azure/azapi,$(2)),grep -qs "azapi" $(1) || bash -c 'echo -e "$(call azapi_provider)"' >> $(1),)
	$(if $(findstring microsoft/azuredevops,$(2)),grep -qs "azuredevops" $(1) || bash -c 'echo -e "$(call azuredevops_provider)"' >> $(1),)
	$(if $(findstring hashicorp/azurerm,$(2)),grep -qs "azurerm" $(1) || bash -c 'echo -e "$(call azurerm_provider)"' >> $(1),)
endef

define create_example_providers
	$(eval PROVIDER_FILE_PATH:=$(call provider_file_path,$(1)))
	$(foreach PROVIDER,$(shell terraform providers | sed -re 's/.+\[(.+\/.+\/.+)\].+/\1/g' | grep registry | sort | uniq),$(call add_provider_details,$(PROVIDER_FILE_PATH),$(PROVIDER)))
endef

define plan_terraform_module
	echo && echo "Planning $(1) ...";
	$(TERRAFORM) -chdir=$(1) plan -input=false -out=terraform.tfplan -var-file $(VAR_FILE);
	echo && echo "Creating JSON plan output for $(1) ...";
	cd $(1) && $(TERRAFORM) show -json ./terraform.tfplan > ./terraform.tfplan.json;

endef

define tflint_terraform_module
	echo && echo "Linting $(1) ...";
	(cd $(1) && TF_LOG=info $(TFLINT) -c $(TFLINT_CONFIG) || TF_LOG=info $(TFLINT) -c ../../$(TFLINT_CONFIG)) || exit 1;

endef

define validate_terraform_module
	echo && echo "Validating $(1) ...";
	$(TERRAFORM) -chdir=$(1) validate || exit 1;

endef

.PHONY: tfmodule/all
tfmodule/all: lint

.PHONY: tfmodule/clean
tfmodule/clean :
	@$(foreach module,$(ALL_TF_MODULES),$(call clean_terraform_module,$(module)))

.PHONY: tfmodule/fmt
tfmodule/fmt :
	$(TERRAFORM) fmt -recursive;

.PHONY: tfmodule/init
tfmodule/init :
	@$(foreach module,$(ALL_TF_MODULES),$(call init_terraform_module,$(module)))
	@$(foreach module,$(ALL_EXAMPLES),$(call init_terraform_module,$(module)))

.PHONY: tfmodule/lint
tfmodule/lint : tfmodule/init
	@$(call check_terraform_fmt)
	@$(foreach module,$(ALL_TF_MODULES),$(call tflint_terraform_module,$(module)))
	@$(foreach module,$(ALL_TF_MODULES),$(call validate_terraform_module,$(module)))
	@$(foreach module,$(ALL_EXAMPLES),$(call tflint_terraform_module,$(module)))
	@$(foreach module,$(ALL_EXAMPLES),$(call validate_terraform_module,$(module)))

.PHONY: tfmodule/list
tfmodule/list :
	@echo -n "Modules: "
	@echo $(ALL_TF_MODULES) | tr ' ' '\n' | sort
	@echo -n "Examples: "
	@echo $(ALL_EXAMPLES) | tr ' ' '\n' | sort

.PHONY: tfmodule/plan
tfmodule/plan : tfmodule/init
	@$(foreach module,$(ALL_EXAMPLES),$(call plan_terraform_module,$(module)))

.PHONY: tfmodule/test/regula
tfmodule/test/regula :
	@$(foreach module,$(ALL_EXAMPLES),$(call regula_terraform_module,$(module)))

.PHONY: tfmodule/test/conftest
tfmodule/test/conftest :
	@$(foreach module,$(ALL_EXAMPLES),$(call conftest_terraform_module,$(module)))

.PHONY: tfmodule/pre_deploy_test
tfmodule/pre_deploy_test : tfmodule/clone_custom_rules
	@$(foreach example,$(ALL_EXAMPLES),$(call init_terraform_module,$(example)))
	@$(foreach example,$(ALL_EXAMPLES),$(call plan_terraform_module,$(example)))
	@$(foreach example,$(ALL_EXAMPLES),$(call conftest_terraform_module,$(example)))
	@$(foreach example,$(ALL_EXAMPLES),$(call regula_terraform_module,$(example)))

.PHONY: tfmodule/post_deploy_test
tfmodule/post_deploy_test :

.PHONY: tfmodule/clone_custom_rules
tfmodule/clone_custom_rules :
	-rm -rf $(MODULE_DIR)/custom_policy
ifeq ($(origin CUSTOM_POLICY_REPO),undefined)
	mkdir -p $(MODULE_DIR)/custom_policy/policy
else
	git clone $(CUSTOM_POLICY_REPO) $(MODULE_DIR)/custom_policy
endif

.PHONY: tfmodule/create_example_providers
tfmodule/create_example_providers : tfmodule/init
	@$(if $(findstring aws.global,$(shell grep -se "\s*provider\s*=" *.tf || true)),$(call create_example_providers,.),)
	@$(foreach example,$(ALL_EXAMPLES),$(call create_example_providers,$(example)))

.PHONY: lint
lint::
	$(MAKE) tfmodule/create_example_providers
	$(MAKE) tfmodule/lint

.PHONY: test
test::
	$(MAKE) tfmodule/clone_custom_rules
	$(MAKE) tfmodule/create_example_providers
	$(MAKE) tfmodule/plan
	$(MAKE) tfmodule/test/conftest
	$(MAKE) tfmodule/test/regula

PYTHON3_INSTALLED = $(shell which python3 > /dev/null 2>&1; echo $$?)
MISE_INSTALLED = $(shell which mise > /dev/null 2>&1; echo $$?)
ASDF_INSTALLED = $(shell which asdf > /dev/null 2>&1; echo $$?)
REPO_INSTALLED = $(shell which repo > /dev/null 2>&1; echo $$?)
GIT_USER_SET = $(shell git config --get user.name > /dev/null 2>&1; echo $$?)
GIT_EMAIL_SET = $(shell git config --get user.email > /dev/null 2>&1; echo $$?)

.PHONY: configure-git-hooks
configure-git-hooks: configure-dependencies
ifeq ($(PYTHON3_INSTALLED), 0)
	pre-commit install
else
	$(error Missing python3, which is required for pre-commit. Install python3 and rerun.)
endif

ifeq ($(IS_PIPELINE),true)
.PHONY: git-config
git-config:
	@set -ex; \
	git config --global user.name "$(JOB_NAME)"; \
	git config --global user.email "$(JOB_EMAIL)"; \
	git config --global color.ui false

configure: git-config
endif

ifeq ($(IS_AUTHENTICATED),true)
.PHONY: git-auth
git-auth:
	$(call config,Bearer $(GIT_TOKEN))

define config
	@set -ex; \
	git config --global http.extraheader "AUTHORIZATION: $(1)"; \
	git config --global http.https://gerrit.googlesource.com/git-repo/.extraheader ''; \
	git config --global http.version HTTP/1.1;
endef

configure: git-auth
endif

.PHONY: configure-dependencies
configure-dependencies:
ifeq ($(MISE_INSTALLED), 0)
	@echo "Installing dependencies using mise"
	@awk -F'[ #]' '$$NF ~ /https/ {system("mise plugin install " $$1 " " $$NF " --yes")} $$1 ~ /./ {system("mise install " $$1 " " $$2 " --yes")}' ./.tool-versions
else ifeq ($(ASDF_INSTALLED), 0)
	@echo "Installing dependencies using asdf-vm"
	@awk -F'[ #]' '$$NF ~ /https/ {system("asdf plugin add " $$1 " " $$NF)} $$1 ~ /./ {system("asdf plugin add " $$1 "; asdf install " $$1 " " $$2)}' ./.tool-versions
else
	$(error Missing supported dependency manager. Install asdf-vm (https://asdf-vm.com/) or mise (https://mise.jdx.dev/) and rerun)
endif

.PHONY: configure
configure: configure-git-hooks
ifneq ($(and $(GIT_USER_SET), $(GIT_EMAIL_SET)), 0)
	$(error Git identities are not set! Set your user.name and user.email using 'git config' and rerun)
endif
ifeq ($(REPO_INSTALLED), 0)
	echo n | repo --color=never init --no-repo-verify \
		-u "$(REPO_MANIFESTS_URL)" \
		-b "$(REPO_BRANCH)" \
		-m "$(REPO_MANIFEST)"
	repo envsubst
	repo sync
else
	$(error Missing Repo, which is required for platform sync. Install Repo (https://gerrit.googlesource.com/git-repo) and rerun.)
endif

# The first line finds and removes all the directories pulled in by repo
# The second line finds and removes all the broken symlinks from removing things
# https://stackoverflow.com/questions/42828021/removing-files-with-rm-using-find-and-xargs
.PHONY: clean
clean:
	-repo list | awk '{ print $1; }' | cut -d '/' -f1 | uniq | xargs rm -rf
	find . -type l ! -exec test -e {} \; -print | xargs rm -rf

.PHONY: init-clean
init-clean:
	rm -rf .git
	git init --initial-branch=main
ifneq (,$(wildcard ./TEMPLATED_README.md))
	mv TEMPLATED_README.md README.MD
endif

.PHONY: init-module
init-module:
	@echo "Initializing module from template..."
	@REPO_URL=$$(git config --get remote.origin.url); \
	if [ -z "$$REPO_URL" ]; then \
		echo "Error: Could not determine git repository URL. Make sure this is a git repository with a remote origin."; \
		exit 1; \
	fi; \
	echo "Repository URL: $$REPO_URL"; \
	REPO_PATH=$$(echo $$REPO_URL | sed -E 's#(https://|git@)##' | sed -E 's#:#/#' | sed -E 's#\.git$$##'); \
	echo "Repository Path: $$REPO_PATH"; \
	MODULE_NAME=$$(basename $$REPO_URL .git); \
	echo "Module Name: $$MODULE_NAME"; \
	echo "Updating go.mod..."; \
	sed -i.bak "s#github.com/launchbynttdata/tf-aws-module-template#$$REPO_PATH#g" go.mod && rm go.mod.bak; \
	echo "Updating test files..."; \
	find tests -type f -name "*.go" -exec sed -i.bak "s#github.com/launchbynttdata/tf-aws-module-template#$$REPO_PATH#g" {} \; -exec rm {}.bak \;; \
	echo "Running go mod tidy..."; \
	go mod tidy; \
	echo ""; \
	echo "Removing detect-secrets baseline..."; \
	rm -f .secrets.baseline; \
	echo "✅ Module initialization complete!"; \
	echo ""; \
	echo "Next steps:"; \
	echo "  1. Review and update the module files (main.tf, variables.tf, outputs.tf)"; \
	echo "  2. Update the examples in the examples/ directory"; \
	echo "  3. Update test implementations in tests/testimpl/"; \
	echo "  4. Run 'make configure' to set up your development environment"; \
	echo "  5. Run 'make check' to validate your changes"

.PHONY: secrets-baseline
secrets-baseline:
	@echo "Creating new detect-secrets baseline..."
	detect-secrets scan > .secrets.baseline
	@echo "✅ Secrets baseline created successfully!"
	@echo "Review .secrets.baseline to ensure no false positives are included."
