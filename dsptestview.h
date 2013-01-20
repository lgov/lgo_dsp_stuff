//
//  dsptestview.h
//  dsptest1
//
//  Created by Lieven Govaerts on 08/02/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MyNSImageView.h"

@interface dsptestview : NSObject {
	IBOutlet MyNSImageView* imageView;
	IBOutlet NSTextField* lbl;
	NSImage* inImage;
	NSBitmapImageRep* inImageRep;

	unsigned char* inputImgBytes;
}

- (IBAction)connComps:(id)sender;
- (IBAction)edgeDetection:(id)sender;
- (IBAction)groupBoundingBoxes:(id)sender;
- (IBAction)binarization:(id)sender;
- (IBAction)ocr:(id)sender;
- (NSBitmapImageRep *)rotate:(NSImage *)image
                       width:(int)width
                      height:(int)height
                       angle:(double)angle
                    imageRep:(NSBitmapImageRep *)imageRep;

@end
