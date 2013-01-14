//
//  tesseract.h
//  dsptest1
//
//  Created by Lieven Govaerts on 14/04/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "baseapi.h"
#import "util.h"

using namespace tesseract;

@interface tessocr : NSObject {
	TessBaseAPI* tess;
}
- (char*)run_tesseract:(const conn_box_t*)box;

-(id)init;
-(void)dealloc;

@end
