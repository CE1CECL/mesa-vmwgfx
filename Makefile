# Makefile -- For the Direct Rendering Manager module (drm)
#
# Based on David Woodhouse's mtd build.
#
# Modified to handle the DRM requirements and builds on a wider range of
# platforms in a flexible way by David Dawes.  It's not clear, however,
# that this approach is simpler than the old one.
#
# The purpose of this Makefile is to handle setting up everything
# needed for an out-of-kernel source build.  Makefile.kernel contains
# everything required for in-kernel source builds.  It is included into
# this file, so none of that should be duplicated here.
#
# $XFree86: xc/programs/Xserver/hw/xfree86/os-support/linux/drm/kernel/Makefile.linux,v 1.40 2003/08/17 17:12:25 dawes Exp $
#

#
# By default, the build is done against the running linux kernel source.
# To build against a different kernel source tree, set LINUXDIR:
#
#    make LINUXDIR=/path/to/kernel/source

#
# To build only some modules, either set DRM_MODULES to the list of modules,
# or specify the modules as targets:
#
#    make r128.o radeon.o
#
# or:
#
#    make DRM_MODULES="r128 radeon"
#

SHELL=/bin/sh

.SUFFIXES:

ifndef LINUXDIR
RUNNING_REL := $(shell uname -r)

LINUXDIR := $(shell if [ -e /lib/modules/$(RUNNING_REL)/source ]; then \
		 echo /lib/modules/$(RUNNING_REL)/source; \
		 else echo /lib/modules/$(RUNNING_REL)/build; fi)
endif

ifndef O
O := $(shell if [ -e /lib/modules/$(RUNNING_REL)/build ]; then \
		 echo /lib/modules/$(RUNNING_REL)/build; \
		 else echo ""; fi)
#O := $(LINUXDIR)
endif

ifdef ARCH
MACHINE := $(ARCH)
else
MACHINE := $(shell uname -m)
endif

# These definitions are for handling dependencies in the out of kernel build.

DRMHEADERS =    drmP.h drm_compat.h drm_os_linux.h drm.h drm_sarea.h
COREHEADERS =   drm_core.h drm_sman.h drm_hashtab.h
TTMHEADERS  =   ttm/ttm_bo_api.h ttm/ttm_bo_driver.h\
		ttm/ttm_bo_user_helper.h ttm/ttm_execbuf_util.h\
		ttm/ttm_lock.h ttm/ttm_memory.h ttm/ttm_module.h\
	        ttm/ttm_object.h ttm/ttm_pat_compat.h ttm/ttm_placement.h
VMWGFXHEADERS = vmwgfx_drv.h vmwgfx_reg.h vmwgfx_drm.h

CLEANFILES = *.o *.ko .depend .*.flags .*.d .*.cmd *.mod.c .tmp_versions\
	Module.markers modules.order Module.symvers 

# VERSION is not defined from the initial invocation.  It is defined when
# this Makefile is invoked from the kernel's root Makefile.

ifndef VERSION

ifdef RUNNING_REL

# SuSE has the version.h and autoconf.h headers for the current kernel
# in /boot as /boot/vmlinuz.version.h and /boot/vmlinuz.autoconf.h.
# Check these first to see if they match the running kernel.

BOOTVERSION_PREFIX = /boot/vmlinuz.

V := $(shell if [ -f $(BOOTVERSION_PREFIX)version.h ]; then \
	grep UTS_RELEASE $(BOOTVERSION_PREFIX)version.h | \
	cut -d' ' -f3; fi)

ifeq ($(V),"$(RUNNING_REL)")
HEADERFROMBOOT := 1
GETCONFIG := MAKEFILES=$(shell /bin/pwd)/.config
HAVECONFIG := y
endif

# On Red Hat we need to check if there is a .config file in the kernel
# source directory.  If there isn't, we need to check if there's a
# matching file in the configs subdirectory.

ifneq ($(HAVECONFIG),y)
HAVECONFIG := $(shell if [ -e $(LINUXDIR)/.config ]; then echo y; fi)
endif

ifneq ($(HAVECONFIG),y)
REL_BASE := $(shell echo $(RUNNING_REL) | sed 's/-.*//')
REL_TYPE := $(shell echo $(RUNNING_REL) | sed 's/[0-9.-]//g')
ifeq ($(REL_TYPE),)
RHCONFIG := configs/kernel-$(REL_BASE)-$(MACHINE).config
else
RHCONFIG := configs/kernel-$(REL_BASE)-$(MACHINE)-$(REL_TYPE).config
endif
HAVECONFIG := $(shell if [ -e $(LINUXDIR)/$(RHCONFIG) ]; then echo y; fi)
ifneq ($(HAVECONFIG),y)
RHCONFIG :=
endif
endif

ifneq ($(HAVECONFIG),y)
ifneq ($(0),$(LINUXDIR))
GETCONFIG += O=$(O)
endif
HAVECONFIG := $(shell if [ -e $(O)/.config ]; then echo y; fi)
endif

ifneq ($(HAVECONFIG),y)
$(error Cannot find a kernel config file)
endif

endif

CLEANCONFIG := $(shell if cmp -s $(LINUXDIR)/.config .config; then echo y; fi)
ifeq ($(CLEANCONFIG),y)
CLEANFILES += $(LINUXDIR)/.config .config $(LINUXDIR)/tmp_include_depends
endif

all: modules

modules: 
	+make -C $(LINUXDIR) $(GETCONFIG) SUBDIRS=`/bin/pwd` DRMSRCDIR=`/bin/pwd` modules

ifeq ($(HEADERFROMBOOT),1)

BOOTHEADERS = version.h autoconf.h
BOOTCONFIG = .config

CLEANFILES += $(BOOTHEADERS) $(BOOTCONFIG)

includes:: $(BOOTHEADERS) $(BOOTCONFIG)

version.h: $(BOOTVERSION_PREFIX)version.h
	rm -f $@
	ln -s $< $@

autoconf.h: $(BOOTVERSION_PREFIX)autoconf.h
	rm -f $@
	ln -s $< $@

.config: $(BOOTVERSION_PREFIX)config
	rm -f $@
	ln -s $< $@
endif

# This prepares an unused Red Hat kernel tree for the build.
ifneq ($(RHCONFIG),)
includes:: $(LINUXDIR)/.config $(LINUXDIR)/tmp_include_depends .config

$(LINUXDIR)/.config: $(LINUXDIR)/$(RHCONFIG)
	rm -f $@
	ln -s $< $@

.config: $(LINUXDIR)/$(RHCONFIG)
	rm -f $@
	ln -s $< $@

$(LINUXDIR)/tmp_include_depends:
	echo all: > $@
endif

clean cleandir:
	rm -rf $(CLEANFILES)

$(MODULE_LIST)::
	make DRM_MODULES=$@ modules

install:
	make -C $(LINUXDIR) $(GETCONFIG) SUBDIRS=`/bin/pwd` DRMSRCDIR=`/bin/pwd` modules_install

else

# Check for kernel versions that we don't support.

BELOW26 := $(shell if [ $(VERSION) -lt 2 -o $(VERSION) -eq 2 -a $(PATCHLEVEL) -lt 6 ]; then \
		echo y; fi)

ifeq ($(BELOW26),y)
$(error Only 2.6.x and later kernels are supported \
	($(VERSION).$(PATCHLEVEL).$(SUBLEVEL)))
endif

ifdef ARCHX86
ifndef CONFIG_X86_CMPXCHG
$(error CONFIG_X86_CMPXCHG needs to be enabled in the kernel)
endif
endif

# This needs to go before all other include paths.
EXTRA_CFLAGS += -I$(DRMSRCDIR)

include $(DRMSRCDIR)/Makefile.kernel

# Depencencies
$(vmwgfx-objs):	$(DRMHEADERS) $(COREHEADERS) $(TTMHEADERS) $(VMWGFXHEADERS)


endif
