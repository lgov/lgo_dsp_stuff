//
//  util.h
//  dsptest1
//
//  Created by Lieven Govaerts on 14/12/12.
//
//

#ifndef dsptest1_util_h
#define dsptest1_util_h

#define LOG_BB 1
#define LOG_OCR 1
#define LOG_TEST 1

void dsptest_log(int verbose_flag, const char *filename, const char *fmt, ...);

/* Connected components and bounding boxes */

@interface conn_box_t : NSObject {
    @public     // TODO: change all these to properties
	short int xmin;
	short int xmax;
	short int ymin;
    short int ymax;
    short int r,g,b,e; /* 4 colors representing 'canny' edges. */

    /* collection of lines of connected pixels */
    NSMutableArray *lines;
}
@end

void binarization_bounding_boxes(const unsigned char *inlum,
                                 unsigned char *outlum,
                                 const NSArray* lines,
                                 int width, int height);
NSArray* group_bounding_boxes(const NSArray* lines, int width, int height);
void log_bounding_boxes(const NSArray* lines);
NSArray* connected_binary(const unsigned char *inptr, int width, int height);
char* filter_ocr_string(const char *txt);

#endif
