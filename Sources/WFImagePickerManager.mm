//
//  WFImagePickerManager.mm
//  Wolf GPS
//

#import "WFImagePickerManager.h"

@implementation WFImagePickerManager

+ (instancetype)shared {
    static WFImagePickerManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[WFImagePickerManager alloc] init];
    });
    return shared;
}

- (void)presentImagePickerFrom:(UIViewController *)vc {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [vc presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey,id> *)info {
    // UIImage *image = info[UIImagePickerControllerOriginalImage];
    // هنا يمكن إضافة منطق رفع الصورة للسيرفر
    NSLog(@"تم اختيار الصورة بنجاح");
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end
