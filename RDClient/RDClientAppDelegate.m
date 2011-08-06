//
//  RDClientAppDelegate.m
//  RDClient
//
//  Created by Ishaan Gulrajani on 7/5/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "RDClientAppDelegate.h"
#import "ConnectionViewController.h"
@implementation RDClientAppDelegate
@synthesize window, connectionViewController;

#pragma mark - Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.connectionViewController = [[[ConnectionViewController alloc] init] autorelease];
    [connectionViewController connectToServer:@"127.0.0.1"];
    
    [window addSubview:connectionViewController.view];
    [window makeKeyAndVisible];
    return YES;
}

-(void)dealloc {
    self.connectionViewController = nil;
    self.window = nil;
    [super dealloc];
}

@end
