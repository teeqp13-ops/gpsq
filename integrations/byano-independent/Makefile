export TARGET := iphone:clang:latest:14.0
export ARCHS := arm64
export THEOS_PACKAGE_SCHEME := rootless

INSTALL_TARGET_PROCESSES := Availo

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := BYANOActivation
BYANOActivation_FILES := GPSPlusActivation.mm
BYANOActivation_FRAMEWORKS := UIKit Foundation
BYANOActivation_CFLAGS := -fobjc-arc -Wall -Wextra

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 Availo || true"
