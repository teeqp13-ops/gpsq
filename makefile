ARCHS = arm64
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = libR6X9

libR6X9_FILES = ok.mm fishhook/fishhook.c WFAuthClient.m WFCodeEntryView.mm
libR6X9_FRAMEWORKS = UIKit Foundation MetalKit Metal ModelIO Security QuartzCore CoreGraphics CoreText AudioToolbox AVFoundation Accelerate Photos MediaPlayer CoreAudio MapKit CoreLocation CoreBluetooth WebKit
libR6X9_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-value -Wno-enum-conversion
libR6X9_LDFLAGS += -lc++ -lobjc -lc -Wl,-U,___isPlatformVersionAtLeast -ObjC

include $(THEOS_MAKE_PATH)/tweak.mk
