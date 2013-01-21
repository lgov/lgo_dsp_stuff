//
//  tesseract.m
//  dsptest1
//
//  Created by Lieven Govaerts on 14/04/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "tessocr.h"
#include "util.h"

@implementation tessocr

- (char*)run_tesseract:(const conn_box_t *)box;
{
    int width = box->xmax - box->xmin + 1;
    int height = box->ymax - box->ymin + 1;

    dsptest_log(LOG_OCR, __FILE__,
                "Pass image in bounding box (%d,%d)-(%d,%d) to TesseractRect.\n",
                box->xmin, box->ymin, box->xmin+width, box->ymin+height);

	// this could take a while. maybe needs to happen asynchronously.
	char* text = tess->TesseractRect(box->img, 1, width,
									 0, 0, width, height);

	return text;
}

-(id)init
{
    if (self = [super init]) {
		NSString* dataPath = [[[NSBundle bundleForClass:[tessocr class]] bundlePath] stringByAppendingString:@"/Contents/Resources/"];
//		NSString* dataPath = @"/Users/lgo/macdev/tesseract-ocr/tessdata";
//		NSString *dataPathWithSlash = [dataPath stringByAppendingString:@"/"];
		const char* dataPathDirectoryCString = [dataPath cStringUsingEncoding:NSUTF8StringEncoding];
		setenv("TESSDATA_PREFIX", dataPathDirectoryCString, 1);

//		setenv("TESSDATA_PREFIX", [dataPathWithSlash UTF8String], 1);

		// init the tesseract engine.
		tess = new TessBaseAPI();

		tess->Init(dataPathDirectoryCString, "eng");

    }
    return self;
}

-(void)dealloc
{
	tess->End();

    [super dealloc];
}
@end
