#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *const FGHiddenKey=@"FG_Hidden";
static NSString *const FGXKey=@"FG_FloatX";
static NSString *const FGYKey=@"FG_FloatY";
static __weak UIViewController *FGController=nil;
static NSInteger FGVolumeCount=0;
static CFTimeInterval FGLastVolume=0;

static UIImage *FGIcon(NSString *name,CGFloat size){
 if(@available(iOS 13.0,*)){ return [UIImage systemImageNamed:name withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:size weight:UIImageSymbolWeightSemibold]]; }
 return nil;
}
static UIButton *FGFloating(void){ id c=FGController; return [c valueForKey:@"floatingButton"]; }
static void FGRefresh(void){
 UIButton *b=FGFloating(); if(!b)return;
 BOOL enabled=[[NSUserDefaults standardUserDefaults] boolForKey:@"GPSQ_Enabled"];
 b.backgroundColor=enabled?[UIColor colorWithRed:.27 green:.89 blue:.48 alpha:1]:[UIColor colorWithRed:.40 green:.44 blue:.49 alpha:1];
 b.tintColor=enabled?[UIColor colorWithRed:.03 green:.13 blue:.07 alpha:1]:UIColor.whiteColor;
 [b setTitle:@"" forState:UIControlStateNormal];
 UIImage *im=FGIcon(@"location.fill",27); if(im)[b setImage:im forState:UIControlStateNormal];
 b.hidden=[[NSUserDefaults standardUserDefaults] boolForKey:FGHiddenKey];
}
static void FGShowHiddenIcon(void){
 UIButton *b=FGFloating(); if(!b||!b.hidden)return;
 [[NSUserDefaults standardUserDefaults] setBool:NO forKey:FGHiddenKey];
 b.hidden=NO; b.alpha=0; b.transform=CGAffineTransformMakeScale(.7,.7);
 [UIView animateWithDuration:.25 animations:^{b.alpha=1;b.transform=CGAffineTransformIdentity;}];
 if(@available(iOS 10.0,*)) [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
}

@interface NSObject (FGEnhance)
- (void)fg_buildFloatingIcon;
- (void)fg_handleDrag:(UIPanGestureRecognizer*)pan;
- (void)fg_showFullOverlay;
- (void)fg_increaseVolume;
@end
@implementation NSObject (FGEnhance)
- (void)fg_buildFloatingIcon{
 [self fg_buildFloatingIcon]; FGController=(UIViewController*)self;
 UIButton *b=[self valueForKey:@"floatingButton"]; if(!b)return;
 b.layer.borderWidth=2;b.layer.borderColor=[UIColor colorWithWhite:1 alpha:.22].CGColor;
 double x=[[NSUserDefaults standardUserDefaults] doubleForKey:FGXKey],y=[[NSUserDefaults standardUserDefaults] doubleForKey:FGYKey]; if(x>0&&y>0)b.center=CGPointMake(x,y);
 UILongPressGestureRecognizer *hold=[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(fg_hideIcon:)];hold.minimumPressDuration=.65;[b addGestureRecognizer:hold];FGRefresh();
}
- (void)fg_hideIcon:(UILongPressGestureRecognizer*)g{if(g.state!=UIGestureRecognizerStateBegan)return;UIButton*b=(UIButton*)g.view;[[NSUserDefaults standardUserDefaults]setBool:YES forKey:FGHiddenKey];b.hidden=YES;}
- (void)fg_handleDrag:(UIPanGestureRecognizer*)pan{[self fg_handleDrag:pan];if(pan.state==UIGestureRecognizerStateEnded){UIButton*b=[self valueForKey:@"floatingButton"];[[NSUserDefaults standardUserDefaults]setDouble:b.center.x forKey:FGXKey];[[NSUserDefaults standardUserDefaults]setDouble:b.center.y forKey:FGYKey];}}
- (void)fg_showFullOverlay{[self fg_showFullOverlay];UIView*v=[self valueForKey:@"fullOverlay"];for(UIView*x in v.subviews){if([x isKindOfClass:UILabel.class]&&[((UILabel*)x).text containsString:@"GPS"])((UILabel*)x).text=@"FAKE GPS";}v.backgroundColor=[UIColor colorWithRed:.025 green:.035 blue:.055 alpha:1];}
- (void)fg_increaseVolume{[self fg_increaseVolume];CFTimeInterval now=CACurrentMediaTime();if(now-FGLastVolume>1.4)FGVolumeCount=0;FGLastVolume=now;FGVolumeCount++;if(FGVolumeCount>=3){FGVolumeCount=0;dispatch_async(dispatch_get_main_queue(),^{FGShowHiddenIcon();});}}
@end

static void FGSwap(Class c,SEL old,SEL new){Method a=class_getInstanceMethod(c,old),b=class_getInstanceMethod(NSObject.class,new);if(a&&b)method_exchangeImplementations(a,b);}
__attribute__((constructor))static void FGInstall(void){dispatch_async(dispatch_get_main_queue(),^{Class c=NSClassFromString(@"GPSQRootController");FGSwap(c,NSSelectorFromString(@"buildFloatingIcon"),@selector(fg_buildFloatingIcon));FGSwap(c,NSSelectorFromString(@"handleDrag:"),@selector(fg_handleDrag:));FGSwap(c,NSSelectorFromString(@"showFullOverlay"),@selector(fg_showFullOverlay));Class volume=NSClassFromString(@"SBVolumeControl");FGSwap(volume,NSSelectorFromString(@"increaseVolume"),@selector(fg_increaseVolume));});}
