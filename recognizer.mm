//
//  recognizer.c
//  dsptest1
//
//  Created by Lieven Govaerts on 22/12/12.
//
//

#include "util.h"
#include "graphics.h"
#include "tessocr.h"
#include "recognizer.h"

@implementation recognizer

- (NSArray *)recognize:(const unsigned char *)inlum
                 width:(int)width
                height:(int)height;
{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    unsigned char *lumtemp = (unsigned char*)malloc(width * height * sizeof(unsigned char));
    unsigned char *rgbatemp = (unsigned char*)malloc(width * height * sizeof(unsigned char) * 4);
    const int bitsPerPixel = 32;
    
    /*** Step 1: Edge detection ***/
    canny_edge_detection(inlum, rgbatemp, width, height, bitsPerPixel);

    /*** Step 2: Get small Bounding Boxes ***/
    // canny returns only 4 colors + black =-> any color > 0 should be white.
    rgb_convert_to_bw_treshold(rgbatemp, lumtemp, width, height, bitsPerPixel, 1);
    //    binarization_threshold(lum_edge, lum_edge, 0, 0, width, width, height, 0, 0, width, 1);
    NSArray *bounding_boxes = connected_binary(lumtemp, width, height);
    //    NSArray *bounding_boxes = connected_div_and_conq(lum_edge, width, height);

    /*** Step 3: Group bounding boxes ***/
    bounding_boxes = group_into_lines(bounding_boxes, width, height);

    /*** Step 4: Binarization of interior of bounding boxes ***/
    binarization_bounding_boxes(inlum, bounding_boxes, width, height);

    /*** Step 5: OCR of binarized bounding boxes ***/
    for(conn_box_t *box in bounding_boxes)
    {
        const char* ocr_text = [ocr run_tesseract:box];
        char* text = filter_ocr_string(ocr_text);
        if (text)
        {
            NSString *str = [NSString stringWithUTF8String:text];
            [result addObject:str];
        }
    }

    return result;
}

-(id)init
{
    if (self = [super init])
    {
        ocr = [[tessocr alloc] init];
    }

    return self;
}

-(void)dealloc
{
    [ocr dealloc];
    
    [super dealloc];
}

@end