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
	NSBitmapImageRep* inImageRep;

	unsigned char* inputImgBytes;
	unsigned char* outputImgBytes;
	unsigned char* outputImg2Bytes;
}

- (IBAction)calcConnCons:(id)sender;
- (IBAction)calcEdges:(id)sender;
- (IBAction)prepare:(id)sender;
- (IBAction)loadImage:(id)sender;

@end
