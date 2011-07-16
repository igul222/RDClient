//
//  ConnectionViewController.h
//  RDClient
//
//  Created by Ishaan Gulrajani on 7/5/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "GCDAsyncSocket.h"

@class ScreenView;
@interface ConnectionViewController : UIViewController <GCDAsyncSocketDelegate> {
    GCDAsyncSocket *socket;
    dispatch_queue_t dispatchQueue;
    NSTimeInterval lastMessage;
}
@property(nonatomic, retain) ScreenView *screenView;

-(void)sendMessage:(NSString *)message;
-(void)connectToServer:(NSString *)serverIP;
-(void)sendNoop;
@end
