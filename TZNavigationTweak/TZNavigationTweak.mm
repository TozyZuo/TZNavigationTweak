//
//  TZNavigationTweak.mm
//  TZNavigationTweak
//
//  Created by TozyZuo on 2018/9/5.
//  Copyright (c) 2018年 ___ORGANIZATIONNAME___. All rights reserved.
//

// CaptainHook by Ryan Petrich
// see https://github.com/rpetrich/CaptainHook/

#if TARGET_OS_SIMULATOR
#error Do not support the simulator, please use the real iPhone Device.
#endif

#import <Foundation/Foundation.h>
#import "CaptainHook/CaptainHook.h"
#import "UINavigationController+TZFullscreenPopGesture.h"

NSDictionary *preference;
NSHashTable *gestureRecognizerDelegates;

CHConstructor // code block that runs immediately upon load
{
	@autoreleasepool
	{
        NSString *appId = NSBundle.mainBundle.bundleIdentifier;
        if (!appId) {
            appId = NSProcessInfo.processInfo.processName;//A Fix By https://github.com/radj
            NSLog(@"Process has no bundle ID, use process name instead: %@", appId);
        }
        TLog(@"%@ detected", appId);
        
        NSDictionary *pref = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/Tozy.TZNavigationTweak.plist"];
//        TLog(@"pref %@", pref);

        if (![pref[[NSString stringWithFormat:@"Enabled-%@", appId]] boolValue])
        {
            return;
        }
        
        preference = pref;
        gestureRecognizerDelegates = NSHashTable.weakObjectsHashTable;
        [UINavigationController enable];
	}
}
