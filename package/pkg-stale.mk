################################################################################
#
# This file contains the removal of the stale packages: those no longer
# enabled, those built differently than recorded, and those built
# against them (see BR2_REBUILD_CHANGED_PACKAGES).
#
################################################################################

ifeq ($(BR2_REBUILD_CHANGED_PACKAGES),y)

# The goals building the whole system, with no goal: 'make'.
BUILD_RECORDS_SYSTEM_GOALS = all world sdk target-reinstall

# A build of the whole system (no goal, or one of these goals, also with
# others, e.g. 'make all legal-info'), and a dry run (make -n).
BUILD_RECORDS_SYSTEM = \
	$(if $(MAKECMDGOALS),$(if $(filter $(BUILD_RECORDS_SYSTEM_GOALS),$(MAKECMDGOALS)),$(BR_BUILDING)),$(BR_BUILDING))
BUILD_RECORDS_DRY_RUN = $(findstring n,$(firstword -$(MAKEFLAGS)))

# The build records of the packages built so far (see build-record-write
# in package/pkg-build-record.mk), compared with the current definitions.
BUILD_RECORDS_FILES := $(wildcard $(BUILD_DIR)/*/.stamp_build_record)
BUILD_RECORDS := $(patsubst $(BUILD_DIR)/%/.stamp_build_record,%,$(BUILD_RECORDS_FILES))
-include $(BUILD_RECORDS_FILES)

# $(1), $(2): words. Empty if they are the same.
build-record-differ = $(strip $(filter-out $(1),$(2)) $(filter-out $(2),$(1)))

# $(1): build directory name
build-record-current-cmds = \
	$(call build-record-configure-cmds,$(BUILD_RECORD_PKG_$(1)),$(BUILD_DIR)/$(1))

# Hash the current text of each record (with make V=1, kept in
# .stamp_build_record.verbose.new).
build-records-hash = \
	$(foreach d,$(BUILD_RECORDS),$(eval BUILD_RECORD_CURRENT_HASH_$(d) := $(shell \
		$(call build-record-hash-cmd,$(BUILD_RECORD_PKG_$(d)),$\
			$(call build-record-text,$(BUILD_RECORD_VARS_$(d)),$(call build-record-current-cmds,$(d))),$\
			$(BUILD_DIR)/$(d)/.stamp_build_record.verbose.new,$(BUILD_RECORD_VARS_$(d))))))

# $(1): build directory name. Empty if the package is built as recorded.
build-record-changed = \
	$(or \
		$(call build-record-differ,$(BUILD_RECORD_DEPS_$(1)), \
			$($(BUILD_RECORD_PKG_$(1))_FINAL_DEPENDENCIES)), \
		$(call build-record-differ,$(BUILD_RECORD_HASH_$(1)), \
			$(BUILD_RECORD_CURRENT_HASH_$(1))))

BUILD_RECORDS_NOT_ENABLED = \
	$(sort $(filter-out host-% $(PACKAGES), \
		$(foreach d,$(BUILD_RECORDS),$(BUILD_RECORD_NAME_$(d)))))
BUILD_RECORDS_CHANGED = \
	$(sort $(filter-out $(BUILD_RECORDS_NOT_ENABLED), \
		$(foreach d,$(BUILD_RECORDS), \
			$(if $(call build-record-changed,$(d)),$(BUILD_RECORD_NAME_$(d))))))

# $(1): package names. Their build directories (several for a package
# built in several versions).
build-records-builds = \
	$(foreach d,$(BUILD_RECORDS),$(if $(filter $(BUILD_RECORD_NAME_$(d)),$(1)),$(d)))

# $(1): package names. The packages built against them, not among them;
# why, in BUILD_RECORD_WHY_<name>.
build-records-against = \
	$(sort $(foreach d,$(BUILD_RECORDS),$\
		$(if $(filter-out $(1),$(BUILD_RECORD_NAME_$(d))),$\
			$(if $(filter $(1),$(BUILD_RECORD_DEPS_$(d))),$\
				$(eval BUILD_RECORD_WHY_$(BUILD_RECORD_NAME_$(d)) := $\
					built against $(sort $(filter $(1),$(BUILD_RECORD_DEPS_$(d)))))$\
				$(BUILD_RECORD_NAME_$(d))))))

# $(1): package names. With the packages built against them, recursively.
build-records-closure = \
	$(call build-records-closure-add,$(1),$(call build-records-against,$(1)))
build-records-closure-add = \
	$(if $(2),$(call build-records-closure,$(1) $(2)),$(sort $(1)))

# The stale packages, with those built against them.
BUILD_RECORDS_STALE = \
	$(foreach n,$(BUILD_RECORDS_CHANGED),$(eval BUILD_RECORD_WHY_$(n) := configuration changed))$\
	$(foreach n,$(BUILD_RECORDS_NOT_ENABLED),$(eval BUILD_RECORD_WHY_$(n) := no longer enabled))$\
	$(call build-records-closure,$(BUILD_RECORDS_CHANGED) $(BUILD_RECORDS_NOT_ENABLED))

# The packages make builds: rebuilt when removed (computed once).
BUILD_RECORDS_ENABLED = \
	$(eval BUILD_RECORDS_ENABLED := $(sort $(foreach i,$(PACKAGES) $(TARGETS_ROOTFS), \
		$(i) $($(call UPPERCASE,$(i))_FINAL_RECURSIVE_DEPENDENCIES))))$(BUILD_RECORDS_ENABLED)

# $(1): package name. The name, and why it is removed.
build-records-describe = $(1)$(if $(BUILD_RECORD_WHY_$(1)), ($(BUILD_RECORD_WHY_$(1))))

# $(1): build directory names. Those installed in the target directory
# without a list of their files there.
build-records-no-target-list = \
	$(strip $(foreach d,$(1),$(if $(wildcard $(BUILD_DIR)/$(d)/.stamp_target_installed),$\
		$(if $(wildcard $(BUILD_DIR)/$(d)/.files-list.txt),,$(d)))))

# The built packages without a record (built before the option was
# enabled). The record is written in the build step.
BUILD_RECORDS_MISSING = \
	$(filter-out $(BUILD_RECORDS),$(patsubst $(BUILD_DIR)/%/.stamp_built,%,$\
		$(wildcard $(BUILD_DIR)/*/.stamp_built)))

# $(1): directory, $(2): file list (e.g. .files-list-staging.txt), $(3):
# build directory names. Remove from the directory the files listed by
# these builds, except those also listed by the others. The directories
# are kept: the lists do not tell which package made them, and some
# packages rely on those of the skeleton (e.g. usr/sbin).
remove-listed-files-cmd = \
	if [ -d $(1) ]; then \
		awk '{ f = substr($$0, index($$0, ",") + 1) } \
			kept { k[f] = 1; next } !(f in k) { print f }' \
			kept=1 /dev/null $(filter-out $(addsuffix /$(2),$(addprefix $(BUILD_DIR)/,$(3))),$\
				$(wildcard $(BUILD_DIR)/*/$(2))) \
			kept=0 $(wildcard $(addsuffix /$(2),$(addprefix $(BUILD_DIR)/,$(3)))) | \
		(cd $(1) && while IFS= read -r f; do \
			if [ -L "$$f" ] || [ -f "$$f" ]; then printf '%s\n' "$$f"; fi; \
		done | tr '\n' '\0' | xargs -0 -r rm -f --); \
	fi

# $(1): package names, with those built against them. Remove their files,
# and their build and per-package directories; 'make' then rebuilds those
# still enabled.
remove-packages-cmd = \
	$(call remove-builds-cmd,$(1),$(call build-records-builds,$(1)),$\
		$(call build-records-no-target-list,$(call build-records-builds,$(1))))

# $(1): package names, $(2): their build directories, $(3): those without
# a list of their target files: the target directory is re-created
# instead of removing their files from it.
remove-builds-cmd = \
	$(if $(3),,$(call remove-listed-files-cmd,$(BASE_TARGET_DIR),.files-list.txt,$(2)) &&) \
	$(call remove-listed-files-cmd,$(call qstrip,$(BR2_HOST_DIR))/$(STAGING_SUBDIR),$\
		.files-list-staging.txt,$(2)) && \
	$(call remove-listed-files-cmd,$(call qstrip,$(BR2_HOST_DIR)),.files-list-host.txt,$(2)) && \
	$(call remove-listed-files-cmd,$(BINARIES_DIR),.files-list-images.txt,$(2)) && \
	printf '%s\n' $(foreach n,$(1),$\
		'$(if $(filter $(n),$(BUILD_RECORDS_ENABLED)),Rebuilding,Removing) $(call build-records-describe,$(n))') && \
	rm -rf $(addprefix $(BUILD_DIR)/,$(2)) \
		$(if $(BR2_PER_PACKAGE_DIRECTORIES),$(addprefix $(PER_PACKAGE_DIR)/,$(1))) \
	$(if $(BUILD_RECORDS_MISSING),&& printf '%s\n' \
		'Warning: these builds have no build record$(comma) packages built against the removed ones among them are not detected:' \
		$(foreach d,$(BUILD_RECORDS_MISSING),'  $(d)')) \
	$(if $(3),&& echo 'No file list for $(sort $(3)): the target directory is re-created.' && \
		{ $(TARGET_CLEAN_FOR_REINSTALL); })

# $(1): package names, with those built against them. List them, as
# removed by the next build.
show-stale-cmd = \
	$(if $(1),,echo 'Nothing to rebuild or remove: every package was built as currently configured.';) \
	$(if $(filter $(BUILD_RECORDS_ENABLED),$(1)),printf '%s\n' 'Packages to rebuild:' \
		$(foreach n,$(filter $(BUILD_RECORDS_ENABLED),$(1)),'  $(call build-records-describe,$(n))');) \
	$(if $(filter-out $(BUILD_RECORDS_ENABLED),$(1)),printf '%s\n' 'Packages to remove:' \
		$(foreach n,$(filter-out $(BUILD_RECORDS_ENABLED),$(1)),'  $(call build-records-describe,$(n))');) \
	$(if $(call build-records-no-target-list,$(call build-records-builds,$(1))),\
		echo 'The target directory will be re-created: no file list for $(sort \
			$(call build-records-no-target-list,$(call build-records-builds,$(1)))).';) \
	true

# $(1): package name. Remove it, and the packages built against it.
remove-package-cmd = \
	$(if $(call build-records-builds,$(1)),$\
		$(call remove-packages-cmd,$(call build-records-closure,$(1))),$\
		echo '$(1): no build to remove.')

# Compare while parsing: in a recipe, the automatic variables would be
# those of the recipe, not of the packages.
ifneq ($(filter show-stale,$(MAKECMDGOALS))$(BUILD_RECORDS_SYSTEM),)
$(if $(BUILD_RECORDS),$(build-records-hash))
BUILD_RECORDS_NOT_ENABLED := $(BUILD_RECORDS_NOT_ENABLED)
BUILD_RECORDS_CHANGED := $(BUILD_RECORDS_CHANGED)
BUILD_RECORDS_STALE := $(BUILD_RECORDS_STALE)
endif

# A build of the whole system (see BUILD_RECORDS_SYSTEM, not 'make -n')
# removes the stale packages first, while parsing, before make looks at
# their stamp files.
ifeq ($(BUILD_RECORDS_SYSTEM)$(BUILD_RECORDS_DRY_RUN),y)
ifneq ($(BUILD_RECORDS_STALE),)
ifneq ($(shell { $(call remove-packages-cmd,$(BUILD_RECORDS_STALE)); } >&2 || echo failed),)
$(error Failed to remove the stale packages)
endif
endif
endif
endif # BR2_REBUILD_CHANGED_PACKAGES
