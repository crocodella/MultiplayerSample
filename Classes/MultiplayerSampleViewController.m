//
//  MultiplayerSampleViewController.m
//  Multiplayer Sample
//
//  Created by Fabio Rodella on 7/20/10.
//  Copyright 2010 Crocodella Software. All rights reserved.
//

#import "MultiplayerSampleViewController.h"

@implementation MultiplayerSampleViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	
	if ([self isGameCenterAvailable] && USE_GAME_CENTER) {
		
		// If GameCenter is available and the app is configured to use it, authenticates the player
		
		[connectButton setTitle:@"Authenticating..." forState:UIControlStateDisabled];
		connectButton.enabled = NO;
		
		[[GKLocalPlayer localPlayer] authenticateWithCompletionHandler:^(NSError *error) {
			
			if (error == nil) {
				
				player1NameLabel.text = [[GKLocalPlayer localPlayer] alias];
			
				connectButton.enabled = YES;
				
				// Setups the invite handler
				
				[GKMatchmaker sharedMatchmaker].inviteHandler = ^(GKInvite *acceptedInvite, NSArray *playersToInvite) {
					
					if (acceptedInvite) {
						
						// Individual invite (from inside the game)
						
						GKMatchmakerViewController *mmvc = [[[GKMatchmakerViewController alloc] initWithInvite:acceptedInvite] autorelease];
						
						mmvc.matchmakerDelegate = self;
						
						[self presentModalViewController:mmvc animated:YES];
						
					} else if (playersToInvite) {
						
						// In Apple's documentation, it's not clear when this option is used.
						// In theory, this should be called when a game is initiated from the
						// GameCenter app itself, however as of iOS 4.2.1 this is not apparently
						// possible.
						
						GKMatchRequest *request = [[[GKMatchRequest alloc] init] autorelease];
						
						request.minPlayers = 2;
						
						request.maxPlayers = 2;
						
						request.playersToInvite = playersToInvite;
						
						GKMatchmakerViewController *mmvc = [[[GKMatchmakerViewController alloc] initWithMatchRequest:request] autorelease];
						
						mmvc.matchmakerDelegate = self;
						
						[self presentModalViewController:mmvc animated:YES];
						
					}
				};
				
				
			} else {
				
				// Authentication error
				
				UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Could not authenticate with GameCenter" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
				[alert show];
				[alert release];
			}
		}];
	}
	
}

- (void)dealloc {
    [super dealloc];
}

- (void)onStateChangedTo:(NetworkState)state {
	
	if (state == kNetworkStateWaitingForConnection) {
		
		// Has connected to the matchmaking server, so tries to establish a connection
		
		[[NetworkManager sharedManager] establishConnection];
		
	} else if (state == kNetworkStateConnectedGameCenter) {
		
		connectButton.hidden = YES;
		
		// Sends the local name to the remote player
		
		NetworkCommand *cmd = [[NetworkCommand alloc] initWithType:kNetworkCommandTypeName andParam:[[GKLocalPlayer localPlayer] alias]];
		[[NetworkManager sharedManager] sendCommand:cmd];
		[cmd release];
	
	} else if (state == kNetworkStateConnectedAsServer || state == kNetworkStateConnectedAsClient) {
		
		connectButton.hidden = YES;
	
	} else if (state == kNetworkStateError) {
		
		// This state is set on network timeout, disconnect and other
		// connection problems
		
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:[NetworkManager sharedManager].message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
}

- (void)onCommandReceived:(NetworkCommand *)cmd {
	
	if (cmd.type == kNetworkCommandTypeMove) {
		
		// Extract the move coordinates from the network command
		
		NSArray* parts = [cmd.param componentsSeparatedByString:@":"];
		
		NSString *strX = [parts objectAtIndex:0];
		NSString *strY = [parts objectAtIndex:1];
		
		float x = [strX floatValue];
		float y = [strY floatValue];

		player2ImageView.center = CGPointMake(x, y);
		player2NameLabel.center = CGPointMake(x, y - 50);

	} else if (cmd.type == kNetworkCommandTypeName) {
		
		player2NameLabel.text = cmd.param;
	}
}

- (IBAction)connect {
	
	[connectButton setTitle:@"Finding match..." forState:UIControlStateDisabled];
	connectButton.enabled = NO;
	
	[NetworkManager sharedManager].delegate = self;
	
	if ([self isGameCenterAvailable] && USE_GAME_CENTER) {
		
		if ([[GKLocalPlayer localPlayer] isAuthenticated]) {
			
			// If the player is already authenticated, presents the matchmaking interface
			
			GKMatchRequest *request = [[[GKMatchRequest alloc] init] autorelease];
			request.minPlayers = 2;
			request.maxPlayers = 2;
			
			GKMatchmakerViewController *mmvc = [[[GKMatchmakerViewController alloc] initWithMatchRequest:request] autorelease];
			mmvc.matchmakerDelegate = self;
			
			[self presentModalViewController:mmvc animated:YES];
		}
		
	} else {
		
		// Connects to the matchmaking server to try to find a match
		
		[[NetworkManager sharedManager] findMatch];

	}
}

- (BOOL)isGameCenterAvailable {
	
	// This is taken straight from Apple's documentation
	
    // Check for presence of GKLocalPlayer API.
    Class gcClass = (NSClassFromString(@"GKLocalPlayer"));
	
    // The device must be running running iOS 4.1 or later.
    NSString *reqSysVer = @"4.1";
    NSString *currSysVer = [[UIDevice currentDevice] systemVersion];
    BOOL osVersionSupported = ([currSysVer compare:reqSysVer options:NSNumericSearch] != NSOrderedAscending);
	
    return (gcClass && osVersionSupported);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	player1ImageView.center = [touch locationInView:[touch view]];
	player1NameLabel.center = CGPointMake(player1ImageView.center.x, player1ImageView.center.y - 50);
	
	if ([[NetworkManager sharedManager] isConnected]) {
		
		// Sends the command with the new position to the remote player
		
		NSString *pos = [NSString stringWithFormat:@"%.0f:%.0f", player1ImageView.center.x, player1ImageView.center.y];
		NetworkCommand *cmd = [[NetworkCommand alloc] initWithType:kNetworkCommandTypeMove andParam:pos];
		[[NetworkManager sharedManager] sendCommand:cmd];
		[cmd release];
	}
}

- (void)matchmakerViewControllerWasCancelled:(GKMatchmakerViewController *)viewController {
    [self dismissModalViewControllerAnimated:YES];
	connectButton.enabled = YES;
}

- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFailWithError:(NSError *)error {
    [self dismissModalViewControllerAnimated:YES];
	connectButton.enabled = YES;
}

- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFindMatch:(GKMatch *)match {
	
	// A match has been found, so sets it on the NetworkManager
	
	[NetworkManager setGameCenterMatch:match];
	
	// This is actually not described on the Apple documentation. When this method is called
	// through an invite, the expectedPlayerCount is already zero, and the match:player:didChangeState
	// method IS NOT CALLED on the delegate. To work around this, we call this method manually.
	
	if (match.expectedPlayerCount == 0) {
		[[NetworkManager sharedManager] match:match player:@"none" didChangeState:GKPlayerStateConnected];
	}
	
	[self dismissModalViewControllerAnimated:YES];
}

@end
