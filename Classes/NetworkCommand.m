//
//  NetworkCommand.m
//  Multiplayer Sample
//
//  Created by Fabio Rodella on 7/20/10.
//  Copyright 2010 Crocodella Software. All rights reserved.
//

#import "NetworkCommand.h"

@implementation NetworkCommand

@synthesize type;
@synthesize param;

+ (NetworkCommand*)parse:(NSString*)cmdStr {
	NSArray* parts = [cmdStr componentsSeparatedByString:@","];
	
	NSString* strType = [parts objectAtIndex:0];
	
	NetworkCommandType tp = kNetworkCommandTypeMove;
	
	if ([strType isEqualToString:@"MV"]) {
		tp = kNetworkCommandTypeMove;
	} else if ([strType isEqualToString:@"NM"]) {
		tp = kNetworkCommandTypeName;
	}
	
	NSString* strParam = [parts objectAtIndex:1];
	
	NetworkCommand* ret = [[NetworkCommand alloc] initWithType:tp andParam:strParam];
	return ret;
}

- (id)initWithType:(NetworkCommandType)cmdType andParam:(NSString *)prm {
	if ((self = [super init])) {
		type = cmdType;
		param = [prm retain];
	}
	return self;	
}

- (NSString*)toSend {
	NSString* strType = nil;
	if (type == kNetworkCommandTypeMove) {
		strType = @"MV";
	} else if (type == kNetworkCommandTypeName) {
		strType = @"NM";
	}
	
	// The line feed and carriage return are added so this could be tested
	// with Telnet, it may not be necessary depending on your "protocol"
	
	return [[NSString alloc] initWithFormat:@"%@,%@\r\n", strType, param];
}

@end
