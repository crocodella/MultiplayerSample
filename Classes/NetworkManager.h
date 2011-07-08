//
//  NetworkManager.h
//  Multiplayer Sample
//
//  Created by Fabio Rodella on 7/20/10.
//  Copyright 2010 Crocodella Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <GameKit/GameKit.h>
#import "AsyncSocket.h"
#import "NetworkCommand.h"
#import "PortMapper.h"

#define PORT 16885

typedef enum tagNetworkState {
	kNetworkStateDisconnected,
	kNetworkStateConnectingToServer,
	kNetworkStateWaitingForConnection,
	kNetworkStateConnectedAsServer,
	kNetworkStateConnectedAsClient,
	kNetworkStateConnectedGameCenter,
	kNetworkStateCommandSent,
	kNetworkStateCommandReceived,
	kNetworkStateError
} NetworkState;

@protocol NetworkResponder

- (void)onStateChangedTo:(NetworkState)state;

- (void)onCommandReceived:(NetworkCommand *)cmd;

@end

@interface NetworkManager : NSObject <GKMatchDelegate> {
	NSMutableData* responseData;
	AsyncSocket* listenSocket;
	AsyncSocket* clientSocket;
	NetworkState state;
	NSString* message;
	id delegate;
	BOOL connected;
	BOOL server;
	NetworkCommand* lastCommandSent;
	PortMapper* mapper;
	GKMatch *gkMatch;
}

@property (readwrite,assign) NetworkState state;
@property (readwrite,retain) NSString* message;
@property (readwrite,retain) id delegate;
@property (readwrite,retain) GKMatch *gkMatch;

+ (NetworkManager*)sharedManager;
+ (void)setGameCenterMatch:(GKMatch *)match;
+ (GKMatch *)getGameCenterMatch;
- (void)findMatch;
- (void)establishConnection;
- (void)disconnect;
- (void)sendCommand:(NetworkCommand*) cmd;
- (BOOL)isConnected;
- (void)changeStateTo:(NetworkState) newState withMessage:(NSString*) msg;

@end
