#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "fishhook/fishhook.h"

static bool (*orig_APMIdentity_1)(id self, SEL _cmd);

static bool new_APMIdentity_1(id self, SEL _cmd) {
    return YES;
}

static void MethodSwizzle(Class cls, SEL sel, IMP newImp, IMP *origImp) {
    Method method = class_getInstanceMethod(cls, sel);
    if (method) {
        *origImp = method_setImplementation(method, newImp);
    }
}

__attribute__((constructor))
static void apm_identity_hook_init(void) {
    Class cls = objc_getClass("APMIdentity");
    if (cls) {
        MethodSwizzle(cls,
                      @selector(isFromAppStore),
                      (IMP)new_APMIdentity_1,
                      (IMP *)&orig_APMIdentity_1);
    }
}

static BOOL fake_jailbroken(id self, SEL _cmd) {
    return NO;
}

static void fake_void_id(id self, SEL _cmd, id arg) {
    (void)self;
    (void)_cmd;
    (void)arg;
}

static id fake_init(id self, SEL _cmd) {
    (void)_cmd;
    return self;
}

static void hookMethod(Class cls, SEL sel, IMP imp) {
    Method m = class_getInstanceMethod(cls, sel);
    if (m) {
        method_setImplementation(m, imp);
    }
}

__attribute__((constructor))
static void jailbreak_bypass_init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(0.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{

        Class jbPlugin = objc_getClass("JailbreakDetectionPlugin");
        if (jbPlugin) {
            hookMethod(jbPlugin, @selector(coolMethod:), (IMP)fake_void_id);
            hookMethod(jbPlugin, @selector(isJailbroken:), (IMP)fake_void_id);
            hookMethod(jbPlugin, @selector(init), (IMP)fake_init);
            hookMethod(jbPlugin, @selector(pluginInitialize), (IMP)fake_void_id);
        }

        Class jbDetect = objc_getClass("JailbreakDetection");
        if (jbDetect) {
            hookMethod(jbDetect, @selector(isJailbroken:), (IMP)fake_void_id);
            hookMethod(jbDetect, @selector(jailbroken), (IMP)fake_jailbroken);
        }
    });
}
