export TARGET := iphone:clang:latest:16.0
export ARCHS := arm64 arm64e

INSTALL_TARGET_PROCESSES := SpringBoard Maps
THEOS_PACKAGE_SCHEME ?= rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := gpsq

gpsq_FILES := \
  gpsq.mm \
  Core/GPSQManager.mm \
  Core/ActivationManager.mm \
  Core/UUIDManager.mm \
  Core/NetworkManager.mm \
  Core/StorageManager.mm \
  UI/MainView.mm \
  UI/ActivationView.mm \
  UI/Components.mm \
  Map/MapController.mm \
  Map/SearchController.mm \
  Map/FavoritesManager.mm \
  Utils/Logger.mm

gpsq_FRAMEWORKS := UIKit Foundation CoreLocation MapKit QuartzCore
gpsq_CFLAGS := -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -IHeaders
gpsq_CCFLAGS := -std=c++17

gpsq_RESOURCE_DIRS := Resources

include $(THEOS_MAKE_PATH)/tweak.mk
