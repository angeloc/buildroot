################################################################################
#
# This file contains the package cache: the result of the build of each
# package, stored and restored instead of building it again (see
# BR2_PACKAGE_CACHE).
#
################################################################################

# Package cache (BR2_PACKAGE_CACHE): when a package is downloaded, its
# result is looked up with a key made of its build record, the Buildroot
# files, the host tools and the keys of its dependencies; restored when
# found, else stored once installed (support/scripts/package-cache).

PACKAGE_CACHE_FORMAT = 1
PACKAGE_CACHE_DIR = $(call qstrip,$(BR2_PACKAGE_CACHE_DIR))
PACKAGE_CACHE_SCRIPT = $(TOPDIR)/support/scripts/package-cache

# The hash of what all the packages are built with, computed once: the
# Buildroot files (except the tests and the files made while using it,
# e.g. .config), the host system and tools, and with BR2_REPRODUCIBLE,
# SOURCE_DATE_EPOCH.
PACKAGE_CACHE_GLOBAL_CMD = \
	{ cd $(TOPDIR) && { \
		ls -1 Makefile Makefile.legacy Config.in Config.in.legacy 2>/dev/null; \
		find arch system support -path support/testing -prune -o \
			-name __pycache__ -prune -o -type f -print; \
		find package toolchain toolchain/toolchain-external boot -maxdepth 1 -type f; \
	} | grep -v -e '\.pyc$$' -e '~$$' -e '\.orig$$' -e '\.rej$$' | \
	LC_ALL=C sort | tr '\n' '\0' | xargs -0 $(SHA256SUM); \
	uname -m; (. /etc/os-release 2>/dev/null; echo "$$ID $$VERSION_ID"); \
	$(HOSTCC_NOCCACHE) --version | head -1; $(HOSTCXX_NOCCACHE) --version | head -1; \
	ld --version | head -1; ldd --version 2>&1 | head -1; \
	python3 --version; perl -e 'print "$$^V\n"'; echo $(MAKE_VERSION); \
	$(TAR) --version | head -1; \
	$(if $(BR2_CMAKE_HOST_DEPENDENCY),,$(BR2_CMAKE) --version | head -1;) \
	$(if $(BR2_REPRODUCIBLE),echo $(SOURCE_DATE_EPOCH);) } 2>&1 | $(SHA256SUM) | cut -d' ' -f1
PACKAGE_CACHE_GLOBAL = \
	$(eval PACKAGE_CACHE_GLOBAL := $(shell $(PACKAGE_CACHE_GLOBAL_CMD)))$(PACKAGE_CACHE_GLOBAL)

# The directories of all the packages, and of those built, computed once.
pkg-cache-pkgdirs = $(abspath $(foreach p,$(1),$($(call UPPERCASE,$(p))_PKGDIR)))
PACKAGE_CACHE_PKGDIRS_ALL = \
	$(eval PACKAGE_CACHE_PKGDIRS_ALL := $(call pkg-cache-pkgdirs,$(PACKAGES_ALL)))$\
	$(PACKAGE_CACHE_PKGDIRS_ALL)
PACKAGE_CACHE_PKGDIRS_BUILT = \
	$(eval PACKAGE_CACHE_PKGDIRS_BUILT := $(call pkg-cache-pkgdirs,$(sort $(foreach i,$(PACKAGES), \
		$(i) $($(call UPPERCASE,$(i))_FINAL_RECURSIVE_DEPENDENCIES)))))$(PACKAGE_CACHE_PKGDIRS_BUILT)

# $(1): package variable prefix. The variables giving its build
# directory: <pkg>_DIR, _SRCDIR, _BUILDDIR, and those defined from them.
pkg-cache-dir-vars = \
	$(1)_DIR $(1)_SRCDIR $(1)_BUILDDIR \
	$(shell sed -n -e 's/^[[:space:]]*\($(1)_[A-Z0-9_]*\)[[:space:]]*[:+?]*=.*$$[({]$(1)_\(SRC\|BUILD\)\?DIR[)}].*/\1/p' \
		$(wildcard $($(1)_PKGDIR)/*.mk))

# $(1): package variable prefix. The directories of the .mk files that
# refer to its build directory, except its own: those of the packages
# built, and of the infrastructures (in no package directory).
pkg-cache-dir-users = \
	$(foreach d,$(abspath $(dir $(shell grep -rlwF $(addprefix -e ,$(call pkg-cache-dir-vars,$(1))) \
			--include='*.mk' $(addprefix $(TOPDIR)/,boot fs linux package toolchain) \
			$(foreach n,$(BR2_EXTERNAL_NAMES),$(BR2_EXTERNAL_$(n)_PATH))))),$\
		$(if $(filter $(abspath $($(1)_PKGDIR)),$(d)),,$\
			$(if $(filter $(d),$(PACKAGE_CACHE_PKGDIRS_ALL)),$(filter $(d),$(PACKAGE_CACHE_PKGDIRS_BUILT)),$(d))))

# $(1): package variable prefix. The command failing when a download has
# no hash.
pkg-cache-sources-hashed-cmd = \
	for f in $(notdir $($(1)_ALL_DOWNLOADS)); do \
		awk -v f="$$f" '$$3 == f && $$1 != "none" { found = 1 } END { exit !found }' \
			$(wildcard $($(1)_HASH_FILES)) /dev/null || exit 1; \
	done

# $(1): package variable prefix. The names its variables refer to.
pkg-cache-refs = $(call build-record-refs,$(call build-record-defined-vars,$(1)))

# $(1): package variable prefix. Empty when it can't be cached: local,
# overridden or unhashed sources, images installed or referred to (the
# images directory is shared), or a build directory used by others.
pkg-cache-able = \
	$(and $(PACKAGE_CACHE_DIR), \
		$(if $($(1)_OVERRIDE_SRCDIR)$(filter local,$($(1)_SITE_METHOD)),,y), \
		$(if $(filter YES,$($(1)_INSTALL_IMAGES)),,y), \
		$(if $(filter BINARIES_DIR,$(call pkg-cache-refs,$(1))),,y), \
		$(if $(strip $(call pkg-cache-dir-users,$(1))),,y), \
		$(shell ($(call pkg-cache-sources-hashed-cmd,$(1))) && echo y))

# $(1): package name. Its key, empty if it is not cached.
pkg-cache-dep-key = $(shell cat $($(call UPPERCASE,$(1))_DIR)/.cache_key 2>/dev/null)

# $(1): package variable prefix, $(2): build directory. Its key, computed
# in the download step, before its sources are extracted.
pkg-cache-key = \
	$(if $(call pkg-cache-able,$(1)),$\
		$(if $(strip $(foreach d,$($(1)_FINAL_DEPENDENCIES),$(if $(call pkg-cache-dep-key,$(d)),,n))),,$\
			$(shell { echo format $(PACKAGE_CACHE_FORMAT); echo global $(PACKAGE_CACHE_GLOBAL); \
				echo record $$($(call build-record-hash-cmd,$(1),$\
					$(call build-record-text,$(call build-record-vars,$(1)),$(call build-record-cmds,$(1))),$\
					/dev/null,$(call build-record-vars,$(1)))); \
				$(foreach d,$(sort $($(1)_FINAL_DEPENDENCIES)),echo dep $(d) $(call pkg-cache-dep-key,$(d));) \
				} | $(SHA256SUM) | cut -d' ' -f1)))

# The roots of the result of a package: its per-package host (except
# staging, under it), staging and target directories.
PACKAGE_CACHE_ROOT_DIRS = \
	host=$(HOST_DIR) staging=$(STAGING_DIR) target=$(TARGET_DIR)

# $(1): names of the roots. Their arguments for the script.
pkg-cache-roots = \
	$(addprefix --root$(space),$(filter $(addsuffix =%,$(1)),$(PACKAGE_CACHE_ROOT_DIRS))) \
	$(if $(filter host,$(1)),--exclude host=$(STAGING_SUBDIR))
PACKAGE_CACHE_ROOTS = $(call pkg-cache-roots,host staging target)

# $(1): package variable prefix, $(2): key, $(3): cache directory, if not
# the configured one. The arguments for the script.
pkg-cache-args = \
	--cache-dir $(or $(3),$(PACKAGE_CACHE_DIR)) --name $($(1)_NAME) --key $(2) \
	$(addprefix --path ,$(BUILD_RECORD_PATHS))

# $(1): package variable prefix, $(2): build directory. Non-empty when it
# was restored; checked even with the cache disabled, as it was not
# configured.
pkg-cache-restored = $(shell test -e $(2)/.stamp_cache_restored && echo y)

# $(1): build directory. Non-empty when the package was restored without
# downloading, extracting and patching its sources.
pkg-cache-nosources = $(shell test -e $(1)/.stamp_cache_nosources && echo y)

# The goals that need the sources of the packages. Without them, the
# sources of a restored package are not downloaded, extracted nor
# patched; with them, those of the packages restored that way are.
PACKAGE_CACHE_SOURCES_GOALS = source %-source legal-info %-legal-info %-extract %-patch
ifeq ($(filter $(PACKAGE_CACHE_SOURCES_GOALS),$(MAKECMDGOALS)),)
PACKAGE_CACHE_SKIP_SOURCES = y
else
$(foreach d,$(dir $(wildcard $(BUILD_DIR)/*/.stamp_cache_nosources)),$\
	$(shell rm -f $(addprefix $(d),.stamp_downloaded .stamp_extracted .stamp_patched \
		.stamp_cache_nosources)))
endif

# Whether a package was restored in the build directories, found once.
PACKAGE_CACHE_ANY_RESTORED = \
	$(eval PACKAGE_CACHE_ANY_RESTORED := $\
		$(if $(wildcard $(BUILD_DIR)/*/.stamp_cache_restored),y))$(PACKAGE_CACHE_ANY_RESTORED)

# $(1): package variable prefix, $(2): build directory, $(3): roots.
# Restore them, in the build (host, staging) and target install steps.
define pkg-cache-restore
	$(Q)$(PACKAGE_CACHE_SCRIPT) restore \
		$(call pkg-cache-args,$(1),$$(cat $(2)/.cache_key),$$(cat $(2)/.stamp_cache_restored)) \
		$(call pkg-cache-roots,$(3))
endef

# $(1): package variable prefix. The build directories (names) of the
# packages whose build directory it uses.
pkg-cache-used-dirs = \
	$(sort $(foreach t,$(filter %_DIR %_SRCDIR %_BUILDDIR,$(call pkg-cache-refs,$(1))),$\
		$(if $(call build-record-own-vars,$(1),$(t)),,$\
			$(firstword $(subst /, ,$(patsubst $(BUILD_DIR)/%,%,$(filter $(BUILD_DIR)/%,$(abspath $($(t))))))))))

# $(1): build directory name. The name of the package built there.
pkg-cache-dir-name = \
	$(or $(firstword $(foreach p,$(PACKAGES_ALL),$\
		$(if $(filter $(BUILD_DIR)/$(1),$($(call UPPERCASE,$(p))_DIR)),$(p)))),<package>)

# $(1): package variable prefix, $(2): build directory. Stop when it uses
# the build directory of a restored package, that is not there.
pkg-cache-check-dirs = \
	$(foreach d,$(call pkg-cache-used-dirs,$(1)),$\
		$(if $(shell test -e $(BUILD_DIR)/$(d)/.stamp_cache_restored && echo y),$\
			$(error $($(1)_NAME) uses the build directory $(BUILD_DIR)/$(d), restored from the \
				package cache: remove it (make $(call pkg-cache-dir-name,$(d))-dirclean) to build it)))

# $(1): names, $(2): depth. The names, and those their definitions refer
# to, $(2) levels deep.
pkg-cache-refs-deep = \
	$(if $(filter-out 0,$(2)),$(1) $(call pkg-cache-refs-deep,$(call build-record-refs,$(1)),$\
		$(word $(2),0 1 2 3)),$(1))

# The directories of the result of a package.
PACKAGE_CACHE_RESULT_DIRS = HOST_DIR STAGING_DIR TARGET_DIR BINARIES_DIR

# $(1): package variable prefix. Non-empty when its sources are not
# needed once it is restored: not when its hooks run outside of its steps
# (e.g. when the target directory is finalized) use its build directory,
# not when the hooks of its download, extract and patch steps write in
# the directories of its result (e.g. the external toolchains, installed
# in the host directory when extracted): these files are there before its
# snapshot, so they are not in its result; nor for a kconfig package: its
# .config, made from its sources, is used by its configuration editors
# and update targets.
pkg-cache-sources-unneeded = \
	$(if $(filter $(call pkg-cache-dir-vars,$(1)),$\
		$(call build-record-refs,$($(1)_TARGET_FINALIZE_HOOKS) $($(1)_ROOTFS_PRE_CMD_HOOKS))),,$\
	$(if $(filter $(PACKAGE_CACHE_RESULT_DIRS),$(call pkg-cache-refs-deep,$\
		$(foreach s,DOWNLOAD EXTRACT PATCH,$(1)_PRE_$(s)_HOOKS $(1)_POST_$(s)_HOOKS),3)),,$\
	$(if $($(1)_KCONFIG_EDITORS),,y)))

# $(1): package variable prefix, $(2): build directory. In the download
# step: look it up. When found, it is restored, and its sources are not
# downloaded, extracted nor patched unless the goals need them
# (__pkg_cache_nosources). A package rebuilt by hand (<pkg>-rebuild) is
# neither restored nor stored.
define pkg-cache-lookup
	$(eval __pkg_cache_hit :=)
	$(eval __pkg_cache_key := $(if $(shell test -e $(2)/.stamp_cache_dirty && echo y),,$\
		$(call pkg-cache-key,$(1),$(2))))
	$(Q)mkdir -p $(2)
	$(Q)rm -f $(2)/.cache_key $(2)/.cache_deps $(2)/.stamp_cache_restored \
		$(2)/.stamp_cache_nosources $(2)/.cache_snapshot
	$(if $(__pkg_cache_key),$(Q)echo $(__pkg_cache_key) > $(2)/.cache_key)
	$(if $(__pkg_cache_key),$(Q)printf '%s\n' $(foreach d,$(sort $($(1)_FINAL_DEPENDENCIES)),$\
		'$($(call UPPERCASE,$(d))_DIR)/.cache_key $(call pkg-cache-dep-key,$(d))') \
		> $(2)/.cache_deps)
	$(if $(__pkg_cache_key),$\
		$(if $(shell $(PACKAGE_CACHE_SCRIPT) lookup $(call pkg-cache-args,$(1),$(__pkg_cache_key))),$\
			$(eval __pkg_cache_hit := y)))
	$(eval __pkg_cache_nosources := $(and $(__pkg_cache_hit),$(PACKAGE_CACHE_SKIP_SOURCES),$\
		$(call pkg-cache-sources-unneeded,$(1))))
	$(if $(__pkg_cache_hit),$\
		@$(call MESSAGE,"Restoring from the package cache")$(sep)$\
		$(Q)echo $(PACKAGE_CACHE_DIR) > $(2)/.stamp_cache_restored)
	$(if $(__pkg_cache_nosources),$(Q)touch $(2)/.stamp_cache_nosources)
endef

# $(1): build directory. In the configure step of a package looked up and
# not restored: take a snapshot of its roots, to store it once installed.
define pkg-cache-snapshot
	$(Q)if [ -e $(1)/.cache_key ]; then \
		$(PACKAGE_CACHE_SCRIPT) snapshot $(PACKAGE_CACHE_ROOTS) --output $(1)/.cache_snapshot; \
	fi
endef

# $(1): build directory. The command failing when the key of a package
# it is built against changed since its key was computed (e.g. that
# package was rebuilt by hand with <pkg>-rebuild).
pkg-cache-deps-unchanged-cmd = \
	while read -r f k; do [ "$$(cat $$f 2>/dev/null)" = "$$k" ] || exit 1; done \
		< $(1)/.cache_deps

# $(1): package variable prefix, $(2): build directory. In the final
# install step, store its result, unless a package it is built against
# changed: then its key is dropped, so that the packages built against it
# are not stored either.
define pkg-cache-store
	$(Q)if [ -e $(2)/.cache_key ] && ! ($(call pkg-cache-deps-unchanged-cmd,$(2))); then \
		rm -f $(2)/.cache_key $(2)/.cache_snapshot; \
	fi
	$(Q)if [ -e $(2)/.cache_snapshot -a -e $(2)/.cache_key ]; then \
		$(PACKAGE_CACHE_SCRIPT) store $(call pkg-cache-args,$(1),$$(cat $(2)/.cache_key)) \
			$(PACKAGE_CACHE_ROOTS) --snapshot $(2)/.cache_snapshot && \
		rm -f $(2)/.cache_snapshot; \
	fi
endef
