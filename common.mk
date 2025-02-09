#
# Common definition to all platforms
#

SHELL := bash
BASH ?= bash
ROOT ?= $(shell pwd)/..

BUILD_PATH			?= $(ROOT)/build
LINUX_PATH			?= $(ROOT)/linux
OPTEE_GENDRV_MODULE		?= $(LINUX_PATH)/drivers/tee/optee/optee.ko
GEN_ROOTFS_PATH			?= $(ROOT)/gen_rootfs
GEN_ROOTFS_FILELIST		?= $(GEN_ROOTFS_PATH)/filelist-tee.txt
OPTEE_OS_PATH			?= $(ROOT)/optee_os
OPTEE_CLIENT_PATH		?= $(ROOT)/optee_client
OPTEE_CLIENT_EXPORT		?= $(OPTEE_CLIENT_PATH)/out/export
OPTEE_TEST_PATH			?= $(ROOT)/optee_test
OPTEE_TEST_OUT_PATH		?= $(ROOT)/optee_test/out
OPTEE_EXAMPLES_PATH		?= $(ROOT)/optee_examples
BENCHMARK_APP_PATH		?= $(ROOT)/optee_benchmark
BENCHMARK_APP_OUT		?= $(BENCHMARK_APP_PATH)/out
LIBYAML_LIB_OUT			?= $(BENCHMARK_APP_OUT)/libyaml/out/lib
BUILDROOT_TARGET_ROOT	?= $(ROOT)/out-br/target
UEFI_TOOLS_PATH			?= $(ROOT)/uefi-tools
EDK2_PLAT_PATH			?= $(ROOT)/edk2-platforms

# default high verbosity. slow uarts shall specify lower if prefered
CFG_TEE_CORE_LOG_LEVEL		?= 3

# default disable latency benchmarks (over all OP-TEE layers)
CFG_TEE_BENCHMARK		?= n

CCACHE ?= $(shell which ccache) # Don't remove this comment (space is needed)

# Accessing a shared folder on the host from QEMU:
# # Set QEMU_VIRTFS_ENABLE to 'y' and adjust QEMU_VIRTFS_HOST_DIR
# # Then in QEMU, run:
# # $ mount -t 9p -o trans=virtio host <mount_point>
QEMU_VIRTFS_ENABLE		?= n
QEMU_VIRTFS_HOST_DIR	?= $(ROOT)

################################################################################
# Mandatory for autotools (for specifying --host)
################################################################################
ifeq ($(COMPILE_NS_USER),64)
MULTIARCH			:= aarch64-linux-gnu
else
MULTIARCH			:= arm-linux-gnueabihf
endif

################################################################################
# Check coherency of compilation mode
################################################################################

ifneq ($(COMPILE_NS_USER),)
ifeq ($(COMPILE_NS_KERNEL),)
$(error COMPILE_NS_KERNEL must be defined as COMPILE_NS_USER=$(COMPILE_NS_USER) is defined)
endif
ifeq (,$(filter $(COMPILE_NS_USER),32 64))
$(error COMPILE_NS_USER=$(COMPILE_NS_USER) - Should be 32 or 64)
endif
endif

ifneq ($(COMPILE_NS_KERNEL),)
ifeq ($(COMPILE_NS_USER),)
$(error COMPILE_NS_USER must be defined as COMPILE_NS_KERNEL=$(COMPILE_NS_KERNEL) is defined)
endif
ifeq (,$(filter $(COMPILE_NS_KERNEL),32 64))
$(error COMPILE_NS_KERNEL=$(COMPILE_NS_KERNEL) - Should be 32 or 64)
endif
endif

ifeq ($(COMPILE_NS_KERNEL),32)
ifneq ($(COMPILE_NS_USER),32)
$(error COMPILE_NS_USER=$(COMPILE_NS_USER) - Should be 32 as COMPILE_NS_KERNEL=$(COMPILE_NS_KERNEL))
endif
endif

ifneq ($(COMPILE_S_USER),)
ifeq ($(COMPILE_S_KERNEL),)
$(error COMPILE_S_KERNEL must be defined as COMPILE_S_USER=$(COMPILE_S_USER) is defined)
endif
ifeq (,$(filter $(COMPILE_S_USER),32 64))
$(error COMPILE_S_USER=$(COMPILE_S_USER) - Should be 32 or 64)
endif
endif

ifneq ($(COMPILE_S_KERNEL),)
OPTEE_OS_COMMON_EXTRA_FLAGS ?= O=out/arm
OPTEE_OS_BIN		    ?= $(OPTEE_OS_PATH)/out/arm/core/tee.bin
OPTEE_OS_HEADER_V2_BIN	    ?= $(OPTEE_OS_PATH)/out/arm/core/tee-header_v2.bin
OPTEE_OS_PAGER_V2_BIN	    ?= $(OPTEE_OS_PATH)/out/arm/core/tee-pager_v2.bin
OPTEE_OS_PAGEABLE_V2_BIN    ?= $(OPTEE_OS_PATH)/out/arm/core/tee-pageable_v2.bin
ifeq ($(COMPILE_S_USER),)
$(error COMPILE_S_USER must be defined as COMPILE_S_KERNEL=$(COMPILE_S_KERNEL) is defined)
endif
ifeq (,$(filter $(COMPILE_S_KERNEL),32 64))
$(error COMPILE_S_KERNEL=$(COMPILE_S_KERNEL) - Should be 32 or 64)
endif
endif

ifeq ($(COMPILE_S_KERNEL),32)
ifneq ($(COMPILE_S_USER),32)
$(error COMPILE_S_USER=$(COMPILE_S_USER) - Should be 32 as COMPILE_S_KERNEL=$(COMPILE_S_KERNEL))
endif
endif


################################################################################
# set the compiler when COMPILE_xxx are defined
################################################################################


ifeq ($(COMPILE_LEGACY),)
CROSS_COMPILE_NS_USER   ?= "$(CCACHE)$(AARCH$(COMPILE_NS_USER)_CROSS_COMPILE)"
CROSS_COMPILE_NS_KERNEL ?= "$(CCACHE)$(AARCH$(COMPILE_NS_KERNEL)_CROSS_COMPILE)"
CROSS_COMPILE_S_USER    ?= "$(CCACHE)$(AARCH$(COMPILE_S_USER)_CROSS_COMPILE)"
CROSS_COMPILE_S_KERNEL  ?= "$(CCACHE)$(AARCH$(COMPILE_S_KERNEL)_CROSS_COMPILE)"
else
CROSS_COMPILE_NS_USER   ?= "$(CCACHE)$(LEGACY_AARCH$(COMPILE_NS_USER)_CROSS_COMPILE)"
CROSS_COMPILE_NS_KERNEL ?= "$(CCACHE)$(LEGACY_AARCH$(COMPILE_NS_KERNEL)_CROSS_COMPILE)"
CROSS_COMPILE_S_USER    ?= "$(CCACHE)$(LEGACY_AARCH$(COMPILE_S_USER)_CROSS_COMPILE)"
CROSS_COMPILE_S_KERNEL  ?= "$(CCACHE)$(LEGACY_AARCH$(COMPILE_S_KERNEL)_CROSS_COMPILE)"
endif

ifeq ($(COMPILE_S_USER),32)
OPTEE_OS_TA_DEV_KIT_DIR	?= $(OPTEE_OS_PATH)/out/arm/export-ta_arm32
endif
ifeq ($(COMPILE_S_USER),64)
OPTEE_OS_TA_DEV_KIT_DIR	?= $(OPTEE_OS_PATH)/out/arm/export-ta_arm64
endif

ifeq ($(COMPILE_S_KERNEL),64)
OPTEE_OS_COMMON_EXTRA_FLAGS	+= CFG_ARM64_core=y
endif


################################################################################
# defines, macros, configuration etc
################################################################################
define KERNEL_VERSION
$(shell cd $(LINUX_PATH) && $(MAKE) --no-print-directory kernelversion)
endef

# Read stdin, expand ${VAR} environment variables, output to stdout
# http://superuser.com/a/302847
define expand-env-var
awk '{while(match($$0,"[$$]{[^}]*}")) {var=substr($$0,RSTART+2,RLENGTH -3);gsub("[$$]{"var"}",ENVIRON[var])}}1'
endef

DEBUG ?= 0

################################################################################
# default target is all
################################################################################
.PHONY: all
all:

################################################################################
# Busybox
################################################################################
BUSYBOX_COMMON_TARGET		?= TOBEDEFINED
BUSYBOX_CLEAN_COMMON_TARGET	?= TOBEDEFINED

.PHONY: busybox-common
busybox-common: linux
	cd $(GEN_ROOTFS_PATH) &&  \
		CROSS_COMPILE=$(CROSS_COMPILE_NS_USER) \
		PATH=${PATH}:$(LINUX_PATH)/usr \
		$(GEN_ROOTFS_PATH)/generate-cpio-rootfs.sh \
			$(BUSYBOX_COMMON_TARGET)

.PHONY: busybox-clean-common
busybox-clean-common:
	cd $(GEN_ROOTFS_PATH) && \
	$(GEN_ROOTFS_PATH)/generate-cpio-rootfs.sh  \
		$(BUSYBOX_CLEAN_COMMON_TARGET)

.PHONY: busybox-cleaner-common
busybox-cleaner-common:
	rm -rf $(GEN_ROOTFS_PATH)/build
	rm -rf $(GEN_ROOTFS_PATH)/filelist-final.txt

################################################################################
# Build root
################################################################################
BUILDROOT_ARCH=aarch$(COMPILE_NS_USER)
ifeq ($(GDBSERVER),y)
BUILDROOT_TOOLCHAIN=toolchain-br # Use toolchain supplied by buildroot
DEFCONFIG_GDBSERVER=--br-defconfig build/br-ext/configs/gdbserver.conf
else
# Local toolchains (downloaded by "make toolchains")
ifeq ($(COMPILE_LEGACY),)
BUILDROOT_TOOLCHAIN=toolchain-aarch$(COMPILE_NS_USER)
else
BUILDROOT_TOOLCHAIN=toolchain-aarch$(COMPILE_NS_USER)-legacy
endif
endif

BR2_PACKAGE_LIBOPENSSL ?= y
BR2_PACKAGE_MMC_UTILS ?= y
BR2_PACKAGE_OPENSSL ?= y
BR2_PACKAGE_OPTEE_BENCHMARK ?= $(CFG_TEE_BENCHMARK)
BR2_PACKAGE_OPTEE_BENCHMARK_SITE ?= $(BENCHMARK_APP_PATH)
BR2_PACKAGE_OPTEE_CLIENT_SITE ?= $(OPTEE_CLIENT_PATH)
BR2_PACKAGE_OPTEE_EXAMPLES ?= y
BR2_PACKAGE_OPTEE_EXAMPLES_CROSS_COMPILE ?= $(CROSS_COMPILE_S_USER)
BR2_PACKAGE_OPTEE_EXAMPLES_SDK ?= $(OPTEE_OS_TA_DEV_KIT_DIR)
BR2_PACKAGE_OPTEE_EXAMPLES_SITE ?= $(OPTEE_EXAMPLES_PATH)
# The OPTEE_OS package builds nothing, it just installs files into the
# root FS when applicable (for example: shared libraries)
BR2_PACKAGE_OPTEE_OS ?= y
BR2_PACKAGE_OPTEE_OS_SDK ?= $(OPTEE_OS_TA_DEV_KIT_DIR)
BR2_PACKAGE_OPTEE_OS_SITE ?= $(CURDIR)/br-ext/package/optee_os
BR2_PACKAGE_OPTEE_TEST ?= y
BR2_PACKAGE_OPTEE_TEST_CROSS_COMPILE ?= $(CROSS_COMPILE_S_USER)
BR2_PACKAGE_OPTEE_TEST_SDK ?= $(OPTEE_OS_TA_DEV_KIT_DIR)
BR2_PACKAGE_OPTEE_TEST_SITE ?= $(OPTEE_TEST_PATH)
BR2_PACKAGE_STRACE ?= y
BR2_TARGET_GENERIC_GETTY_PORT ?= $(if $(CFG_NW_CONSOLE_UART),ttyAMA$(CFG_NW_CONSOLE_UART),ttyAMA0)

# All BR2_* variables from the makefile or the environment are appended to
# ../out-br/extra.conf. All values are quoted "..." except y and n.
double-quote = "#" # This really sets the variable to " and avoids upsetting vim's syntax highlighting
streq = $(and $(findstring $(1),$(2)),$(findstring $(2),$(1)))
y-or-n = $(or $(call streq,y,$(1)),$(call streq,n,$(1)))
append-var_ = echo '$(1)=$(3)'$($(1))'$(3)' >>$(2);
append-var = $(call append-var_,$(1),$(2),$(if $(call y-or-n,$($(1))),,$(double-quote)))
append-br2-vars = $(foreach var,$(filter BR2_%,$(.VARIABLES)),$(call append-var,$(var),$(1)))

.PHONY: buildroot
buildroot: optee-os
	@mkdir -p ../out-br
	@rm -f ../out-br/build/optee_*/.stamp_*
	@rm -f ../out-br/extra.conf
	@$(call append-br2-vars,../out-br/extra.conf)
	@(cd .. && python build/br-ext/scripts/make_def_config.py \
		--br buildroot --out out-br --br-ext build/br-ext \
		--top-dir "$(ROOT)" \
		--br-defconfig build/br-ext/configs/optee_$(BUILDROOT_ARCH) \
		--br-defconfig build/br-ext/configs/optee_generic \
		--br-defconfig build/br-ext/configs/$(BUILDROOT_TOOLCHAIN) \
		$(DEFCONFIG_GDBSERVER) \
		--br-defconfig out-br/extra.conf \
		--make-cmd $(MAKE))
	@$(MAKE) -C ../out-br all

.PHONY: buildroot-clean
buildroot-clean:
	@test ! -d $(ROOT)/out-br || $(MAKE) -C $(ROOT)/out-br clean

.PHONY: buildroot-cleaner
buildroot-cleaner:
	@rm -rf $(ROOT)/out-br

################################################################################
# Linux
################################################################################
ifeq ($(CFG_TEE_BENCHMARK),y)
LINUX_DEFCONFIG_BENCH ?= $(CURDIR)/kconfigs/tee_bench.conf
endif

LINUX_COMMON_FLAGS ?= LOCALVERSION= CROSS_COMPILE=$(CROSS_COMPILE_NS_KERNEL)

.PHONY: linux-common
linux-common: linux-defconfig
	$(MAKE) -C $(LINUX_PATH) $(LINUX_COMMON_FLAGS)

$(LINUX_PATH)/.config: $(LINUX_DEFCONFIG_COMMON_FILES)
	cd $(LINUX_PATH) && \
		ARCH=$(LINUX_DEFCONFIG_COMMON_ARCH) \
		scripts/kconfig/merge_config.sh $(LINUX_DEFCONFIG_COMMON_FILES) \
			$(LINUX_DEFCONFIG_BENCH)

.PHONY: linux-defconfig-clean-common
linux-defconfig-clean-common:
	rm -f $(LINUX_PATH)/.config

# LINUX_CLEAN_COMMON_FLAGS should be defined in specific makefiles (hikey.mk,...)
.PHONY: linux-clean-common
linux-clean-common: linux-defconfig-clean
	$(MAKE) -C $(LINUX_PATH) $(LINUX_CLEAN_COMMON_FLAGS) clean

# LINUX_CLEANER_COMMON_FLAGS should be defined in specific makefiles (hikey.mk,...)
.PHONY: linux-cleaner-common
linux-cleaner-common: linux-defconfig-clean
	$(MAKE) -C $(LINUX_PATH) $(LINUX_CLEANER_COMMON_FLAGS) distclean

################################################################################
# EDK2 / Tianocore
################################################################################
.PHONY: edk2-common
edk2-common:
	$(call edk2-env) && \
	export PACKAGES_PATH=$(EDK2_PATH):$(EDK2_PLATFORMS_PATH) && \
	cd $(EDK2_PATH) && \
	git submodule init && \
	git submodule update &&\
	cd - && \
	source $(EDK2_PATH)/edksetup.sh && \
	$(MAKE) -j1 -C $(EDK2_PATH)/BaseTools && \
	$(call edk2-call) all

.PHONY: edk2-clean-common
edk2-clean-common:
	$(call edk2-env) && \
	export PACKAGES_PATH=$(EDK2_PATH):$(ROOT)/edk2-platforms && \
	source $(EDK2_PATH)/edksetup.sh && \
	$(MAKE) -j1 -C $(EDK2_PATH)/BaseTools clean && \
	$(call edk2-call) cleanall

################################################################################
# QEMU / QEMUv8
################################################################################
QEMU_CONFIGURE_PARAMS_COMMON = --cc="$(CCACHE)gcc" --extra-cflags="-Wno-error"

ifeq ($(QEMU_VIRTFS_ENABLE),y)
QEMU_CONFIGURE_PARAMS_COMMON +=  --enable-virtfs
QEMU_EXTRA_ARGS +=\
	-fsdev local,id=fsdev0,path=$(QEMU_VIRTFS_HOST_DIR),security_model=none \
	-device virtio-9p-device,fsdev=fsdev0,mount_tag=host
endif

ifeq ($(GDBSERVER),y)
HOSTFWD := ,hostfwd=tcp::12345-:12345
endif
# Enable QEMU SLiRP user networking
QEMU_EXTRA_ARGS +=\
	-netdev user,id=vmnic$(HOSTFWD) -device virtio-net-device,netdev=vmnic

define run-help
	@echo
	@echo \* QEMU is now waiting to start the execution
	@echo \* Start execution with either a \'c\' followed by \<enter\> in the QEMU console or
	@echo \* attach a debugger and continue from there.
	@echo \*
	@echo \* To run OP-TEE tests, use the xtest command in the \'Normal World\' terminal
	@echo \* Enter \'xtest -h\' for help.
	@echo
endef

ifneq (, $(LAUNCH_TERMINAL))
define launch-terminal
	@nc -z  127.0.0.1 $(1) || \
		$(LAUNCH_TERMINAL) "$(SOC_TERM_PATH)/soc_term $(1)" &
endef
else
gnome-terminal := $(shell command -v gnome-terminal 2>/dev/null)
xterm := $(shell command -v xterm 2>/dev/null)
ifdef gnome-terminal
define launch-terminal
	@nc -z  127.0.0.1 $(1) || \
	$(gnome-terminal) -x $(SOC_TERM_PATH)/soc_term $(1) &
endef
else
ifdef xterm
define launch-terminal
	@nc -z  127.0.0.1 $(1) || \
	$(xterm) -title $(2) -e $(BASH) -c "$(SOC_TERM_PATH)/soc_term $(1)" &
endef
else
check-terminal := @echo "Error: could not find gnome-terminal nor xterm" ; false
endif
endif
endif

define wait-for-ports
	@while ! nc -z 127.0.0.1 $(1) || ! nc -z 127.0.0.1 $(2); do sleep 1; done
endef

################################################################################
# OP-TEE
################################################################################
OPTEE_OS_COMMON_FLAGS ?= \
	$(OPTEE_OS_COMMON_EXTRA_FLAGS) \
	CROSS_COMPILE=$(CROSS_COMPILE_S_USER) \
	CROSS_COMPILE_core=$(CROSS_COMPILE_S_KERNEL) \
	CROSS_COMPILE_ta_arm64="$(CCACHE)$(AARCH64_CROSS_COMPILE)" \
	CROSS_COMPILE_ta_arm32="$(CCACHE)$(AARCH32_CROSS_COMPILE)" \
	CFG_TEE_CORE_LOG_LEVEL=$(CFG_TEE_CORE_LOG_LEVEL) \
	DEBUG=$(DEBUG) \
	CFG_TEE_BENCHMARK=$(CFG_TEE_BENCHMARK)

.PHONY: optee-os-common
optee-os-common:
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_COMMON_FLAGS)

OPTEE_OS_CLEAN_COMMON_FLAGS ?= $(OPTEE_OS_COMMON_EXTRA_FLAGS)

.PHONY: optee-os-clean-common
ifeq ($(CFG_TEE_BENCHMARK),y)
optee-os-clean-common: benchmark-app-clean-common
endif
optee-os-clean-common: xtest-clean-common optee-examples-clean-common
	$(MAKE) -C $(OPTEE_OS_PATH) $(OPTEE_OS_CLEAN_COMMON_FLAGS) clean

OPTEE_CLIENT_COMMON_FLAGS ?= CROSS_COMPILE=$(CROSS_COMPILE_NS_USER) \
	CFG_TEE_BENCHMARK=$(CFG_TEE_BENCHMARK) \
	CFG_TA_TEST_PATH=y

.PHONY: optee-client-common
optee-client-common:
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_COMMON_FLAGS)

# OPTEE_CLIENT_CLEAN_COMMON_FLAGS can be defined in specific makefiles
# (hikey.mk,...) if necessary

.PHONY: optee-client-clean-common
optee-client-clean-common:
	$(MAKE) -C $(OPTEE_CLIENT_PATH) $(OPTEE_CLIENT_CLEAN_COMMON_FLAGS) \
		clean

################################################################################
# xtest / optee_test
################################################################################
XTEST_COMMON_FLAGS ?= CROSS_COMPILE_HOST=$(CROSS_COMPILE_NS_USER)\
	CROSS_COMPILE_TA=$(CROSS_COMPILE_S_USER) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
	OPTEE_CLIENT_EXPORT=$(OPTEE_CLIENT_EXPORT) \
	COMPILE_NS_USER=$(COMPILE_NS_USER) \
	O=$(OPTEE_TEST_OUT_PATH)

.PHONY: xtest-common
xtest-common: optee-os optee-client
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_COMMON_FLAGS)

XTEST_CLEAN_COMMON_FLAGS ?= O=$(OPTEE_TEST_OUT_PATH) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \

.PHONY: xtest-clean-common
xtest-clean-common:
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_CLEAN_COMMON_FLAGS) clean

XTEST_PATCH_COMMON_FLAGS ?= $(XTEST_COMMON_FLAGS)

.PHONY: xtest-patch-common
xtest-patch-common:
	$(MAKE) -C $(OPTEE_TEST_PATH) $(XTEST_PATCH_COMMON_FLAGS) patch

################################################################################
# sample applications / optee_examples
################################################################################
OPTEE_EXAMPLES_COMMON_FLAGS ?= HOST_CROSS_COMPILE=$(CROSS_COMPILE_NS_USER)\
	TA_CROSS_COMPILE=$(CROSS_COMPILE_S_USER) \
	TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR) \
	TEEC_EXPORT=$(OPTEE_CLIENT_EXPORT)

.PHONY: optee-examples-common
optee-examples-common: optee-os optee-client
	$(MAKE) -C $(OPTEE_EXAMPLES_PATH) $(OPTEE_EXAMPLES_COMMON_FLAGS)

OPTEE_EXAMPLES_CLEAN_COMMON_FLAGS ?= TA_DEV_KIT_DIR=$(OPTEE_OS_TA_DEV_KIT_DIR)

.PHONY: optee-examples-clean-common
optee-examples-clean-common:
	$(MAKE) -C $(OPTEE_EXAMPLES_PATH) \
			$(OPTEE_EXAMPLES_CLEAN_COMMON_FLAGS) clean

################################################################################
# benchmark_app
################################################################################
BENCHMARK_APP_COMMON_FLAGS ?= CROSS_COMPILE=$(CROSS_COMPILE_NS_USER) \
	TEEC_EXPORT=$(OPTEE_CLIENT_EXPORT) \
	TEEC_INTERNAL_INCLUDES=$(OPTEE_CLIENT_PATH)/libteec \
	MULTIARCH=$(MULTIARCH)

.PHONY: benchmark-app-common
benchmark-app-common: optee-os optee-client
	$(MAKE) -C $(BENCHMARK_APP_PATH) $(BENCHMARK_APP_COMMON_FLAGS)

.PHONY: benchmark-app-clean-common
benchmark-app-clean-common:
	$(MAKE) -C $(BENCHMARK_APP_PATH) clean
