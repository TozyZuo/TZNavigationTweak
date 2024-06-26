// The MIT License (MIT)
//
// Copyright (c) 2015-2016 forkingdog ( https://github.com/forkingdog )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#import "UINavigationController+TZFullscreenPopGesture.h"
#import <objc/runtime.h>
#import <CoreFoundation/CoreFoundation.h>

@interface TZPanGestureRecognizer : UIPanGestureRecognizer

@end
@implementation TZPanGestureRecognizer

@end

@interface _TZFullscreenPopGestureRecognizerDelegate : NSObject <UIGestureRecognizerDelegate>

@property (nonatomic, weak) UINavigationController *navigationController;
@property (nonatomic, assign) BOOL UIScrollViewPanGestureRecognizerEnable;
@property (nonatomic, assign) BOOL UIPanGestureRecognizerEnable;

@end

static inline void prefsChanged(CFNotificationCenterRef center,
                                void *observer,
                                CFStringRef name,
                                const void *object,
                                CFDictionaryRef userInfo)
{
    NSArray *keyList = (NSArray *)CFBridgingRelease(CFPreferencesCopyKeyList((CFStringRef)@"Tozy.TZNavigationTweak", kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
    preference = (NSDictionary *)CFBridgingRelease(CFPreferencesCopyMultiple((CFArrayRef)keyList, (CFStringRef)@"Tozy.TZNavigationTweak", kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
    
//    TLog(@"prefsChanged %@ %@", name, preference);
    if (preference.count) {
        NSString *key = [(NSString *)CFBridgingRelease(name) componentsSeparatedByString:@"/"].lastObject;
        for (_TZFullscreenPopGestureRecognizerDelegate *delegate in gestureRecognizerDelegates) {
            [delegate setValue:preference[key] forKey:key];
        }
    }
}

@implementation _TZFullscreenPopGestureRecognizerDelegate

- (NSString *)description
{
    return [[super description] stringByAppendingFormat:@"UIScrollViewPanGestureRecognizerEnable: %d UIPanGestureRecognizerEnable:%d", self.UIScrollViewPanGestureRecognizerEnable, self.UIPanGestureRecognizerEnable];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [gestureRecognizerDelegates addObject:self];
        self.UIScrollViewPanGestureRecognizerEnable = preference[@"UIScrollViewPanGestureRecognizerEnable"] ? [preference[@"UIScrollViewPanGestureRecognizerEnable"] boolValue]: YES;
        self.UIPanGestureRecognizerEnable = preference[@"UIPanGestureRecognizerEnable"] ? [preference[@"UIPanGestureRecognizerEnable"] boolValue] : YES;
    }
    return self;
}

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gestureRecognizer
{
    // Ignore when no view controller is pushed into the navigation stack.
    if (self.navigationController.viewControllers.count <= 1) {
        return NO;
    }
    
    // Ignore when the active view controller doesn't allow interactive pop.
    UIViewController *topViewController = self.navigationController.viewControllers.lastObject;
    if (topViewController.tz_interactivePopDisabled) {
        return NO;
    }
    
    // Ignore when the beginning location is beyond max allowed initial distance to left edge.
    CGPoint beginningLocation = [gestureRecognizer locationInView:gestureRecognizer.view];
    CGFloat maxAllowedInitialDistance = topViewController.tz_interactivePopMaxAllowedInitialDistanceToLeftEdge;
    if (maxAllowedInitialDistance > 0 && beginningLocation.x > maxAllowedInitialDistance) {
        return NO;
    }

    // Ignore pan gesture when the navigation controller is currently in transition.
    if ([[self.navigationController valueForKey:@"_isTransitioning"] boolValue]) {
        return NO;
    }
    
    // Prevent calling the handler when the gesture begins in an opposite direction.
    CGPoint translation = [gestureRecognizer translationInView:gestureRecognizer.view];
    BOOL isLeftToRight = [UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionLeftToRight;
    CGFloat multiplier = isLeftToRight ? 1 : - 1;
    if ((translation.x * multiplier) <= 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if ([otherGestureRecognizer isKindOfClass:NSClassFromString(@"UIScrollViewPanGestureRecognizer")] &&
        self.UIScrollViewPanGestureRecognizerEnable)
    {
        return YES;
    }
    if ([otherGestureRecognizer isMemberOfClass:UIPanGestureRecognizer.class] &&
        self.UIPanGestureRecognizerEnable)
    {
        return YES;
    }
    return NO;
}

@end

typedef void (^_TZViewControllerWillAppearInjectBlock)(UIViewController *viewController, BOOL animated);

@interface UIViewController (TZFullscreenPopGesturePrivate)

@property (nonatomic, copy) _TZViewControllerWillAppearInjectBlock tz_willAppearInjectBlock;

@end

@implementation UIViewController (TZFullscreenPopGesturePrivate)

+ (void)enable
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Method viewWillAppear_originalMethod = class_getInstanceMethod(self, @selector(viewWillAppear:));
        Method viewWillAppear_swizzledMethod = class_getInstanceMethod(self, @selector(tz_viewWillAppear:));
        method_exchangeImplementations(viewWillAppear_originalMethod, viewWillAppear_swizzledMethod);
    
        Method viewWillDisappear_originalMethod = class_getInstanceMethod(self, @selector(viewWillDisappear:));
        Method viewWillDisappear_swizzledMethod = class_getInstanceMethod(self, @selector(tz_viewWillDisappear:));
        method_exchangeImplementations(viewWillDisappear_originalMethod, viewWillDisappear_swizzledMethod);
    });
}

- (void)tz_viewWillAppear:(BOOL)animated
{
    // Forward to primary implementation.
    [self tz_viewWillAppear:animated];
    
    if (self.tz_willAppearInjectBlock) {
        self.tz_willAppearInjectBlock(self, animated);
    }
}

- (void)tz_viewWillDisappear:(BOOL)animated
{
    // Forward to primary implementation.
    [self tz_viewWillDisappear:animated];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *viewController = self.navigationController.viewControllers.lastObject;
        if (viewController && !viewController.tz_prefersNavigationBarHidden) {
            [self.navigationController setNavigationBarHidden:NO animated:NO];
        }
    });
}

- (_TZViewControllerWillAppearInjectBlock)tz_willAppearInjectBlock
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setTz_willAppearInjectBlock:(_TZViewControllerWillAppearInjectBlock)block
{
    objc_setAssociatedObject(self, @selector(tz_willAppearInjectBlock), block, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

@implementation UINavigationController (TZFullscreenPopGesture)

+ (void)enable
{
    if ([self instancesRespondToSelector:@selector(fd_fullscreenPopGestureRecognizer)]) {
        TLog(@"%@ already import FDFullscreenPopGesture, give up injecting.", NSBundle.mainBundle.bundleIdentifier);
        return;
    }
    // Inject "-pushViewController:animated:"
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector = @selector(pushViewController:animated:);
        SEL swizzledSelector = @selector(tz_pushViewController:animated:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        BOOL success = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        if (success) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
    
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &prefsChanged, (CFStringRef)@"Tozy.TZNavigationTweak/UIPanGestureRecognizerEnable", NULL, 0);

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &prefsChanged, (CFStringRef)@"Tozy.TZNavigationTweak/UIScrollViewPanGestureRecognizerEnable", NULL, 0);

//    [UIViewController enable];
}

- (void)tz_pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    if (![self.interactivePopGestureRecognizer.view.gestureRecognizers containsObject:self.tz_fullscreenPopGestureRecognizer]) {
        
        // Add our own gesture recognizer to where the onboard screen edge pan gesture recognizer is attached to.
        [self.interactivePopGestureRecognizer.view addGestureRecognizer:self.tz_fullscreenPopGestureRecognizer];
        
        // Forward the gesture events to the private handler of the onboard gesture recognizer.
        NSArray *internalTargets = [self.interactivePopGestureRecognizer valueForKey:@"targets"];
        id internalTarget = [internalTargets.firstObject valueForKey:@"target"];
        SEL internalAction = NSSelectorFromString(@"handleNavigationTransition:");
        self.tz_fullscreenPopGestureRecognizer.delegate = self.tz_popGestureRecognizerDelegate;
        [self.tz_fullscreenPopGestureRecognizer addTarget:internalTarget action:internalAction];
        
        // Disable the onboard gesture recognizer.
        self.interactivePopGestureRecognizer.enabled = NO;
    }
    
    // Handle perferred navigation bar appearance.
    [self tz_setupViewControllerBasedNavigationBarAppearanceIfNeeded:viewController];
    
    // Forward to primary implementation.
    if (![self.viewControllers containsObject:viewController]) {
        [self tz_pushViewController:viewController animated:animated];
    }
}

- (void)tz_setupViewControllerBasedNavigationBarAppearanceIfNeeded:(UIViewController *)appearingViewController
{
    if (!self.tz_viewControllerBasedNavigationBarAppearanceEnabled) {
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    _TZViewControllerWillAppearInjectBlock block = ^(UIViewController *viewController, BOOL animated) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf setNavigationBarHidden:viewController.tz_prefersNavigationBarHidden animated:animated];
        }
    };
    
    // Setup will appear inject block to appearing view controller.
    // Setup disappearing view controller as well, because not every view controller is added into
    // stack by pushing, maybe by "-setViewControllers:".
    appearingViewController.tz_willAppearInjectBlock = block;
    UIViewController *disappearingViewController = self.viewControllers.lastObject;
    if (disappearingViewController && !disappearingViewController.tz_willAppearInjectBlock) {
        disappearingViewController.tz_willAppearInjectBlock = block;
    }
}

- (_TZFullscreenPopGestureRecognizerDelegate *)tz_popGestureRecognizerDelegate
{
    _TZFullscreenPopGestureRecognizerDelegate *delegate = objc_getAssociatedObject(self, _cmd);
    
    if (!delegate) {
        delegate = [[_TZFullscreenPopGestureRecognizerDelegate alloc] init];
        delegate.navigationController = self;
        
        objc_setAssociatedObject(self, _cmd, delegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return delegate;
}

- (UIPanGestureRecognizer *)tz_fullscreenPopGestureRecognizer
{
    UIPanGestureRecognizer *panGestureRecognizer = objc_getAssociatedObject(self, _cmd);
    
    if (!panGestureRecognizer) {
        panGestureRecognizer = [[TZPanGestureRecognizer alloc] init];
        panGestureRecognizer.maximumNumberOfTouches = 1;
        
        objc_setAssociatedObject(self, _cmd, panGestureRecognizer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return panGestureRecognizer;
}

- (BOOL)tz_viewControllerBasedNavigationBarAppearanceEnabled
{
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number) {
        return number.boolValue;
    }
    self.tz_viewControllerBasedNavigationBarAppearanceEnabled = YES;
    return YES;
}

- (void)setTz_viewControllerBasedNavigationBarAppearanceEnabled:(BOOL)enabled
{
    SEL key = @selector(tz_viewControllerBasedNavigationBarAppearanceEnabled);
    objc_setAssociatedObject(self, key, @(enabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UIViewController (TZFullscreenPopGesture)

- (BOOL)tz_interactivePopDisabled
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setTz_interactivePopDisabled:(BOOL)disabled
{
    objc_setAssociatedObject(self, @selector(tz_interactivePopDisabled), @(disabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)tz_prefersNavigationBarHidden
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setTz_prefersNavigationBarHidden:(BOOL)hidden
{
    objc_setAssociatedObject(self, @selector(tz_prefersNavigationBarHidden), @(hidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}


- (CGFloat)tz_interactivePopMaxAllowedInitialDistanceToLeftEdge
{
#if CGFLOAT_IS_DOUBLE
    return [objc_getAssociatedObject(self, _cmd) doubleValue];
#else
    return [objc_getAssociatedObject(self, _cmd) floatValue];
#endif
}

- (void)setTz_interactivePopMaxAllowedInitialDistanceToLeftEdge:(CGFloat)distance
{
    SEL key = @selector(tz_interactivePopMaxAllowedInitialDistanceToLeftEdge);
    objc_setAssociatedObject(self, key, @(MAX(0, distance)), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end
