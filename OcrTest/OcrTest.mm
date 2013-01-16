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
    
    editDistances = [[NSMutableDictionary alloc] init];

    // Set-up code here.
    dsptest_log(LOG_TEST, NULL, "------------------------------------------------------\n");
}

- (void)tearDown
{
    // Tear-down code here.
    [editDistances release];

    [super tearDown];
    dsptest_log(LOG_TEST, NULL, "======================================================\n");
}

/* Calculate and return the Levenshteint distance between two strings. */
- (int) calc_editDistance:(NSString *)a
                        b:(NSString *)b
{
    NSInteger lenA = [a length];
    NSInteger lenB = [b length];
    int cost = 0;

    NSString* key = [NSString stringWithFormat:@"%@/%ld//%@/%ld", a, lenA, b, lenB];
    id dist = [editDistances objectForKey:key];
    if (dist != nil)
        return (int)[dist integerValue];

    /* Store distances between known string */
    if (lenA == 0) return (int)lenB;
    if (lenB == 0) return (int)lenA;

    /* Cost of 1 if current characters not equal */
    if ([a characterAtIndex:0] != [b characterAtIndex:0]) cost = 1;

    /* Calculate the total cost of the remaining characters in both strings.
       Three possible operations: Delete character, Insert character or
                                  Modify character */
    int delCost = [self calc_editDistance:[a substringFromIndex:1] b:b] + 1;
    int insCost = [self calc_editDistance:a b:[b substringFromIndex:1]] + 1;
    int modCost = [self calc_editDistance:[a substringFromIndex:1]
                                        b:[b substringFromIndex:1]] + cost;

    /* Take the minimum of the possible costs for the remaining characters. */
    int min = delCost < insCost ? delCost : insCost;
    min = min < modCost ? min : modCost;

    [editDistances setObject:[NSNumber numberWithInteger:min] forKey:key];

    return min;
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

- (int) all_lines_found_ignore_order:(NSArray *)actual
                            expected:(const str_t *)expected
                             exp_len:(size_t)exp_len
                     minEditDistance:(int)minEditDistance
{
    bool result = true;
    NSMutableArray *not_found = [[NSMutableArray alloc] initWithArray:actual];
    /* The same amount of lines, check that the expected lines are in the
       actually returned array. */
    for (int i = 0; i < exp_len; i++)
    {
        NSString *a = [[NSString alloc] initWithUTF8String:expected[i].str];
        NSString *b = nil;
        int cost = 100000;

        for (b in actual)
        {
            cost = [self calc_editDistance:a b:b];
            if (cost <= minEditDistance)
                break;
        }
        if (cost > minEditDistance) {
            result = false;
            break;
        }

        [not_found removeObjectIdenticalTo:b];
        dsptest_log(LOG_TEST, __FILE__, "Found expected '%s' for '%s' (distance %d)\n", expected[i].str,
                    [b cStringUsingEncoding:NSUTF8StringEncoding], cost);
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

    STAssertTrue([self all_lines_found_ignore_order:names
                                           expected:expected
                                            exp_len:exp_len
                                    minEditDistance:2], nil);

}

#define STR(x)\
  { (x), sizeof(x) }

- (void) test_blackOnWhite_A
{
    const str_t expected[] = { STR("A") };
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/A_bonw.jpg";

    [self recognizer_test:imageName
                 expected:expected
                  exp_len:sizeof(expected)/sizeof(expected[0])];
}

- (void) test_whiteOnBlack_A
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
- (void) test_WonB_cody_banks
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
- (void) test_WonB_cody_banks_slope
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
- (void) test_WonG_el
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
- (void) test_WonG_el_secreto
{
    const str_t expected[] = { STR("El Secreto") };
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/el_secreto_wong.jpg";

    [self recognizer_test:imageName
                 expected:expected
                  exp_len:sizeof(expected)/sizeof(expected[0])];
}

/**
 * large font, no slope, white on gray background + border
 */
- (void) test_WonG_el_secreto_de_sus_ojos
{
    const str_t expected[] = { STR("El Secreto de Sus Ojos") };
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/el_secreto_de_sus_ojos.jpg";

    [self recognizer_test:imageName
                 expected:expected
                  exp_len:sizeof(expected)/sizeof(expected[0])];
}

/**
 * Test to ensure a grouping component (border around the text) is not dropped
 * because too many children (the inner circle of the two o's and the d.).
 */
- (void) test_BonW_London
{
    const str_t expected[] = { STR("London") };
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/london_bonw.jpg";

    [self recognizer_test:imageName
                 expected:expected
                  exp_len:sizeof(expected)/sizeof(expected[0])];
}

/**
 * Same test as BonW_London but inverted colors.
 */
- (void) test_WonB_London
{
    const str_t expected[] = { STR("London") };
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/london_wonb.jpg";

    [self recognizer_test:imageName
                 expected:expected
                  exp_len:sizeof(expected)/sizeof(expected[0])];
}

/**
 * Text with border (touches the text by one pixel).
 */
- (void) test_WonB_El_Traspatio_border
{
    const str_t expected[] = { STR("El Traspatio") };
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/el_traspatio_border_wong.jpg";

    [self recognizer_test:imageName
                 expected:expected
                  exp_len:sizeof(expected)/sizeof(expected[0])];
}

/**
 * Text with border.
 */
- (void) test_BonW_border_text
{
    const str_t expected[] = { STR("TEKST") };
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/border_text_bonw.jpg";

    [self recognizer_test:imageName
                 expected:expected
                  exp_len:sizeof(expected)/sizeof(expected[0])];
}

/**
 * Text with border (touches the text by one pixel).
 */
- (void) test_BonW_border_text_connected
{
    const str_t expected[] = { STR("TEKST") };
    NSString* imageName = @"/Users/lgo/macdev/dsptest1/OcrTest/images/border_text_conn_bonw.jpg";

    [self recognizer_test:imageName
                 expected:expected
                  exp_len:sizeof(expected)/sizeof(expected[0])];
}

- (void) test_calcDistance
{
    STAssertEquals([self calc_editDistance:@"A" b:@"A"], 0, nil);
    STAssertEquals([self calc_editDistance:@"A" b:@"B"], 1, nil);
    STAssertEquals([self calc_editDistance:@"A" b:@"aA"], 1, nil);
    STAssertEquals([self calc_editDistance:@"A" b:@"aaaaaaA"], 6, nil);
    STAssertEquals([self calc_editDistance:@"aaaA" b:@"aaaaaaA"], 3, nil);
    STAssertEquals([self calc_editDistance:@"aaaaaaA" b:@"aaaA"], 3, nil);
    STAssertEquals([self calc_editDistance:@"London" b:@"Londen"], 1, nil);
    STAssertEquals([self calc_editDistance:@"El Secreto de Sus Ojos"
                                      b:@"El Secrcto de Sus Ojos"], 1, nil);
    STAssertEquals([self calc_editDistance:@"Agent Cody Banks 2: Destination London"
                                         b:@"Agent Cody Ianks 2: Destination London"],
                   1, nil);
    STAssertEquals([self calc_editDistance:@"Agent Cody Banks 2: Destination London"
                                         b:@"Agnnt  Innis 2;: Dnﬂnatlon London"],
                   14, nil);
}

@end
