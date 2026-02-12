# required for buildroot external tree

include $(sort $(wildcard $(BR2_EXTERNAL_WALLY_PATH)/package/*/*.mk))
