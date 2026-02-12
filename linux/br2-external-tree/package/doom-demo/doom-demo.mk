################################################################################
#
# doom-demo
#
################################################################################

DOOM_DEMO_VERSION = 1
DOOM_DEMO_SITE = https://classicdoom.com
DOOM_DEMO_SOURCE = bounce1.lmp
DOOM_DEMO_SITE_METHOD = wget

DOOM_DEMO_LICENSE = Proprietary
# No license file shipped alongside the .lmp download.
# DOOM_DEMO_LICENSE_FILES =

# Single file, nothing to extract/unpack
define DOOM_DEMO_EXTRACT_CMDS
	:
endef

define DOOM_DEMO_INSTALL_TARGET_CMDS
	$(INSTALL) -D -m 0644 $(DOOM_DEMO_DL_DIR)/bounce1.lmp \
		$(TARGET_DIR)/usr/share/games/doom/bounce1.lmp

	$(INSTALL) -D -m 0755 $(DOOM_DEMO_PKGDIR)/doom-short-demo.sh \
		$(TARGET_DIR)/usr/bin/doom-short-demo.sh
	$(INSTALL) -D -m 0755 $(DOOM_DEMO_PKGDIR)/doom-demo.sh \
		$(TARGET_DIR)/usr/bin/doom-demo.sh
endef

$(eval $(generic-package))
