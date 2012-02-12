//
//  dsptestview.h
//  dsptest1
//
//  Created by Lieven Govaerts on 08/02/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface dsptestview : NSObject {
	IBOutlet NSImageView* imageView;
	NSImage* image;
	unsigned char* inputImgBytes;
	unsigned char* outputImgBytes;
}

- (IBAction)calcSpectrum:(id)sender;
- (IBAction)calcEdge:(id)sender;
- (IBAction)loadImage:(id)sender;

@end
