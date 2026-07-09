export TARGET := iphone:clang:latest:16.0
export ARCHS := arm64 arm64e

INSTALL_TARGET_PROCESSES := SpringBoard Maps
THEOS_PACKAGE_SCHEME ?= rootless

GPSQ_API_BASE ?= https://ipa.p3nd.fun/server/public/api
GPSQ_API_KEY ?=

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := gpsq

gpsq_FILES := gpsq.mm
gpsq_FRAMEWORKS := UIKit Foundation QuartzCore
gpsq_CFLAGS := -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -DGPSQ_API_BASE=@\"$(GPSQ_API_BASE)\" -DGPSQ_API_KEY=@\"$(GPSQ_API_KEY)\"

include $(THEOS_MAKE_PATH)/tweak.mk
