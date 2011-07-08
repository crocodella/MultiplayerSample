//
//  MultiplayerSampleViewController.h
//  Multiplayer Sample
//
//  Created by Fabio Rodella on 7/20/10.
//  Copyright 2010 Crocodella Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NetworkManager.h"

// Flag determining if GameCenter should be used if available
#define USE_GAME_CENTER YES

@interface MultiplayerSampleViewController : UIViewController <NetworkResponder, GKMatchmakerViewControllerDelegate> {
	IBOutlet UIImageView *player1ImageView;
	IBOutlet UIImageView *player2ImageView;
	IBOutlet UILabel *player1NameLabel;
	IBOutlet UILabel *player2NameLabel;
	IBOutlet UIButton *connectButton;
}

- (IBAction)connect;

- (BOOL)isGameCenterAvailable;

@end

