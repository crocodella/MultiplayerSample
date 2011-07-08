//
//  MultiplayerSampleAppDelegate.h
//  Multiplayer Sample
//
//  Created by Fabio Rodella on 7/20/10.
//  Copyright 2010 Crocodella Software. All rights reserved.
//

#import <UIKit/UIKit.h>

@class MultiplayerSampleViewController;

@interface MultiplayerSampleAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
    MultiplayerSampleViewController *viewController;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet MultiplayerSampleViewController *viewController;

@end

