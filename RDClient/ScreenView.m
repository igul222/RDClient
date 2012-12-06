//
//  ScreenView.m
//  RDClient
//
//  Created by Ishaan Gulrajani on 7/5/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "ScreenView.h"

@interface ScreenView ()
-(void)updateRectScalingFactors;
-(CGRect)translateRemoteRectToLocalRect:(CGRect)remote;
-(void)handleMemoryWarning:(NSNotification *)notification;
@end

@implementation ScreenView

#pragma mark - Init and dealloc

-(id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if(self) {
        unusedLayers = [[NSMutableArray alloc] init];
        backgroundLayer = [[CALayer alloc] init];
        backgroundLayer.frame = self.bounds;
        [self.layer addSublayer:backgroundLayer];
        
        actions = [[NSDictionary alloc] initWithObjectsAndKeys:
                                        [NSNull null], @"sublayers",
                                        [NSNull null], @"contents",
                                        [NSNull null], @"onOrderOut",
                                        [NSNull null], @"onOrderIn",
                                        [NSNull null], @"bounds",
                                        [NSNull null], @"position",
                                        [NSNull null], @"opacity",
                                        nil];
        self.layer.actions = actions;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMemoryWarning:) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    }
    return self;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [unusedLayers release];
    [actions release];
    
    [super dealloc];
}

#pragma mark - Blitting updates

-(void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    [self updateRectScalingFactors];
    backgroundLayer.frame = self.bounds;
}

-(void)setRemoteResolution:(CGSize)remote {
    remoteResolution = remote;
    [self updateRectScalingFactors];
}

-(void)updateRectScalingFactors {
    CGRect local = self.frame;
    CGFloat hScale = local.size.width / remoteResolution.width;
    CGFloat vScale = local.size.height / remoteResolution.height;
    scale = MIN(hScale, vScale);
    CGFloat hSize = remoteResolution.width * scale;
    CGFloat vSize = remoteResolution.height * scale;
    hOffset = (local.size.width - hSize) / 2.0;
    vOffset = (local.size.height - vSize) / 2.0;
}

-(CGRect)translateRemoteRectToLocalRect:(CGRect)remote {
    
    remote.size.width = remote.size.width * scale;
    remote.size.height = remote.size.height * scale;
    remote.origin.x = (remote.origin.x * scale) + hOffset;
    
    remote.origin.y = self.frame.size.height - (remote.origin.y * scale) - vOffset - remote.size.height;
    
    return remote;
}

-(void)updateRect:(CGRect)rect withImage:(CGImageRef)updateImage callbackDelegate:(id)delegate { 
    CGImageRetain(updateImage);
    dispatch_async(dispatch_get_main_queue(), ^{
        
        updateCount++;
        if(updateCount > 250) {
            updateCount = 0;
            [self compactUpdates];
        }
        
        CALayer *sublayer;
        if([unusedLayers count] > 0) {
            sublayer = [[unusedLayers objectAtIndex:0] retain];
            [unusedLayers removeObjectAtIndex:0];
        } else {
            sublayer = [[CALayer alloc] init];
            sublayer.actions = actions;
        }
        
        sublayer.frame = [self translateRemoteRectToLocalRect:rect];
        sublayer.contents = (id)updateImage;
        sublayer.opacity = 1;
        
        [self.layer addSublayer:sublayer];
        
        [delegate performSelector:@selector(rectRenderFinished)]; 

        [sublayer release];
        CGImageRelease(updateImage);
    });    
}

#pragma mark - Compacting updates

// this is to be run on the *main thread only*
-(void)compactUpdates {
    NSLog(@"compacting...");
    
    UIGraphicsBeginImageContext(self.frame.size);
    [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    backgroundLayer.contents = (id)[screenshot CGImage];
    
    NSArray *sublayers = [self.layer.sublayers copy];
    for(CALayer *sublayer in sublayers) {
        if(sublayer == backgroundLayer)
            continue;
        sublayer.frame = CGRectZero;
        sublayer.contents = nil;
        sublayer.opacity = 0;
        [unusedLayers addObject:sublayer];
    }
    [sublayers release];
}

-(void)handleMemoryWarning:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self compactUpdates];
    });
}

@end
