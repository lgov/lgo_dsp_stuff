//
//  OcrTest.m
//  OcrTest
//
//  Created by Lieven Govaerts on 20/12/12.
//
//

#import "OcrTest.h"
#import "recognizer.h"

#include "graphics.h"
#include "util.h"

@implementation OcrTest

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

static unsigned char *
load_imagedata(NSString *imageName, int *img_width, int *img_height)
{
	NSData* fileData = [NSData dataWithContentsOfFile:imageName];
	NSBitmapImageRep *inImageRep = [NSBitmapImageRep
                                    imageRepWithData:fileData];
    
    if (inImageRep == nil) {
        *img_width = 0;
        *img_height = 0;
        return NULL;
    }
    
    /* Load image file content in memory */
    NSImage* inImage = [[NSImage alloc] init];
    [inImage addRepresentation:inImageRep];

    int bitsPerPixel  = (int)[inImageRep bitsPerPixel];
	int width = (int)[inImageRep pixelsWide];
	int height = (int)[inImageRep pixelsHigh];
    unsigned char* inputImgBytes = [inImageRep bitmapData];
    unsigned char* lumin = (unsigned char*)malloc(width * height * sizeof(unsigned char));
	rgb_convert_to_lum(inputImgBytes, lumin, width, height, bitsPerPixel);

    *img_width = width;
    *img_height = height;
    return lumin;
}

- (void) testA_blackOnWhite
{
    recognizer* r = [[[recognizer alloc] init] autorelease];
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/A_bonw.jpg";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/frits_and_freddy.jpg";
    int width, height;
    
    unsigned char *lumin = load_imagedata(imageName, &width, &height);

    NSArray *names = [r recognize:lumin
                            width:width
                           height:height];
    for (NSString *name in names)
    {
        dsptest_log(LOG_OCR, __FILE__, "found line: %s\n", [name UTF8String]);
    }
}

@end
