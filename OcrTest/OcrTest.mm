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

typedef struct {
    const char *str;
    size_t len;
} str_t;

static bool
all_lines_found_ignore_order(NSArray *names, const str_t *expected,
                             size_t exp_len)
{
    bool result = true;
    NSMutableArray *not_found = [[NSMutableArray alloc] initWithArray:names];
    /* The same amount of lines, check that the expected lines are in the
       actually returned array. */
    for (int i = 0; i < exp_len; i++)
    {
        NSString *str = [[NSString alloc] initWithUTF8String:expected[i].str];
        
        NSUInteger index =[names indexOfObject:str];
        if (index == NSNotFound) {
            result = false;
            break;
        }

        [not_found removeObjectAtIndex:index];
        dsptest_log(LOG_TEST, __FILE__, "Found line: %s\n", expected[i].str);
    }

    /* Log the remaining lines unexpectedly returned by the ocr engine. */
    for (NSString *str in not_found)
    {
        dsptest_log(LOG_TEST, __FILE__, "Unexpected line: %s\n",
                    [str cStringUsingEncoding:NSUTF8StringEncoding]);
    }
    return result;
}

- (void) recognizer_test:(NSString*)imageName
                expected:(const str_t *)expected
                 exp_len:(size_t)exp_len;
{
    recognizer* r = [[[recognizer alloc] init] autorelease];
    int width, height;

    unsigned char *lumin = load_imagedata(imageName, &width, &height);

    NSArray *names = [r recognize:lumin
                            width:width
                           height:height];

    STAssertTrue(
                 all_lines_found_ignore_order(names, expected, exp_len),
                 nil);

}

#define STR(x)\
  { (x), sizeof(x) }

- (void) testA_blackOnWhite
{
    const str_t expected[] = { STR("A") };
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/A_bonw.jpg";

    [self recognizer_test:imageName
                 expected:expected
                  exp_len:sizeof(expected)/sizeof(expected[0])];
}

- (void) testA_whiteOnBlack
{
    const str_t expected[] = { STR("A") };
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/A_wonb.jpg";

    [self recognizer_test:imageName
                 expected:expected
                  exp_len:sizeof(expected)/sizeof(expected[0])];
}


/**
 * no slope, white text on black background.
 */
- (void) testA_wOnB_code_banks
{
    const str_t expected[] = { STR("Agent Cody Banks 2: Destination London") };
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/agent_cody_banks.jpg";

    [self recognizer_test:imageName
                 expected:expected
                  exp_len:sizeof(expected)/sizeof(expected[0])];
}

/**
 * small slope, white text on black background.
 */
- (void) testA_wOnB_code_banks_slope
{
    const str_t expected[] = { STR("Agent Cody Banks 2: Destination London") };
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/agent_cody_banks_slope.jpg";

    [self recognizer_test:imageName
                 expected:expected
                  exp_len:sizeof(expected)/sizeof(expected[0])];
}

/**
 * large font, no slope, white on gray background.
 */
- (void) testA_wOnG_el_wong
{
    const str_t expected[] = { STR("El") };
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/el_wong.jpg";

    [self recognizer_test:imageName
                 expected:expected
                  exp_len:sizeof(expected)/sizeof(expected[0])];
}

/**
 * large font, no slope, white on gray background.
 */
- (void) testA_wOnG_el_secreto_wong
{
    const str_t expected[] = { STR("El Secreto de Sus Ojos") };
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/el_secreto_wong.jpg";

    [self recognizer_test:imageName
                 expected:expected
                  exp_len:sizeof(expected)/sizeof(expected[0])];
}

/**
 * large font, no slope, white on gray background.
 */
- (void) testA_wOnG_el_secreto_de_sus_ojos_wong
{
    const str_t expected[] = { STR("El Secreto de Sus Ojos") };
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/el_secreto_de_sus_ojos.jpg";

    [self recognizer_test:imageName
                 expected:expected
                  exp_len:sizeof(expected)/sizeof(expected[0])];
}



@end
