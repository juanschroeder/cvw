################################################################################
# FBDOOM
################################################################################

# this repo doesn't have tags or releases
FBDOOM_VERSION = master
FBDOOM_SITE = $(call github,maximevince,fbdoom,$(FBDOOM_VERSION))
FBDOOM_LICENSE = Unknown
FBDOOM__COMMIT_ID = 6c599f50e9e8e9436a5c064f42836eb48ff6bde0

FBDOOM_EXTRA_MAKE_ARGS = NOSDL=1 V=1
FBDOOM_CFLAGS := $(filter-out -O% -Ofast -Og -Os -g0 -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64,$(TARGET_CFLAGS)) \
	-O3 -flto -march=rv64gc -mabi=lp64d -fno-exceptions -fno-asynchronous-unwind-tables -fno-unwind-tables -fomit-frame-pointer

define FBDOOM_BUILD_CMDS
	$(TARGET_MAKE_ENV) $(MAKE) -C $(@D)/fbdoom CROSS_COMPILE="$(TARGET_CROSS)" \
			CC="$(TARGET_CC)" PREFIX=/usr \
			CFLAGS="$(FBDOOM_CFLAGS)" \
			LDFLAGS="$(TARGET_LDFLAGS)" $(FBDOOM_EXTRA_MAKE_ARGS) -C $(@D)/fbdoom $(t)
endef


define FBDOOM_INSTALL_TARGET_CMDS
        $(INSTALL) -m 0755 -D $(@D)/fbdoom/fbdoom \
                $(TARGET_DIR)/usr/bin/fbdoom
endef

$(eval $(generic-package))
