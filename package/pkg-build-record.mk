################################################################################
#
# This file contains the build records of the packages: how each package
# is built, recorded in its build step, to rebuild it when it changes
# (see BR2_REBUILD_CHANGED_PACKAGES).
#
################################################################################

# The host sha256sum, found once.
SHA256SUM = $(eval SHA256SUM := $(shell which sha256sum || type -p sha256sum || echo sha256sum))$(SHA256SUM)

# Build records (BR2_REBUILD_CHANGED_PACKAGES): in the build step of a
# package, record in .stamp_build_record how it is built: the hash of its
# variables, the options they refer to, its expanded configure and build
# commands, and its files. Not in the configure step: make expands a
# recipe before running it, so there, the per-package directories are
# not prepared yet, and a command reading them (e.g. $(shell
# $(STAGING_DIR)/usr/bin/mysql_config --cflags)) would not expand as when
# the record is compared.

# $(1): package variable prefix (e.g. HOST_NTP), $(2): variable names.
# Those of the package, except those of the packages named after it (e.g.
# perl-* for perl), the reverse dependencies and the recipe ones (__X).
build-record-own-vars = \
	$(filter-out $(addsuffix _%,$(filter $(1)_%,$(PACKAGES_VARS_ALL))) %_RDEPENDENCIES %__X %_, \
		$(filter $(1)_%,$(2)))

# $(1): package variable prefix. Its defined variables (.VARIABLES is
# filtered one word at a time, for https://savannah.gnu.org/bugs/?59093).
build-record-defined-vars = \
	$(call build-record-own-vars,$(1),$(foreach X,$(.VARIABLES),$(filter $(1)_%,$(X))))

# Characters separating the names in a definition: all those that can't
# be in the name of a variable of a package, e.g. the ' and / of
# 's/\/\* #define LUA_32BITS \*\//#define LUA_32BITS/' in lua.mk.
BUILD_RECORD_SEPARATORS := $$ ( ) { } $(comma) : = ' " / \ * \# ; @ < > | & ! ? ~ [ ] ^ + . - %

# $(1): text, $(2): separators. The text, split at the separators.
build-record-split = \
	$(if $(2),$(call build-record-split,$(subst $(firstword $(2)), ,$(1)),$\
		$(wordlist 2,$(words $(2)),$(2))),$(1))

# $(1): variable names. The names their definitions refer to.
build-record-refs = \
	$(call build-record-split,$(foreach v,$(1),$(value $(v))),$(BUILD_RECORD_SEPARATORS))

# The package variables the infrastructures read in their recipes (e.g.
# FOO_CONFIGURE_CMDS, from $$($$(PKG)_CONFIGURE_CMDS)), found once.
BUILD_RECORD_INFRA_VARS = \
	$(eval BUILD_RECORD_INFRA_VARS := $(shell grep -rhoe '\$$.\$$.PKG._[A-Z0-9_]*' \
		--include='*.mk' $(TOPDIR)/Makefile $(TOPDIR)/package/*.mk \
		$(addprefix $(TOPDIR)/,boot fs linux toolchain) | \
		cut -c10- | LC_ALL=C sort -u))$(BUILD_RECORD_INFRA_VARS)

# $(1): package variable prefix. The variables recorded: those defined,
# those the infrastructures read, and those its variables refer to, even
# undefined (e.g. defined only when an option is enabled); for a host
# package, also those of the target package it refers to.
build-record-vars = \
	$(sort $(call build-record-defined-vars,$(1)) \
		$(addprefix $(1)_,$(BUILD_RECORD_INFRA_VARS)) \
		$(foreach p,$(1) $(patsubst HOST_%,%,$(filter HOST_%,$(1))),$\
			$(call build-record-own-vars,$(p),$(call build-record-refs,$(call build-record-defined-vars,$(1))))))

# Variables that change the expansion of the commands, but not the build
# (verbosity, terminal, version, number of jobs, date): emptied while the
# commands are expanded, except SOURCE_DATE_EPOCH, set to 0, as some
# commands give it to date (e.g. linux). CMAKE_QUIET is set from QUIET
# (make -s) when parsing. MAKE, MAKE1 and HOSTMAKE, that depend on the -j
# option of the top-level make, are replaced.
BUILD_RECORD_NEUTRAL_VARS = \
	Q QUIET VERBOSE CMAKE_QUIET TERM_BOLD TERM_RESET BR2_VERSION_FULL \
	SOURCE_DATE_EPOCH PARALLEL_JOBS BR2_JLEVEL

# $(1): package variable prefix. Its configure and build commands, with
# their hooks, expanded.
build-record-cmds-expand = \
	$(foreach s,CONFIGURE BUILD, \
		$(foreach h,$($(1)_PRE_$(s)_HOOKS),$(call $(h))) \
		$($(1)_$(s)_CMDS) \
		$(foreach h,$($(1)_POST_$(s)_HOOKS),$(call $(h))))
build-record-cmds = \
	$(foreach v,$(BUILD_RECORD_NEUTRAL_VARS),$\
		$(eval __br_$(v) := $$($(v)))$(eval $(v) :=$(if $(filter SOURCE_DATE_EPOCH,$(v)),0)))$\
	$(eval __br_cmds := $$(strip $$(subst $$(HOSTMAKE),_M,$$(subst $$(MAKE),_M,$\
		$$(subst $$(MAKE1),_M1,$$(call build-record-cmds-expand,$(1)))))))$\
	$(foreach v,$(BUILD_RECORD_NEUTRAL_VARS),$(eval $(v) := $$(__br_$(v))))$\
	$(__br_cmds)

# $(1): package variable prefix, $(2): build directory. Its commands,
# expanded outside of a recipe: PKG and the automatic variables are set
# as in the build step.
build-record-configure-cmds = \
	$(eval PKG := $(1))$(eval @D := $(2))$(eval @ := $(2)/.stamp_built)$\
	$(call build-record-cmds,$(1))$\
	$(eval PKG :=)$(eval @D :=)$(eval @ :=)

# $(1): variable names. The options (BR2_*) their definitions refer to,
# except the neutral ones, as the install commands are not expanded. A
# name ending with _ (e.g. BR2_PACKAGE_LINUX_TOOLS_$(tool)) stands for
# all the options starting with it.
build-record-options = \
	$(call build-record-options-of,$(sort $(filter BR2_%,$(call build-record-refs,$(1)))))
build-record-options-of = \
	$(sort $(filter-out $(BUILD_RECORD_NEUTRAL_VARS),$(filter-out %_,$(1)) \
		$(if $(filter %_,$(1)),$\
			$(foreach X,$(.VARIABLES),$(filter $(addsuffix %,$(filter %_,$(1))),$(X))))))

# $(1): variable names, $(2): expanded commands. The text of a record.
build-record-text = \
	$(foreach v,$(1),$(v) = $(value $(v))$(sep))$\
	$(foreach o,$(call build-record-options,$(1)),$(o) = $($(o))$(sep))$\
	$(strip $(2))$(sep)

# The directories of the build, replaced by their names in the records.
BUILD_RECORD_PATHS = \
	BASE_DIR=$(BASE_DIR) HOST_DIR=$(call qstrip,$(BR2_HOST_DIR)) DL_DIR=$(DL_DIR) \
	TOPDIR=$(TOPDIR) $(if $(BR2_CCACHE),CCACHE_DIR=$(call qstrip,$(BR2_CCACHE_DIR))) \
	$(foreach n,$(BR2_EXTERNAL_NAMES),BR2_EXTERNAL_$(n)_PATH=$(BR2_EXTERNAL_$(n)_PATH))

# The sed expressions replacing them, longest first, computed once.
BUILD_RECORD_SED = \
	$(eval BUILD_RECORD_SED := $(shell printf '%s\n' $(BUILD_RECORD_PATHS) | \
		awk -F= '$$2 != "" { print length($$2), "-e s," $$2 ",@" $$1 "@,g" }' | \
		LC_ALL=C sort -rn | cut -d' ' -f2-))$(BUILD_RECORD_SED)

# The trees whose files the variables can refer to (e.g.
# $(BR2_EXTERNAL_FOO_PATH)/board/foo.conf), and the characters ending such
# a path.
BUILD_RECORD_TREES = TOPDIR $(foreach n,$(BR2_EXTERNAL_NAMES),BR2_EXTERNAL_$(n)_PATH)
BUILD_RECORD_PATH_ENDS := ; $(comma) ) } $$

# $(1): text, $(2): tree variables. The text, with their references
# replaced by their values.
build-record-trees-subst = \
	$(if $(2),$(call build-record-trees-subst,$\
		$(subst $$($(firstword $(2))),$($(firstword $(2))),$(1)),$(wordlist 2,$(words $(2)),$(2))),$(1))

# $(1): variable names. The paths their definitions refer to in the trees.
build-record-tree-paths = \
	$(filter $(foreach t,$(BUILD_RECORD_TREES),$($(t))/%),$\
		$(call build-record-split,$(call build-record-trees-subst,$\
			$(subst ',,$(subst ",,$(foreach v,$(1),$(value $(v))))),$(BUILD_RECORD_TREES)),$\
			$(BUILD_RECORD_PATH_ENDS)))

# Paths of option values that are not recorded: those of the host system
# (e.g. the host tools), and the directories of the build as a whole
# (e.g. BR2_EXTERNAL_<name>_PATH, BR2_CCACHE_DIR).
BUILD_RECORD_HOST_PATHS = \
	/ $(wildcard /*) $(HOME) /usr/% /bin/% /sbin/% /lib% /etc/% /proc/% \
	/sys/% /dev/% /run/% /var/%

# $(1): words. Those that can be paths: with a /, or naming a file. A
# bare word naming a directory is a value, not a path (e.g. "boot linux"
# in BR2_TARGET_GRUB2_BUILTIN_MODULES_PC).
build-record-path-words = \
	$(foreach w,$(1),$(if $(findstring /,$(w)),$(w),$(if $(wildcard $(w)/.),,$(w))))

# $(1): variable names. The existing files and directories the values of
# their options, and their definitions, refer to.
build-record-paths = \
	$(sort $(filter-out $(abspath $(foreach p,$(BUILD_RECORD_PATHS),$(lastword $(subst =, ,$(p))))),$\
		$(patsubst %/,%,$(wildcard \
			$(filter-out $(BUILD_RECORD_HOST_PATHS),$\
				$(call build-record-path-words,$\
					$(foreach o,$(call build-record-options,$(1)),$(call qstrip,$($(o)))))) \
			$(call build-record-tree-paths,$(1))))))

# $(1): package variable prefix. The packages in subdirectories of its
# directory (e.g. qt6base in package/qt6), whose files are not its own.
build-record-subpackages = \
	$(patsubst %/,%,$(dir $(wildcard $($(1)_PKGDIR)/*/*.mk $($(1)_PKGDIR)/*/*/*.mk)))

# $(1): package variable prefix, $(2): its variables. The command
# printing the hashes of its files: those of its directory, its patches
# and hash files, and those its variables refer to; and listing the
# directories they refer to: names, sizes and times of their files, not
# their content, that can be large (e.g. a pre-installed toolchain).
build-record-files-cmd = \
	{ $(if $($(1)_PKGDIR),\
		find $($(1)_PKGDIR) $(foreach d,$(call build-record-subpackages,$(1)),-path $(d) -prune -o) \
			-type f -print;) \
	printf '%s\n' $(sort $(wildcard $(addsuffix /*.patch,$(call pkg-patches-dirs,$(1))))) \
		$(wildcard $($(1)_HASH_FILES)) \
		$(filter-out $(call build-record-dirs,$(2)),$(call build-record-paths,$(2))); \
	} | grep . | LC_ALL=C sort -u | tr '\n' '\0' | xargs -0 -r $(SHA256SUM); \
	$(if $(call build-record-dirs,$(2)),\
		find $(call build-record-dirs,$(2)) -name .git -prune -o -printf '%p %s %T@\n' | \
		LC_ALL=C sort;)
build-record-dirs = \
	$(patsubst %/.,%,$(wildcard $(addsuffix /.,$(call build-record-paths,$(1)))))

# With make V=1, the text hashed is kept.
BUILD_RECORD_KEEP_TEXT = $(filter 1,$(KBUILD_VERBOSE))

# $(1): package variable prefix, $(2): text, $(3): file where to keep it
# (V=1), $(4): its variables. The command printing the hash of the text
# and of its files. printf gets the newlines as \n.
build-record-hash-cmd = \
	{ printf '%b' '$(subst ','\'',$(subst $(sep),\n,$(subst \,\\,$(2))))'; \
		$(call build-record-files-cmd,$(1),$(4)) } | \
	sed $(BUILD_RECORD_SED) | \
	$(if $(BUILD_RECORD_KEEP_TEXT),tee $(3) |) \
	$(SHA256SUM) | cut -d' ' -f1

# $(1): text. The text, quoted for the shell.
build-record-quote = '$(subst ','\'',$(1))'

# $(1): package variable prefix, $(2): build directory. Write its record:
# variable prefix, name, dependencies, recorded variables and hash.
define build-record-write
	$(eval __build_record_vars := $(call build-record-vars,$(1)))
	$(Q)printf '%s\n' \
		$(call build-record-quote,BUILD_RECORD_PKG_$(notdir $(2)) = $(1)) \
		$(call build-record-quote,BUILD_RECORD_NAME_$(notdir $(2)) = $($(1)_NAME)) \
		$(call build-record-quote,BUILD_RECORD_DEPS_$(notdir $(2)) = $($(1)_FINAL_DEPENDENCIES)) \
		$(call build-record-quote,BUILD_RECORD_VARS_$(notdir $(2)) = $(__build_record_vars)) \
		"BUILD_RECORD_HASH_$(notdir $(2)) = $$($(call build-record-hash-cmd,$(1),$\
			$(call build-record-text,$(__build_record_vars),$(call build-record-cmds,$(1))),$\
			$(2)/.stamp_build_record.verbose,$(__build_record_vars)))" \
		> $(2)/.stamp_build_record
endef
