export TARGET := iphone:clang:latest:14.0
export ARCHS := arm64 arm64e

INSTALL_TARGET_PROCESSES := SpringBoard
THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := gpsq

gpsq_FILES := FakeGPS.mm
gpsq_FRAMEWORKS := UIKit Foundation QuartzCore MapKit CoreLocation AVFoundation
gpsq_CFLAGS := -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable
gpsq_LDFLAGS := -Wl,-dead_strip

include $(THEOS_MAKE_PATH)/tweak.mk
