//
//  dsptestview.m
//  dsptest1
//
//  Created by Lieven Govaerts on 08/02/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "dsptestview.h"
#import "tessocr.h"
#include <stdlib.h>
#include <math.h>
#include "util.h"
#include "graphics.h"

@implementation dsptestview

void draw_bounding_boxes(unsigned char *outptr, NSArray* lines,
                         int width, int height, int bitsPerPixel)
{
    for(NSArray* list in lines) {
        NSValue* bbval = [list objectAtIndex:0];
        conn_box_t box;
        [bbval getValue:&box];

		// TODO: cleanup all compranges in the set.

		// draw a blue bounding box
		for (int x = box.xmin; x < box.xmax; x++) {
			int xloc = x * bitsPerPixel / 8;
			// top
			int yloc = box.ymin * width * bitsPerPixel / 8;
			*(outptr + xloc + yloc) = 255;
			*(outptr + xloc + yloc + 1) = 0;
			*(outptr + xloc + yloc + 2) = 0;
			// bottom
			yloc = box.ymax * width * bitsPerPixel / 8;
			*(outptr + xloc + yloc) = 255;
			*(outptr + xloc + yloc + 1) = 0;
			*(outptr + xloc + yloc + 2) = 0;
		}

		for (int y = box.ymin; y < box.ymax; y++) {
			int yloc = y * width * bitsPerPixel / 8;

			int xloc = box.xmin * bitsPerPixel / 8;
			*(outptr + xloc + yloc) = 255;
			*(outptr + xloc + yloc + 1) = 0;
			*(outptr + xloc + yloc + 2) = 0;

			xloc = box.xmax * bitsPerPixel / 8;
			*(outptr + xloc + yloc) = 255;
			*(outptr + xloc + yloc + 1) = 0;
			*(outptr + xloc + yloc + 2) = 0;
		}
	}
}

- (void) awakeFromNib
{
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/replica_state_license_plate.gif";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/P1180863.JPG";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/P1180863_topcorner.JPG";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/iphone-prime.png";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/test_small.jpg";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/P1180863_lessbright.JPG";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/el_secreto_de_sus_ojos.JPG";
//	 NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/agent_cody_banks.JPG";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/IMG_0002_treshold.JPG";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/radio days.jpg";
//	NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/frits_and_freddy.jpg";
//  NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/a_single_man.jpg";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/canny_test.jpg";
	NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/A_bonw.jpg";

	NSData* fileData = [NSData dataWithContentsOfFile:imageName];
	inImageRep = [NSBitmapImageRep
				  imageRepWithData:fileData];
	if (inImageRep){
		NSImage* inImage = [[NSImage alloc] init];
		[inImage addRepresentation:inImageRep];

		inputImgBytes = [inImageRep bitmapData];

		[imageView setImage:inImage];
	}
}

NSBitmapImageRep *cloneImageRep(NSBitmapImageRep* inImageRep)
{
	return [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes:NULL
            pixelsWide:[inImageRep pixelsWide]
            pixelsHigh:[inImageRep pixelsHigh]
            bitsPerSample:[inImageRep bitsPerSample]
            samplesPerPixel:[inImageRep samplesPerPixel]
            hasAlpha:[inImageRep hasAlpha]
            isPlanar:[inImageRep isPlanar]
            colorSpaceName:[inImageRep colorSpaceName]
            bytesPerRow:[inImageRep bytesPerRow]
            bitsPerPixel:[inImageRep bitsPerPixel]];
}

- (IBAction)edgeDetection:(id)sender
{
	int bitsPerPixel  = [inImageRep bitsPerPixel];
	int width = [inImageRep pixelsWide];
	int height = [inImageRep pixelsHigh];
    unsigned char* lumin = (unsigned char*)malloc(width * height * sizeof(unsigned char));
	unsigned char* lumbuf = (unsigned char*)malloc(width * height * sizeof(unsigned char));
    unsigned char* lum_edge = (unsigned char*)malloc(width * height * sizeof(unsigned char));

	NSBitmapImageRep *outImageRep = cloneImageRep(inImageRep);
	NSImage* outImage = [[[NSImage alloc] init] autorelease];
	[outImage addRepresentation:outImageRep];
	outputImgBytes = [outImageRep bitmapData];

    /*** Step 1: Edge detection ***/
	rgb_convert_to_lum(inputImgBytes, lumin, width, height, bitsPerPixel);
    canny_edge_detection(lumin, outputImgBytes, width, height, bitsPerPixel);
//    gaussian_blur(lumin, lumbuf, width, height);
//    sobel_edge_detection(lumbuf, lum_edge, width, height);

    /* Finished */
	[imageView setImage:outImage];

    free(lumin);
    free(lum_edge);
    free(lumbuf);
}

- (IBAction)connComps:(id)sender
{
	int bitsPerPixel  = [inImageRep bitsPerPixel];
	int width = [inImageRep pixelsWide];
	int height = [inImageRep pixelsHigh];
    unsigned char* lumin = (unsigned char*)malloc(width * height * sizeof(unsigned char));
	unsigned char* lum_edge = (unsigned char*)malloc(width * height * sizeof(unsigned char));

	NSBitmapImageRep *outImageRep = cloneImageRep(inImageRep);
	NSImage* outImage = [[[NSImage alloc] init] autorelease];
	[outImage addRepresentation:outImageRep];
	outputImgBytes = [outImageRep bitmapData];

    /*** Step 1: Edge detection ***/
    rgb_convert_to_lum(inputImgBytes, lumin, width, height, bitsPerPixel);
    canny_edge_detection(lumin, outputImgBytes, width, height, bitsPerPixel);

    /*** Step 2: Get small Bounding Boxes ***/
    // canny returns only 4 colors + black =-> any color > 0 should be white.
	rgb_convert_canny_to_code(outputImgBytes, lum_edge, width, height, bitsPerPixel);
    NSArray *conn_lines = connected_binary(lum_edge, width, height);
    
    dsptest_log(LOG_BB, __FILE__, "Log connected components\n");
    dsptest_log(LOG_BB, __FILE__, "===========================================\n");
    log_bounding_boxes(conn_lines);
    dsptest_log(LOG_BB, __FILE__, "===========================================\n");

    // draw bounding boxes on screen.
//    lum_convert_to_rgb(lum_edge, outputImgBytes, width, height, bitsPerPixel);
    draw_bounding_boxes(outputImgBytes, conn_lines, width, height, bitsPerPixel);

    /* Finished */
	[imageView setImage:outImage];
    free(lumin);
    free(lum_edge);
}

- (IBAction)groupBoundingBoxes:(id)sender
{
    int bitsPerPixel  = [inImageRep bitsPerPixel];
	int width = [inImageRep pixelsWide];
	int height = [inImageRep pixelsHigh];
    unsigned char* lumin = (unsigned char*)malloc(width * height * sizeof(unsigned char));
	unsigned char* lum_edge = (unsigned char*)malloc(width * height * sizeof(unsigned char));

	NSBitmapImageRep *outImageRep = cloneImageRep(inImageRep);
	NSImage* outImage = [[[NSImage alloc] init] autorelease];
	[outImage addRepresentation:outImageRep];
	outputImgBytes = [outImageRep bitmapData];

    /*** Step 1: Edge detection ***/
    rgb_convert_to_lum(inputImgBytes, lumin, width, height, bitsPerPixel);
    canny_edge_detection(lumin, outputImgBytes, width, height, bitsPerPixel);

    /*** Step 2: Get small Bounding Boxes ***/
    // canny returns only 4 colors + black =-> any color > 0 should be white.
	rgb_convert_canny_to_code(outputImgBytes, lum_edge, width, height, bitsPerPixel);
    NSArray *bounding_boxes = connected_binary(lum_edge, width, height);
    //    NSArray *bounding_boxes = connected_div_and_conq(lum_edge, width, height);

    /*** Step 3: Group bounding boxes ***/
    bounding_boxes = group_bounding_boxes(bounding_boxes, width, height);
    dsptest_log(LOG_BB, __FILE__, "Log grouped connected components\n");
    dsptest_log(LOG_BB, __FILE__, "===========================================\n");
    log_bounding_boxes(bounding_boxes);
    dsptest_log(LOG_BB, __FILE__, "===========================================\n");

    // draw bounding boxes on screen.
//    lum_convert_to_rgb(lum_edge, outputImgBytes, width, height, bitsPerPixel);
    draw_bounding_boxes(outputImgBytes, bounding_boxes, width, height, bitsPerPixel);

    /* Finished */
	[imageView setImage:outImage];
}

- (IBAction)binarization:(id)sender
{
    int bitsPerPixel  = [inImageRep bitsPerPixel];
	int width = [inImageRep pixelsWide];
	int height = [inImageRep pixelsHigh];
    unsigned char* lumin = (unsigned char*)malloc(width * height * sizeof(unsigned char));
	unsigned char* lum_edge = (unsigned char*)malloc(width * height * sizeof(unsigned char));
    unsigned char* lumbuf = (unsigned char*)malloc(width * height * sizeof(unsigned char));

	NSBitmapImageRep *outImageRep = cloneImageRep(inImageRep);
	NSImage* outImage = [[[NSImage alloc] init] autorelease];
	[outImage addRepresentation:outImageRep];
	outputImgBytes = [outImageRep bitmapData];

    /*** Step 1: Edge detection ***/
    rgb_convert_to_lum(inputImgBytes, lumin, width, height, bitsPerPixel);
    canny_edge_detection(lumin, outputImgBytes, width, height, bitsPerPixel);

    /*** Step 2: Get small Bounding Boxes ***/
    // canny returns only 4 colors + black =-> any color > 0 should be white.
	rgb_convert_to_bw_treshold(outputImgBytes, lum_edge, width, height, bitsPerPixel, 1);
    NSArray *bounding_boxes = connected_binary(lum_edge, width, height);
    //    NSArray *bounding_boxes = connected_div_and_conq(lum_edge, width, height);

    /*** Step 3: Group bounding boxes ***/
    bounding_boxes = group_bounding_boxes(bounding_boxes, width, height);

    /*** Step 4: Binarization of interior of bounding boxes ***/
    binarization_bounding_boxes(lumin, lumbuf, bounding_boxes, width, height);
    //    binarization_threshold(lum_edge, lum_edge, 0, 0, width, width, height, 0, 0, width, 1);

    // draw bounding boxes on screen.
    lum_convert_to_rgb(lumbuf, outputImgBytes, width, height, bitsPerPixel);
    draw_bounding_boxes(outputImgBytes, bounding_boxes, width, height, bitsPerPixel);

    /* Finished */
	[imageView setImage:outImage];
}

- (IBAction)ocr:(id)sender
{
	tessocr* ocr = [[tessocr alloc] init];

    int bitsPerPixel  = [inImageRep bitsPerPixel];
	int width = [inImageRep pixelsWide];
	int height = [inImageRep pixelsHigh];
    unsigned char* lumin = (unsigned char*)malloc(width * height * sizeof(unsigned char));
	unsigned char* lum_edge = (unsigned char*)malloc(width * height * sizeof(unsigned char));
    unsigned char* lumbuf = (unsigned char*)malloc(width * height * sizeof(unsigned char));

	NSBitmapImageRep *outImageRep = cloneImageRep(inImageRep);
	NSImage* outImage = [[[NSImage alloc] init] autorelease];
	[outImage addRepresentation:outImageRep];
	outputImgBytes = [outImageRep bitmapData];

    /*** Step 1: Edge detection ***/
    rgb_convert_to_lum(inputImgBytes, lumin, width, height, bitsPerPixel);
    canny_edge_detection(lumin, outputImgBytes, width, height, bitsPerPixel);

    /*** Step 2: Get small Bounding Boxes ***/
    // canny returns only 4 colors + black =-> any color > 0 should be white.
	rgb_convert_to_bw_treshold(outputImgBytes, lum_edge, width, height, bitsPerPixel, 1);
    //    binarization_threshold(lum_edge, lum_edge, 0, 0, width, width, height, 0, 0, width, 1);
    NSArray *bounding_boxes = connected_binary(lum_edge, width, height);
    //    NSArray *bounding_boxes = connected_div_and_conq(lum_edge, width, height);

    /*** Step 3: Group bounding boxes ***/
    bounding_boxes = group_bounding_boxes(bounding_boxes, width, height);

    /*** Step 4: Binarization of interior of bounding boxes ***/
    binarization_bounding_boxes(lumin, lumbuf, bounding_boxes, width, height);

    // draw bounding boxes on screen.
    lum_convert_to_rgb(lumbuf, outputImgBytes, width, height, bitsPerPixel);
    draw_bounding_boxes(outputImgBytes, bounding_boxes, width, height, bitsPerPixel);

	[imageView setImage:outImage];

    /*** Step 5: OCR of binarized bounding boxes ***/
    for(NSArray* list in bounding_boxes) {
        NSValue* bbval = [list objectAtIndex:0];
		conn_box_t bb;
		[bbval getValue:&bb];
		const char* ocr_text =
                    [ocr run_tesseract:lumbuf
						bytes_per_pixel:1
						 bytes_per_line:width
								   left:bb.xmin
									top:bb.ymin
								  width:bb.xmax - bb.xmin
								 height:bb.ymax - bb.ymin
					  ];
        char* text = filter_ocr_string(ocr_text);
        if (text)
            dsptest_log(LOG_OCR, __FILE__, "found line: %s\n", text);
	}
//	NSString *str = [[NSString alloc] initWithUTF8String:text];
//	[lbl setStringValue:str];
}

@end
