//
//  MyNSImageView.m
//  dsptest1
//
//  Created by Lieven Govaerts on 19/05/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MyNSImageView.h"

@implementation MyNSImageView
- (void)drawRect:(NSRect)dirtyRect {
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationNone];
    
    [super drawRect:dirtyRect];
}
@end