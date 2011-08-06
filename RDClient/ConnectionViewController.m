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
#import "ProtocolConstants.h"

#define DEFAULT_TAG 0
#define MESSAGE_CODE_TO_END_RANGE(l) (NSMakeRange(4, (l) - (4+[EOF_STR length])))

static int dataToInt(NSData *data) {
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    int result = [str intValue];
    [str release];
    return result;
}

@implementation ConnectionViewController
@synthesize screenView;

#pragma mark - Init and memory management

-(id)init {
    self = [super init];
    if(self) {
        screenView = [[ScreenView alloc] initWithFrame:CGRectZero];
        dispatchQueue = dispatch_queue_create("com.lateralcommunications.RDClient-ConnectionViewController", NULL);
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
    screenView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
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
    
    NSString *messageCode = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, 4)] encoding:NSUTF8StringEncoding];
    
    if([messageCode isEqualToString:AUTHENTICATION_REQUEST_MSG]) {
        NSString *msgStr = FORMAT(@"%@%@%@", AUTHENTICATE_MSG, PASSWORD, EOF_STR);
        [socket writeData:[msgStr dataUsingEncoding:NSUTF8StringEncoding] 
              withTimeout:TIMEOUT 
                      tag:DEFAULT_TAG];
    
    } else if([messageCode isEqualToString:SCREEN_MSG]) {
        NSData *numberData = [data subdataWithRange:MESSAGE_CODE_TO_END_RANGE([data length])];
        remainingRects = dataToInt(numberData);
    
    } else if([messageCode isEqualToString:CURRENT_RESOLUTION_MSG]) {
    
        NSData *wData = [data subdataWithRange:NSMakeRange(4, 4)];
        NSData *hData = [data subdataWithRange:NSMakeRange(8, 4)];
        int width = [[[[NSString alloc] initWithData:wData encoding:NSUTF8StringEncoding] autorelease] intValue];
        int height = [[[[NSString alloc] initWithData:hData encoding:NSUTF8StringEncoding] autorelease] intValue];

        [screenView setRemoteResolution:CGSizeMake((CGFloat)width, (CGFloat)height)];
        
    } else if([messageCode isEqualToString:SCREEN_RECT_MSG]) {
        
        NSData *xData = [data subdataWithRange:NSMakeRange(4, 4)];
        NSData *yData = [data subdataWithRange:NSMakeRange(8, 4)];
        int x = [[[[NSString alloc] initWithData:xData encoding:NSUTF8StringEncoding] autorelease] intValue];
        int y = [[[[NSString alloc] initWithData:yData encoding:NSUTF8StringEncoding] autorelease] intValue];        
        
        CFDataRef imgData = (CFDataRef)[data subdataWithRange:NSMakeRange(12, [data length]-([EOF_DATA length]+12))];
        CGDataProviderRef imgDataProvider = CGDataProviderCreateWithCFData(imgData);
        
        CGImageRef image = CGImageCreateWithJPEGDataProvider(imgDataProvider, 
                                                     NULL, 
                                                     false, // shouldInterpolate 
                                                     kCGRenderingIntentDefault);
        CGRect rect = CGRectMake((CGFloat)x, (CGFloat)y, (CGFloat)CGImageGetWidth(image), (CGFloat)CGImageGetHeight(image));

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [screenView updateRect:rect withImage:image callbackDelegate:self];
            CGImageRelease(image);
        });
    
        CGDataProviderRelease(imgDataProvider);
    }
    
    [socket readDataToData:EOF_DATA withTimeout:TIMEOUT tag:DEFAULT_TAG];
    [messageCode release];
}

#pragma mark - Handling timeouts

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

#pragma mark -


-(void)rectRenderFinished {
    remainingRects--;
    if(remainingRects == 0) {
        [self sendMessage:ALL_RECTS_RECEIVED_MSG];
    }
}

@end
