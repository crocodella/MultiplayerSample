//
//  NetworkManager.m
//  Cornered
//
//  Created by Fabio Rodella on 7/20/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "NetworkManager.h"

@implementation NetworkManager

@synthesize state;
@synthesize message;
@synthesize delegate;
@synthesize gkMatch;

static NetworkManager* _networkManager = nil;

+ (NetworkManager*)sharedManager {
	
	// Gets a reference to the singleton
	
	@synchronized([NetworkManager class]) {
		if (!_networkManager)
			[[self alloc] init];
		return _networkManager;
	}
	return nil;
}

+ (void)setGameCenterMatch:(GKMatch *)match {
	
	// Sets the GameCenter match, and also set the NetworkManager
	// as its delegate.
	
	@synchronized([NetworkManager class]) {
		if (_networkManager) {
			_networkManager.gkMatch = match;
			if (match != nil) {
				match.delegate = _networkManager;
			}
		}
	}
}

+ (GKMatch *)getGameCenterMatch {
	@synchronized([NetworkManager class]) {
		if (_networkManager) {
			return _networkManager.gkMatch;
		}
		return nil;
	}
}

+ (id)alloc {
	@synchronized([NetworkManager class]) {
		NSAssert(_networkManager == nil, @"Attempted to allocate a second instance of a singleton");
		_networkManager = [super alloc];
		return _networkManager;
	}
	return nil;
}

- (id)init {
	self =  [super init];
	if (self != nil) {
		state = kNetworkStateDisconnected;
		connected = NO;
		message = nil;
	}
	return self;
}

- (void)changeStateTo:(NetworkState)newState withMessage:(NSString *)msg {
	self.state = newState;
	
	NSLog(@"State changed: %d", newState);
	
	[message release];
	message = [msg retain];
	
	[delegate onStateChangedTo:newState];
}

- (void)findMatch {
	
	// Finds a match through the homebrew matchmaking server. In this case,
	// the server is a really simple Java servlet, which responds with an IP
	// address if there's someone waiting to play, or SERVER if there's no
	// one waiting.
	
	if (state != kNetworkStateDisconnected) {
		[self disconnect];
	}
	
	server = NO;
	listenSocket = nil;
	clientSocket = nil;
	
	responseData = [[NSMutableData data] retain];
	NSURL *url = [NSURL URLWithString:@"<fill your server address here>"];
	
	NSURLRequest* request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:5.0f ];
	[[[NSURLConnection alloc] initWithRequest:request delegate:self] autorelease];
	
	[self changeStateTo:kNetworkStateConnectingToServer withMessage:nil];
}

- (void)portMappingChanged: (NSNotification*)n
{
    // This is where we get notified that the mapping was created, or that no mapping exists,
    // or that mapping failed.
	
    if( mapper.error )
        NSLog(@"!! PortMapper error %i", mapper.error);
    else {
        NSString *_message = @"";
        if( !mapper.isMapped )
            _message = @" (no address translation!)";
        NSLog(@"** Public address:port is %@:%hu%@", mapper.publicAddress,mapper.publicPort,_message);
    }
}


- (void)establishConnection {
	
	if (state == kNetworkStateWaitingForConnection) {
		
		if ([message hasPrefix:@"SERVER"]) {
			
			server = YES;
			
			// Tries to open the used port through uPnP
			
			mapper = [[PortMapper alloc] initWithPort: PORT];
			mapper.desiredPublicPort = PORT;
			
			// Now open the mapping (asynchronously):
			if( [mapper open] ) {
				NSLog(@"Opening port mapping...");
				// Now listen for notifications to find out when the mapping opens, fails, or changes:
				[[NSNotificationCenter defaultCenter] addObserver: self 
														 selector: @selector(portMappingChanged:) 
															 name: PortMapperChangedNotification 
														   object: mapper];
			} else {
				// PortMapper failed -- this is unlikely, but be graceful:
				NSLog(@"!! Error: PortMapper wouldn't start: %i",mapper.error);
				[mapper release];
			}
			
			// Starts the listen socket
						
			listenSocket = [[AsyncSocket alloc] initWithDelegate:self];
			[listenSocket setRunLoopModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
		
			NSError *error = nil;
			if(![listenSocket acceptOnPort:PORT error:&error]) {
				NSLog(@"%@", error);
				[self changeStateTo:kNetworkStateError withMessage:@"Error connecting to the remote player. Please try again."];
			}
		
		} else {
		
			// Connects to the server socket
			
			clientSocket = [[AsyncSocket alloc] initWithDelegate:self];
			[clientSocket setRunLoopModes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
		
			NSError *error = nil;
			if(![clientSocket connectToHost:message onPort:PORT withTimeout:5 error:&error]) {
				NSLog(@"%@", error);
				[self changeStateTo:kNetworkStateError withMessage:@"Error connecting to the remote player. Please try again."];
			}
		}
	}
}

-(void) disconnect {
	if (self.gkMatch != nil) {
		[gkMatch disconnect];
	} else {
		if (clientSocket != nil) {
			[clientSocket disconnectAfterWriting];
			[clientSocket release];
			clientSocket = nil;
		}
		
		if (listenSocket != nil) {
			[listenSocket disconnectAfterWriting];
			[listenSocket release];
			listenSocket = nil;
			[mapper close];
			[mapper release];
		}
	}
	
	state = kNetworkStateDisconnected;
}

-(void) sendCommand:(NetworkCommand *)cmd {
	
	// Wraps the command in a string, and then converts it to NSData
	
	[lastCommandSent release];
	lastCommandSent = [cmd retain];
	NSString* strCmd = [cmd toSend];
	NSData *data = [strCmd dataUsingEncoding:NSUTF8StringEncoding];
	
	if (self.gkMatch == nil) {
		[clientSocket writeData:data withTimeout:5 tag:0];
	} else {
		NSError *error;
		[gkMatch sendDataToAllPlayers:data withDataMode:GKMatchSendDataReliable error:&error];
	}
	
	[self changeStateTo:kNetworkStateCommandSent withMessage:[cmd toSend]];
	[strCmd release];
}

-(BOOL) isConnected {
	return connected;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [responseData setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	[self changeStateTo:kNetworkStateError withMessage:@"Error connecting to the match server"];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	NSString* msg = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
	[responseData release];
	[self changeStateTo:kNetworkStateWaitingForConnection withMessage:msg];
}

- (void)onSocket:(AsyncSocket *)sock didAcceptNewSocket:(AsyncSocket *)newSocket
{
	clientSocket = [newSocket retain];
}

- (void)onSocket:(AsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{	
	[sock readDataToData:[AsyncSocket CRLFData] withTimeout:25 tag:0];
	connected = YES;
	if (server) {
		[self changeStateTo:kNetworkStateConnectedAsServer withMessage:nil];
	} else {
		[self changeStateTo:kNetworkStateConnectedAsClient withMessage:nil];
	}
}

- (void)onSocket:(AsyncSocket *)sock didWriteDataWithTag:(long)tag
{
	[sock readDataToData:[AsyncSocket CRLFData] withTimeout:25 tag:0];
}

- (void)onSocket:(AsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
	NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length] - 2)];
	NSString *msg = [[[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding] autorelease];
	NSLog(@"%@\n", msg);
	NetworkCommand* cmd = [NetworkCommand parse:msg];
	[self changeStateTo:kNetworkStateCommandReceived withMessage:msg];
	[delegate onCommandReceived:cmd];
	[cmd release];
	[sock readDataToData:[AsyncSocket CRLFData] withTimeout:25 tag:0];
}

- (void)onSocket:(AsyncSocket *)sock willDisconnectWithError:(NSError *)err
{
	if (state != kNetworkStateError) {
		[self changeStateTo:kNetworkStateError withMessage:@"Error connecting to the remote player. Please try again."];
	}
	connected = NO;
}

- (void)onSocketDidDisconnect:(AsyncSocket *)sock
{
	if (state != kNetworkStateError) {
		[self changeStateTo:kNetworkStateError withMessage:@"Error connecting to the remote player. Please try again."];
	}
	connected = NO;
}

- (void)match:(GKMatch *)match player:(NSString *)playerID didChangeState:(GKPlayerConnectionState)st {
	if (st == GKPlayerStateDisconnected) {
		
		if (state != kNetworkStateError) {
			[self changeStateTo:kNetworkStateError withMessage:@"Error connecting to the remote player. Please try again."];
		}
		connected = NO;
		
	} else if (st == GKPlayerStateConnected && match.expectedPlayerCount == 0) {
		
		connected = YES;
		[self changeStateTo:kNetworkStateConnectedGameCenter withMessage:nil];
	}
}

- (void)match:(GKMatch *)match didFailWithError:(NSError *)error {
	if (state != kNetworkStateError) {
		[self changeStateTo:kNetworkStateError withMessage:@"Error connecting to the remote player. Please try again."];
	}
	connected = NO;
}

- (void)match:(GKMatch *)match connectionWithPlayerFailed:(NSString *)playerID withError:(NSError *)error {
	if (state != kNetworkStateError) {
		[self changeStateTo:kNetworkStateError withMessage:@"Error connecting to the remote player. Please try again."];
	}
	connected = NO;	
}

- (void)match:(GKMatch *)match didReceiveData:(NSData *)data fromPlayer:(NSString *)playerID {
	NSData *strData = [data subdataWithRange:NSMakeRange(0, [data length] - 2)];
	NSString *msg = [[[NSString alloc] initWithData:strData encoding:NSUTF8StringEncoding] autorelease];
	NSLog(@"%@\n", msg);
	NetworkCommand* cmd = [NetworkCommand parse:msg];
	[self changeStateTo:kNetworkStateCommandReceived withMessage:msg];
	[delegate onCommandReceived:cmd];
	[cmd release];
}


@end
