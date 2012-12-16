//
//  util.c
//  dsptest1
//
//  Created by Lieven Govaerts on 14/12/12.
//
//

#include <stdarg.h>
#include <stdio.h>
#include <algorithm>

#include "util.h"

/* Logging function.
 Use with one of the [COMP]_VERBOSE defines so that the compiler knows to
 optimize this code out when no logging is needed. */
void dsptest_log(int verbose_flag, const char *filename, const char *fmt, ...)
{
    va_list argp;

    if (verbose_flag) {
        if (filename)
            fprintf(stderr, "%s: ", filename);

        va_start(argp, fmt);
        vfprintf(stderr, fmt, argp);
        va_end(argp);
    }
}

typedef struct {
	short int xmin;
	short int xmax;
	short int y;
} conn_line_t;

/**
 * Merge a set of lines in an existing set if connected. Add as new if no
 * connection found.
 *
 * input:
 *  bounding_boxes:
 *  newlist:
 *  max_xdelta:
 *  max_ydelta:
 *  merge_lines: if FALSE merge bounding boxes only (pixels don't need to be
 *               connected), if TRUE actual lines/pixels need to be connected.
 **/
static void
merge(NSMutableArray* bounding_boxes, NSArray* newlist,
      short int max_xdelta, short int max_ydelta, bool merge_lines)
{
	for(NSMutableArray* list in bounding_boxes) {
		// find component connected with our new component

        NSValue* bbval = [list objectAtIndex:0];
        conn_box_t box;
        [bbval getValue:&box];

        NSValue* bbnewval = [newlist objectAtIndex:0];
        conn_box_t newbox;
        [bbnewval getValue:&newbox];

        // iff bounding boxes overlap, check the individual lines.
        if ((box.ymin >= newbox.ymin-max_ydelta && box.ymin <= newbox.ymax+max_ydelta) ||
            (box.ymax >= newbox.ymin-max_ydelta && box.ymax <= newbox.ymax+max_ydelta) ||
            (box.ymin >= newbox.ymin-max_ydelta && box.ymax <= newbox.ymax+max_ydelta) ||
            (box.ymin <= newbox.ymin-max_ydelta && box.ymax >= newbox.ymax+max_ydelta)) {
            if ((box.xmin >= newbox.xmin-max_xdelta && box.xmin <= newbox.xmax+max_xdelta) ||
                (box.xmax >= newbox.xmin-max_xdelta && box.xmax <= newbox.xmax+max_xdelta) ||
                (box.xmax >= newbox.xmin-max_xdelta && box.xmax <= newbox.xmax+max_xdelta) ||
                (box.xmin <= newbox.xmin-max_xdelta && box.xmax >= newbox.xmax+max_xdelta)) {

                if (!merge_lines) {
                    box.xmin = std::min(box.xmin, newbox.xmin);
                    box.ymin = std::min(box.ymin, newbox.ymin);
                    box.xmax = std::max(box.xmax, newbox.xmax);
                    box.ymax = std::max(box.ymax, newbox.ymax);

                    NSValue *new_bboxval = [[NSValue alloc] initWithBytes:&(box) objCType:@encode(conn_box_t)];
                    [list replaceObjectAtIndex:0 withObject:new_bboxval];

                    // add all but the first element.
                    NSRange theRange;
                    theRange.location = 1;
                    theRange.length = [newlist count] -1;
                    [list addObjectsFromArray:[newlist subarrayWithRange:theRange]];

                    return;
                }

                for(NSValue* crval in list) {
                    if (bbval == crval) // skip first element.
                        continue;

                    conn_line_t comp;
                    [crval getValue:&comp];

                    for(NSValue* newval in newlist) {
                        if (bbnewval == newval) // skip first element
                            continue;

                        conn_line_t newcomp;
                        [newval getValue:&newcomp];

                        // lines connected?
                        if (comp.y >= newcomp.y-max_ydelta && comp.y <= newcomp.y+max_ydelta) {
                            if ((comp.xmin >= newcomp.xmin-max_xdelta && comp.xmin <= newcomp.xmax+max_xdelta) ||
                                (comp.xmax >= newcomp.xmin-max_xdelta && comp.xmax <= newcomp.xmax+max_xdelta) ||
                                (comp.xmin >= newcomp.xmin-max_xdelta && comp.xmax <= newcomp.xmax+max_xdelta) ||
                                (comp.xmin <= newcomp.xmin-max_xdelta && comp.xmax >= newcomp.xmax+max_xdelta)) {
                                // yes
                                box.xmin = std::min(box.xmin, newbox.xmin);
                                box.ymin = std::min(box.ymin, newbox.ymin);
                                box.xmax = std::max(box.xmax, newbox.xmax);
                                box.ymax = std::max(box.ymax, newbox.ymax);

                                NSValue *new_bboxval = [[NSValue alloc] initWithBytes:&(box) objCType:@encode(conn_box_t)];
                                [list replaceObjectAtIndex:0 withObject:new_bboxval];

                                // add all but the first element.
                                NSRange theRange;
                                theRange.location = 1;
                                theRange.length = [newlist count] -1;
                                [list addObjectsFromArray:[newlist subarrayWithRange:theRange]];
                                
                                return;
                            }
                        }
                    }
                }
            }
        }
    }
    
    [bounding_boxes addObject:newlist];
}

NSArray* group_bounding_boxes(const NSArray* lines, int width, int height)
{
    // combine small components into characters
    // skip too large components
    // keep merging bounding boxes until minimum number was reached.
    int size = [lines count], prev_size = 0;
    const int maxwidth = (width * 3) / 4;
    const int maxheight = (height * 3) / 4;
    bool first_run = TRUE;
    NSArray* result;

    while (size != prev_size && size != 1)
    {
        prev_size = size;

        NSMutableArray* bounding_boxes = [[NSMutableArray alloc] init];
        for(NSArray* list in lines) {
            NSValue* bbval = [list objectAtIndex:0];
            conn_box_t box;
            [bbval getValue:&box];

            if (first_run)
                if ((box.xmax - box.xmin > maxwidth) ||
                    (box.ymax - box.ymin > maxheight))
                {
                    dsptest_log(LOG_BB, __FILE__,
                                " remove too big bounding box: (%d,%d)-(%d,%d)\n",
                                box.xmin, box.ymin, box.xmax, box.ymax);
                    continue;
                }
            merge(bounding_boxes, list, 10, 5, FALSE);
        }
        result = bounding_boxes;
        size = [lines count];
        first_run = false;
    }

    // remove bounding boxes that are too small
    NSMutableArray* bounding_boxes = [[NSMutableArray alloc] init];
    for(NSArray* list in result) {
        NSValue* bbval = [list objectAtIndex:0];
        conn_box_t box;
        [bbval getValue:&box];

        // skip too small
        if ((box.xmax - box.xmin < 5) ||
            (box.ymax - box.ymin < 5))
        {
            dsptest_log(LOG_BB, __FILE__,
                        " remove too small bounding box: (%d,%d)-(%d,%d)\n",
                        box.xmin, box.ymin, box.xmax, box.ymax);

            continue;
        }
        [bounding_boxes addObject:list];
    }
    result = bounding_boxes;

#if 0
    // combine words into phrases
    // keep merging bounding boxes until minimum number was reached.
    size = [lines count], prev_size = 0;
    while (size != prev_size && size != 1)
    {
        prev_size = size;

        NSMutableArray* bounding_boxes = [[NSMutableArray alloc] init];
        for(NSArray* list in lines) {
            NSValue* bbval = [list objectAtIndex:0];
            conn_box_t box;
            [bbval getValue:&box];

            merge(bounding_boxes, list, 10, 0, FALSE);
        }
        lines = bounding_boxes;
        size = [lines count];
    }
    
#endif
    
	return result;
}

/** Find connected components in a binary image.
 *  inptr: one-byte per pixel array
 *  returns an array of bounding boxes.
 *
 **/
NSArray* connected_binary(const unsigned char *inptr, int width, int height)
{
	const unsigned char* cur;
    conn_line_t *cur_line = 0l;

    NSMutableArray* lines = [[NSMutableArray alloc] init];

    // colors should be either 0 (OFF) or 255 (ON). Use <128 or >= 128 as check
    // just to be sure.

	// find horizontal lines of ON pixels
    for (int y = 0; y < height; y++) {
		for (int x = 0; x < width;) {
            // select a line of connected ON pixels
            for (cur = inptr + y * width + x ; x < width && (*cur++) >= 128 ; x++) {
                if (!cur_line) {
                    cur_line = (conn_line_t *)malloc(sizeof(conn_line_t));

                    cur_line->y = y;
                    cur_line->xmin = cur_line->xmax = x;
                } else {
                    cur_line->xmax = x;
                }
            }
            if (cur_line) {
                const int maxwidth = width / 2;
                if (cur_line->xmax - cur_line->xmin > maxwidth) {
                    cur_line = 0l;
                    continue;
                }

                // store cur_line, merge with previous lines if possible
                NSMutableArray *newcomp = [[NSMutableArray alloc] init];

                conn_box_t *cur_bbox = (conn_box_t *)malloc(sizeof(conn_box_t));
                cur_bbox->xmin = cur_line->xmin; cur_bbox->xmax = cur_line->xmax; cur_bbox->ymin = cur_bbox->ymax = cur_line->y;
                NSValue *cur_bboxval = [[NSValue alloc] initWithBytes:&(*cur_bbox) objCType:@encode(conn_box_t)];
                [newcomp addObject:cur_bboxval];

                NSValue *cur_lineval = [[NSValue alloc] initWithBytes:&(*cur_line) objCType:@encode(conn_line_t)];
                [newcomp addObject:cur_lineval];

                merge(lines, newcomp, 1, 1, TRUE);
                cur_line = 0l;
            } else {
                x++; // skip an OFF pixel
            }
        }
    }

    // combine connected components
    int size = [lines count], prev_size = 0;
    bool first_run = TRUE;
    while (size != prev_size && size != 1)
    {
        prev_size = size;

        NSMutableArray* bounding_boxes = [[NSMutableArray alloc] init];
        for(NSArray* list in lines) {
            NSValue* bbval = [list objectAtIndex:0];
            conn_box_t box;
            [bbval getValue:&box];

            merge(bounding_boxes, list, 2, 2, TRUE); // skip a few empty pixels, but not more.
        }
        lines = bounding_boxes;
        size = [lines count];
        first_run = false;
    }
    
    return lines;
}

#if 0
// histogram on the borders of characters doesn't work well, as these borders have aliassing and shadows => no single color.
void
histogram_bounding_boxes(const unsigned char *inbuf, NSArray* lines,
                         unsigned int *histogram, int width, int height)
{
    memset(histogram, 0, 256 * sizeof(unsigned int));

    int first = 1;
    for (NSValue* bbval in lines) {
        if (first) {
            first = 0;
            continue;
        }

        conn_line_t line;
        [bbval getValue:&line];

        // get histogram of this line.
        for (int x = line.xmin; x <= line.xmax; x++) {
            const unsigned char *curin = inbuf + line.y * width + x;

            (*(histogram+(unsigned int)*curin))++;
        }
    }
}
#endif

void log_bounding_boxes(const NSArray* lines)
{
    for(NSArray* list in lines) {
        NSValue* bbval = [list objectAtIndex:0];
        conn_box_t box;
        [bbval getValue:&box];

        dsptest_log(LOG_BB, __FILE__, "bounding box: (%d,%d)-(%d,%d)\n",
                    box.xmin, box.ymin, box.xmax, box.ymax);
    }
}
