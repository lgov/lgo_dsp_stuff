//
//  tesseract.m
//  dsptest1
//
//  Created by Lieven Govaerts on 14/04/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "tessocr.h"


@implementation tessocr

- (char*)run_tesseract:(const unsigned char*)imagedata
	   bytes_per_pixel:(int)bytes_per_pixel
		bytes_per_line:(int)bytes_per_line
				  left:(int)left
				   top:(int)top
				 width:(int)width
				height:(int)height;
{

	// this could take a while. maybe needs to happen asynchronously.
	char* text = tess->TesseractRect(imagedata,(int)bytes_per_pixel,(int)bytes_per_line,
									 left, top, width, height);

	return text;
}

-(id)init
{
    if (self = [super init]) {
		NSString* dataPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingString:@"/Contents/Resources/"];
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
