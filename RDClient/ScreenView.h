//
//  ScreenView.h
//  RDClient
//
//  Created by Ishaan Gulrajani on 7/5/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface ScreenView : UIView {
    CGSize remoteResolution;
    CGFloat scale;
    CGFloat hOffset;
    CGFloat vOffset;
    
    int updateCount;
    NSMutableArray *unusedLayers;
    CALayer *backgroundLayer;
    
    NSDictionary *actions;
}

// blitting updates
-(void)setRemoteResolution:(CGSize)remote;
-(void)updateRect:(CGRect)rect withImage:(CGImageRef)image callbackDelegate:(id)delegate;

// compacting updates
-(void)compactUpdates;

@end
