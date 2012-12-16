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

void dsptest_log(int verbose_flag, const char *filename, const char *fmt, ...);

/* Connected components and bounding boxes */
typedef struct {
	short int xmin;
	short int xmax;
	short int ymin;
    short int ymax;
} conn_box_t;

NSArray* group_bounding_boxes(NSArray* lines, int width, int height);
void log_bounding_boxes(NSArray* lines);
NSArray* connected_binary(unsigned char *inptr, int width, int height);
NSArray* connected_div_and_conq(unsigned char *inptr, int width, int height);

#endif
