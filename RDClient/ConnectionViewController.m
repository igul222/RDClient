//
//  ConnectionViewController.m
//  RDClient
//
//  Created by Ishaan Gulrajani on 7/5/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ConnectionViewController.h"
#import "AppUtils.h"
#import "ScreenView.h"
#import "GCDAsyncSocket.h"

#define PORT 51617

#define EOF_STR @"@@@"
#define EOF_DATA [EOF_STR dataUsingEncoding:NSUTF8StringEncoding]
#define DEFAULT_TAG 0

#define NOOP_MSG @"NOOP"
#define AUTHENTICATION_REQUEST_MSG @"AREQ"
#define AUTHENTICATE_MSG @"AUTH"
#define RESOLUTION_REQUEST_MSG @"RREQ"
#define SET_RESOLUTION_MSG @"SRES"
#define CURRENT_RESOLUTION_MSG @"RESN"
#define SCREEN_MSG @"SCRN"

@implementation ConnectionViewController
@synthesize screenView;

#pragma mark - Init and memory management

-(id)init {
    self = [super init];
    if(self) {
        screenView = [[ScreenView alloc] initWithFrame:CGRectZero];
        dispatchQueue = dispatch_queue_create("com.lateralcommunications.gcdclient-connectionviewcontroller", NULL);
    }
    return self;
}

-(void)dealloc {
    self.screenView = nil;
    socket.delegate = nil;
    [socket release];
    [super dealloc];
}

-(void)viewDidUnload {
    [super viewDidUnload];
}

#pragma mark - View controller methods

-(void)viewDidLoad {
    screenView.frame = [self.view bounds];
    [self.view addSubview:screenView];
    [super viewDidLoad];
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

#pragma mark - Connection management

-(void)connectToServer:(NSString *)serverIP {
    if(socket != nil) {
        NSError *error = [NSError errorWithDomain:@"ConnectionViewController" code:1 userInfo:[NSDictionary dictionaryWithObject:@"Already connected" forKey:@"message"]];
        [AppUtils handleError:error context:@"connectToServer:"];
        return;
    }
    
    socket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatchQueue];
    
    NSError *error = nil;
    [socket connectToHost:serverIP onPort:PORT error:&error];
    if(error != nil) {
        [AppUtils handleError:error context:@"connectToServer:"];
        return;
    }
    
    [AppUtils log:FORMAT(@"Connecting to %@...",serverIP)];
}

-(void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port {
    [AppUtils log:@"Connected!"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self performSelector:@selector(sendNoop) withObject:nil afterDelay:0.1];
    });
    
    [socket readDataToData:EOF_DATA withTimeout:TIMEOUT tag:DEFAULT_TAG];
}

// send a control message over the line
-(void)sendMessage:(NSString *)message {
    if(!socket || ![socket isConnected])
        return;

    NSString *messageStr = FORMAT(@"%@%@", message,EOF_STR);
    NSData *messageData = [messageStr dataUsingEncoding:NSUTF8StringEncoding];
    
    [socket writeData:messageData withTimeout:TIMEOUT tag:DEFAULT_TAG];
}

-(void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag {
    lastMessage = [[NSDate date] timeIntervalSince1970];
    
    NSString *dataStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *messageCode = [dataStr substringWithRange:NSMakeRange(0, 4)];
    
    if([messageCode isEqualToString:AUTHENTICATION_REQUEST_MSG]) {
        NSString *msgStr = FORMAT(@"%@%@%@", AUTHENTICATE_MSG, PASSWORD, EOF_STR);
        [socket writeData:[msgStr dataUsingEncoding:NSUTF8StringEncoding] 
              withTimeout:TIMEOUT 
                      tag:DEFAULT_TAG];
    } else if([messageCode isEqualToString:RESOLUTION_REQUEST_MSG]) {
        int width, height;
        if(IPAD) {
            width = 1920;
            height = 1200;
        } else {
            width = 1920;
            height = 1200;
        }
        NSString *msgStr = FORMAT(@"%@%04d%04d%@", SET_RESOLUTION_MSG, width, height, EOF_STR);
        [socket writeData:[msgStr dataUsingEncoding:NSUTF8StringEncoding] 
              withTimeout:TIMEOUT 
                      tag:DEFAULT_TAG];
    }
    
    [socket readDataToData:EOF_DATA withTimeout:TIMEOUT tag:DEFAULT_TAG];
}

#pragma mark - Handling timeouts

-(NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length {
    return (10.0 + lastMessage - [[NSDate date] timeIntervalSince1970]);
}

-(NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag elapsed:(NSTimeInterval)elapsed bytesDone:(NSUInteger)length {
    return (10.0 + lastMessage - [[NSDate date] timeIntervalSince1970]);
}

-(void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err {
    if(err)
        [AppUtils handleNonFatalError:err context:@"socketDidDisconnect:"];
    
    socket.delegate = nil;
    [socket release];
    socket = nil;
}

-(void)sendNoop {
    dispatch_async(dispatchQueue, ^{
        if(socket && [socket isConnected]) {
            [self sendMessage:NOOP_MSG];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self performSelector:@selector(sendNoop) withObject:nil afterDelay:5.0];
            });
        }
    });
}

@end
