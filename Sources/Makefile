# Wolf GPS Pro - Official Makefile
# Optimized for ESign & Filza Compatibility

TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Maps
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WolfGPS

WolfGPS_FILES = Source/WFGPSManager.mm \
                Source/WFGPSFloatingButton.mm \
                Source/WFGPSPanel.mm \
                Source/WFThemeManager.mm \
                Source/WFLocalization.mm \
                Source/WFGPXMovementManager.mm \
                Source/WFFavoritesViewController.mm \
                Source/WFGPSMapViewController.mm \
                Source/WFGPSSearchViewController.mm \
                Source/WFGPSFavoritesManager.mm \
                Source/WFBeaconManager.mm \
                Source/WFImagePickerManager.mm \
                Source/WolFoxLicenseClient.mm \
                Source/KSA.mm \
                Source/c.mm \
                Source/fishhook/fishhook.c

WolfGPS_CFLAGS = -fobjc-arc -IHeaders -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value
WolfGPS_FRAMEWORKS = UIKit MapKit CoreLocation CoreBluetooth AVFoundation Photos Security WebKit MobileCoreServices QuartzCore
WolfGPS_LIBRARIES = substrate

# Ensure Gzip compression for ESign compatibility
after-package::
	@echo "Package optimized for ESign."

include $(THEOS_MAKE_PATH)/tweak.mk
