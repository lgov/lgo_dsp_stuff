//
//  tesseract.h
//  dsptest1
//
//  Created by Lieven Govaerts on 14/04/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "baseapi.h"

using namespace tesseract;

@interface tessocr : NSObject {
	TessBaseAPI* tess;
}
- (char*)run_tesseract:(const unsigned char*)imagedata
	   bytes_per_pixel:(int)bytes_per_pixel
		bytes_per_line:(int)bytes_per_line
				  left:(int)left
				   top:(int)top
				 width:(int)width
				height:(int)height;

-(id)init;
-(void)dealloc;

@end
