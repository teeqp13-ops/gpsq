#import "WFAuthClient.h"
#import <UIKit/UIKit.h>

@implementation WFAuthClient

+ (void)activateWithCode:(NSString *)code completion:(void (^)(BOOL success, NSString *message))completion {
    NSString *udid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    // استخدام HTTPS بشكل رسمي
    NSString *urlStr = [NSString stringWithFormat:@"https://laylastore.site/api/verify.php?code=%@&udid=%@", 
                        [code stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]], 
                        [udid stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:15.0];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(NO, [NSString stringWithFormat:@"خطأ اتصال: %@", error.localizedDescription]);
            });
            return;
        }
        
        NSError *jsonError;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (json && [json[@"status"] isEqualToString:@"success"]) {
                [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"WF_IsActivated"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                completion(YES, @"تم التفعيل بنجاح");
            } else {
                NSString *errMsg = json[@"message"] ?: @"كود غير صحيح";
                completion(NO, errMsg);
            }
        });
    }];
    [task resume];
}

+ (BOOL)isActivated {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"WF_IsActivated"];
}

@end
