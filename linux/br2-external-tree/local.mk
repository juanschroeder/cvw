override STRACE_VERSION = 6.18
override STRACE_SOURCE = strace-$(STRACE_VERSION).tar.xz
override STRACE_SITE = https://github.com/strace/strace/releases/download/v$(STRACE_VERSION)
# This prevents hash check errors since the main tree won't have the 6.18 hash
BR_NO_CHECK_HASH_FOR += $(STRACE_SOURCE)


# Fix an error during extract of sources (because it's custom u-boot??)
override UBOOT_POST_EXTRACT_HOOKS =
