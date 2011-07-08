//
//  NetworkCommand.h
//  Multiplayer Sample
//
//  Created by Fabio Rodella on 7/20/10.
//  Copyright 2010 Crocodella Software. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum tagNetworkCommandType {
	kNetworkCommandTypeName,
	kNetworkCommandTypeMove
} NetworkCommandType;

@interface NetworkCommand : NSObject {
	NetworkCommandType type;
	NSString* param;
}

+ (NetworkCommand*)parse:(NSString*)cmdStr;

- (id)initWithType:(NetworkCommandType) cmdType andParam:(NSString*)prm;

- (NSString*)toSend;

@property (readwrite,assign) NetworkCommandType type;
@property (readwrite,retain) NSString* param;

@end
