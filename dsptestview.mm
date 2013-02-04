//
//  dsptestview.m
//  dsptest1
//
//  Created by Lieven Govaerts on 08/02/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "dsptestview.h"
#import "tessocr.h"
#import "fuzzy_search_db.h"
#import "recognizer.h"

#include <stdlib.h>
#include <math.h>
#include "util.h"
#include "graphics.h"

@implementation dsptestview

static void
draw_bounding_boxes(unsigned char *outptr, const NSArray *comps,
                    int width, int height, int bitsPerPixel)
{
    for(conn_box_t *box in comps)
    {
        if (box->img)
        {
            int boxwidth = box->xmax - box->xmin + 1;
            int boxheight = box->ymax - box->ymin + 1;
            
            /* Copy box image to out image */
            for (int y = 0; y < boxheight; y++) {
                int yloc = (box->ymin + y) * width * bitsPerPixel / 8;
                for (int x = 0; x < boxwidth; x++) {
                    int xloc = (box->xmin + x) * bitsPerPixel / 8;

                    unsigned char *inptr = box->img + y * boxwidth + x;
                    unsigned char *curout = outptr + xloc + yloc;

                    *curout++ = *inptr; // r
                    *curout++ = *inptr; // g
                    *curout++ = *inptr; // b
                    *curout++ = 0;
                }
            }
        }
        
        // draw a red bounding box
		for (int x = box->xmin; x <= box->xmax; x++) {
			int xloc = x * bitsPerPixel / 8;
			// top
			int yloc = box->ymin * width * bitsPerPixel / 8;
			*(outptr + xloc + yloc) = 255;
			*(outptr + xloc + yloc + 1) = 0;
			*(outptr + xloc + yloc + 2) = 0;
			// bottom
			yloc = box->ymax * width * bitsPerPixel / 8;
			*(outptr + xloc + yloc) = 255;
			*(outptr + xloc + yloc + 1) = 0;
			*(outptr + xloc + yloc + 2) = 0;
		}

		for (int y = box->ymin; y <= box->ymax; y++) {
			int yloc = y * width * bitsPerPixel / 8;

			int xloc = box->xmin * bitsPerPixel / 8;
			*(outptr + xloc + yloc) = 255;
			*(outptr + xloc + yloc + 1) = 0;
			*(outptr + xloc + yloc + 2) = 0;

			xloc = box->xmax * bitsPerPixel / 8;
			*(outptr + xloc + yloc) = 255;
			*(outptr + xloc + yloc + 1) = 0;
			*(outptr + xloc + yloc + 2) = 0;
		}


	}
}

- (void) awakeFromNib
{
//	NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/A_wonb.jpg";
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/P1180863-800x600.jpg";
	NSData* fileData = [NSData dataWithContentsOfFile:imageName];
	inImageRep = [NSBitmapImageRep
				  imageRepWithData:fileData];
	if (inImageRep){
		inImage = [[NSImage alloc] init];
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
#if 0
- (IBAction)edgeDetection:(id)sender
{
	int bitsPerPixel  = [inImageRep bitsPerPixel];
	int width = [inImageRep pixelsWide];
	int height = [inImageRep pixelsHigh];
    int avg_slope = 0;
    unsigned char* lumin = (unsigned char*)malloc(width * height * sizeof(unsigned char));
	unsigned char* lumbuf = (unsigned char*)malloc(width * height * sizeof(unsigned char));
    unsigned char* lum_edge = (unsigned char*)malloc(width * height * sizeof(unsigned char));

	NSBitmapImageRep *outImageRep = cloneImageRep(inImageRep);
	NSImage* outImage = [[[NSImage alloc] init] autorelease];
	[outImage addRepresentation:outImageRep];
	outputImgBytes = [outImageRep bitmapData];

    /*** Step 1: Edge detection ***/
	rgb_convert_to_lum(inputImgBytes, lumin, width, height, bitsPerPixel);

    canny_edge_detection(lumin, outputImgBytes, width, height, bitsPerPixel, &avg_slope);
//    sobel_edge_detection(lumbuf, lum_edge, width, height);

    /* Finished */
	[imageView setImage:outImage];

    free(lumin);
    free(lum_edge);
    free(lumbuf);
}
#endif

- (NSBitmapImageRep *)rotate:(NSImage *)image
                       width:(int)width
                      height:(int)height
                       angle:(double)angle
                    imageRep:(NSBitmapImageRep *)imageRep
{
    /**
     * Apply the following transformations:
     *
     * - with the rotation at the left corner (0,0).
     * - rotate it by 90 degrees, either clock or counter clockwise.
     */
    NSSize size = NSMakeSize(width, height);
    NSImage *rotatedImage = [[NSImage alloc] initWithSize:size];
	NSBitmapImageRep *rotatedImageRep = cloneImageRep(imageRep);
    [rotatedImage addRepresentation:rotatedImageRep];

    [rotatedImage lockFocus];

    NSAffineTransform *rotateTF = [NSAffineTransform transform];
    [rotateTF rotateByDegrees:2];
    [rotateTF concat];

    NSRect r1 = NSMakeRect(0, 0, width, height);
    [imageRep drawInRect:r1];

    [rotatedImage unlockFocus];

    return rotatedImageRep;
}


- (IBAction)connComps:(id)sender
{
	int bitsPerPixel  = [inImageRep bitsPerPixel];
	int width = [inImageRep pixelsWide];
	int height = [inImageRep pixelsHigh];
    unsigned char* lumin = (unsigned char*)malloc(width * height * sizeof(unsigned char));
	unsigned char* lum_edge = (unsigned char*)malloc(width * height * sizeof(unsigned char));
    double avg_slope = 0;

	NSBitmapImageRep *outImageRep = cloneImageRep(inImageRep);
	NSImage* outImage = [[[NSImage alloc] init] autorelease];
	[outImage addRepresentation:outImageRep];
    unsigned char* outputImgBytes = [outImageRep bitmapData];

    /*** Step 1: Edge detection ***/
    rgb_convert_to_lum(inputImgBytes, lumin, width, height, bitsPerPixel);
    canny_edge_detection(lumin, outputImgBytes, width, height, bitsPerPixel, &avg_slope);

    /*** Step 2a: if slope, rotate image first ***/
    if (avg_slope > -180)
    {
        rotate(lumin, lum_edge, width, height, avg_slope);
        canny_edge_detection(lum_edge, outputImgBytes, width, height, bitsPerPixel, &avg_slope);
    }

    /*** Step 2: Get small Bounding Boxes ***/
    // canny returns only 4 colors + black =-> any color > 0 should be white.
	rgb_convert_canny_to_code(outputImgBytes, lum_edge, width, height, bitsPerPixel);

    const NSArray *comps = connected_binary(lum_edge, width, height);

    /*** Step 2b: Group into characters ***/
    const int maxCharDeltaX = 2;
    const int maxCharDeltaY= 2;
    comps = group_into_characters(comps, maxCharDeltaX, maxCharDeltaY);

    const int minWidth = 6;
    const int minHeight = 6;
    comps = remove_too_small(comps, minWidth, minHeight);

    dsptest_log(LOG_BB, __FILE__, "Log connected components\n");
    dsptest_log(LOG_BB, __FILE__, "===========================================\n");
    log_bounding_boxes(comps);
    dsptest_log(LOG_BB, __FILE__, "===========================================\n");

    // draw bounding boxes on screen.
//    lum_convert_to_rgb(lum_edge, outputImgBytes, width, height, bitsPerPixel);
    draw_bounding_boxes(outputImgBytes, comps, width, height, bitsPerPixel);
    
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
    double avg_slope = 0;

	NSBitmapImageRep *outImageRep = cloneImageRep(inImageRep);
	NSImage* outImage = [[[NSImage alloc] init] autorelease];
	[outImage addRepresentation:outImageRep];
    unsigned char* outputImgBytes = [outImageRep bitmapData];

    /*** Step 1: Edge detection ***/
    rgb_convert_to_lum(inputImgBytes, lumin, width, height, bitsPerPixel);
    canny_edge_detection(lumin, outputImgBytes, width, height, bitsPerPixel, &avg_slope);

    /*** Step 2a: if slope, rotate image first ***/
    if (avg_slope > -180)
    {
        rotate(lumin, lum_edge, width, height, avg_slope);
        canny_edge_detection(lum_edge, outputImgBytes, width, height, bitsPerPixel, &avg_slope);
    }

    /*** Step 2: Get small Bounding Boxes ***/
    // canny returns only 4 colors + black =-> any color > 0 should be white.
	rgb_convert_canny_to_code(outputImgBytes, lum_edge, width, height, bitsPerPixel);

    NSArray *bounding_boxes = connected_binary(lum_edge, width, height);
    //    NSArray *bounding_boxes = connected_div_and_conq(lum_edge, width, height);

    /*** Step 3: Group bounding boxes ***/
    bounding_boxes = group_into_lines(bounding_boxes, width, height);
    
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
    double avg_slope = 0;

	NSBitmapImageRep *outImageRep = cloneImageRep(inImageRep);
	NSImage* outImage = [[[NSImage alloc] init] autorelease];
	[outImage addRepresentation:outImageRep];
	unsigned char *outputImgBytes = [outImageRep bitmapData];

    /*** Step 1: Edge detection ***/
    rgb_convert_to_lum(inputImgBytes, lumin, width, height, bitsPerPixel);
    canny_edge_detection(lumin, outputImgBytes, width, height, bitsPerPixel, &avg_slope);

    /*** Step 2a: if slope, rotate image first ***/
    if (avg_slope > -180)
    {
        rotate(lumin, lum_edge, width, height, avg_slope);
        canny_edge_detection(lum_edge, outputImgBytes, width, height, bitsPerPixel, &avg_slope);
    }

    /*** Step 2: Get small Bounding Boxes ***/
    // canny returns only 4 colors + black =-> any color > 0 should be white.
	rgb_convert_to_bw_treshold(outputImgBytes, lum_edge, width, height, bitsPerPixel, 1);
    NSArray *bounding_boxes = connected_binary(lum_edge, width, height);
    //    NSArray *bounding_boxes = connected_div_and_conq(lum_edge, width, height);

    /*** Step 3: Group bounding boxes ***/
    bounding_boxes = group_into_lines(bounding_boxes, width, height);

    /*** Step 4: Binarization of interior of bounding boxes ***/
    binarization_bounding_boxes(lumin, bounding_boxes, width, height);
    //    binarization_threshold(lum_edge, lum_edge, 0, 0, width, width, height, 0, 0, width, 1);

    make_boxes_black_on_white_bg(bounding_boxes);

    // draw bounding boxes on screen.
    lum_convert_to_rgb(lumbuf, outputImgBytes, width, height, bitsPerPixel);
    draw_bounding_boxes(outputImgBytes, bounding_boxes, width, height, bitsPerPixel);

    /* Finished */
	[imageView setImage:outImage];
}

- (IBAction)ocr:(id)sender
{
	tessocr *ocr = [[tessocr alloc] init];
    recognizer *rec = [[recognizer alloc] init];

    int bitsPerPixel  = [inImageRep bitsPerPixel];
	int width = [inImageRep pixelsWide];
	int height = [inImageRep pixelsHigh];
    unsigned char* lumin = (unsigned char*)malloc(width * height * sizeof(unsigned char));
	unsigned char* lum_edge = (unsigned char*)malloc(width * height * sizeof(unsigned char));
    double avg_slope = 0;
    
	NSBitmapImageRep *outImageRep = cloneImageRep(inImageRep);
	NSImage* outImage = [[[NSImage alloc] init] autorelease];
	[outImage addRepresentation:outImageRep];
	unsigned char *outputImgBytes = [outImageRep bitmapData];

    /*** Step 1: Edge detection ***/
    rgb_convert_to_lum(inputImgBytes, lumin, width, height, bitsPerPixel);
    canny_edge_detection(lumin, outputImgBytes, width, height, bitsPerPixel, &avg_slope);

    /*** Step 2a: if slope, rotate image first ***/
    if (avg_slope > -180)
    {
        unsigned char* lumbuf = (unsigned char*)malloc(width * height * sizeof(unsigned char));

        rotate(lumin, lumbuf, width, height, avg_slope);
        canny_edge_detection(lumbuf, outputImgBytes, width, height, bitsPerPixel, &avg_slope);
        free(lumin);
        lumin = lumbuf;
    }

    /*** Step 2: Get small Bounding Boxes ***/
    // canny returns only 4 colors + black =-> any color > 0 should be white.
	rgb_convert_to_bw_treshold(outputImgBytes, lum_edge, width, height, bitsPerPixel, 1);
    //    binarization_threshold(lum_edge, lum_edge, 0, 0, width, width, height, 0, 0, width, 1);
    NSArray *bounding_boxes = connected_binary(lum_edge, width, height);
    //    NSArray *bounding_boxes = connected_div_and_conq(lum_edge, width, height);

    /*** Step 3: Group bounding boxes ***/
    bounding_boxes = group_into_lines(bounding_boxes, width, height);

    /*** Step 4: Binarization of interior of bounding boxes ***/
    binarization_bounding_boxes(lumin, bounding_boxes, width, height);

    make_boxes_black_on_white_bg(bounding_boxes);

    // draw bounding boxes on screen.
    lum_convert_to_rgb(lumin, outputImgBytes, width, height, bitsPerPixel);
    draw_bounding_boxes(outputImgBytes, bounding_boxes, width, height, bitsPerPixel);

	[imageView setImage:outImage];

    /*** Step 5: OCR of binarized bounding boxes ***/
    fuzzy_search_db *db = [[fuzzy_search_db alloc] init_db:@"/tmp/ramdisc/ratings"];

    NSMutableArray *result = [[NSMutableArray alloc] init];
    for(conn_box_t *box in bounding_boxes) {
		const char* ocr_text = [ocr run_tesseract:box];
        char* text = filter_ocr_string(ocr_text);
        if (text)
        {
            NSString *str = [NSString stringWithUTF8String:text];
            NSArray *matches = [db find_best_matching_movies:str
                                                        topk:20];
            for (NSString *m in matches)
            {
                int dist = [rec calc_editDistance:str b:m caseInsensitive:true];
                if (dist < 25)
                {
                    if (! [result containsObject:m])
                        [result addObject:m];
                }
            }
        }
	}

    for (NSString *str in result)
        dsptest_log(LOG_OCR, __FILE__, "found line: %s\n", [str UTF8String]);

//	NSString *str = [[NSString alloc] initWithUTF8String:text];
//	[lbl setStringValue:str];
}

@end
