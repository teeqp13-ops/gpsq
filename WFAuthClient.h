#import <Foundation/Foundation.h>

@interface WFAuthClient : NSObject
+ (void)activateWithCode:(NSString *)code completion:(void (^)(BOOL success, NSString *message))completion;
+ (BOOL)isActivated;
@end
