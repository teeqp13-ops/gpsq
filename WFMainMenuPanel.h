//
//  WFMainMenuPanel.h
//  WolFox GPS
//

#import <UIKit/UIKit.h>

@interface WFMainMenuPanel : UIView

+ (void)presentOverView:(UIView *)hostView
                 onClose:(void (^)(void))onClose
                onSearch:(void (^)(void))onSearch
             onToggleRun:(void (^)(BOOL isRunning))onToggleRun
          onToggleUpload:(void (^)(BOOL isUploading))onToggleUpload
                   onMap:(void (^)(void))onMap
                    onID:(void (^)(void))onID;

@end
