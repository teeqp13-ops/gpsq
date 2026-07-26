export TARGET := iphone:clang:latest:14.0
export ARCHS := arm64
export THEOS_PACKAGE_SCHEME := rootless

INSTALL_TARGET_PROCESSES := Availo

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := GPSQActivation
GPSQActivation_FILES := Sources/GPSQActivation.mm
GPSQActivation_FRAMEWORKS := UIKit Foundation Security MapKit CoreLocation
GPSQActivation_CFLAGS := -fobjc-arc -fblocks -Wall -Wextra -Wno-unused-parameter -Wno-deprecated-declarations
GPSQActivation_LDFLAGS := -Wl,-dead_strip

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Availo || true"
