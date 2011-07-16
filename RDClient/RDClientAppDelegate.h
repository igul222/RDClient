//
//  RDClientAppDelegate.h
//  RDClient
//
//  Created by Ishaan Gulrajani on 7/5/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class  ConnectionViewController;
@interface RDClientAppDelegate : NSObject <UIApplicationDelegate>

@property(nonatomic, retain) IBOutlet UIWindow *window;
@property(nonatomic, retain) ConnectionViewController *connectionViewController;

@end
