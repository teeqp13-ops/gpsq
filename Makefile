export TARGET := iphone:clang:latest:14.0
export ARCHS := arm64 arm64e

INSTALL_TARGET_PROCESSES := SpringBoard
THEOS_PACKAGE_SCHEME ?= rootless

# Resolve THEOS correctly in GitHub Actions, macOS runners, and jailbreak devices.
# Prefer the environment supplied by the workflow; only use known local fallbacks.
ifeq ($(strip $(THEOS)),)
  ifneq ($(wildcard $(CURDIR)/theos/makefiles/common.mk),)
    THEOS := $(CURDIR)/theos
  else ifneq ($(wildcard $(HOME)/theos/makefiles/common.mk),)
    THEOS := $(HOME)/theos
  else ifneq ($(wildcard /opt/theos/makefiles/common.mk),)
    THEOS := /opt/theos
  else ifneq ($(wildcard /var/jb/var/mobile/theos/makefiles/common.mk),)
    THEOS := /var/jb/var/mobile/theos
  else
    $(error THEOS is not configured. Set THEOS to a valid Theos installation)
  endif
endif

export THEOS
THEOS_MAKE_PATH := $(THEOS)/makefiles

include $(THEOS_MAKE_PATH)/common.mk

TWEAK_NAME := gpsq FakeGPSLocation

gpsq_FILES := FakeGPS.mm SharedBridge.xm FeaturePack.xm
gpsq_FRAMEWORKS := UIKit Foundation QuartzCore MapKit CoreLocation AVFoundation
gpsq_CFLAGS := -fobjc-arc -Wall -Wextra -Wno-error -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable -Wno-unused-parameter
gpsq_LDFLAGS := -Wl,-dead_strip

FakeGPSLocation_FILES := LocationSpoof.xm
FakeGPSLocation_FRAMEWORKS := Foundation CoreLocation
FakeGPSLocation_CFLAGS := -fobjc-arc -Wall -Wextra -Wno-error -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable -Wno-unused-parameter
FakeGPSLocation_LDFLAGS := -Wl,-dead_strip

include $(THEOS_MAKE_PATH)/tweak.mk

before-package::
	@rm -rf "$(THEOS_STAGING_DIR)/Library/Application Support/FAKEGPS"
	@mkdir -p "$(THEOS_STAGING_DIR)/Library/Application Support/FAKEGPS"
	@cp -R Resources/. "$(THEOS_STAGING_DIR)/Library/Application Support/FAKEGPS/"

after-install::
	install.exec "sbreload"
