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
#include "graphics.h"

@implementation conn_box_t

@end

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
    short int r,g,b,e; /* 4 colors representing 'canny' edges. */
} conn_line_t;

/**
 * Merge a set of lines in an existing set if connected. Add as new if no
 * connection found.
 *
 * input:
 *  bounding_boxes:
 *  newlist: first element is a ((NSValue*)conn_box_t), all the following
 *           are ((NSValue*)conn_line_t)
 *  max_xdelta:
 *  max_ydelta:
 *  merge_lines: if FALSE merge bounding boxes only (pixels don't need to be
 *               connected), if TRUE actual lines/pixels need to be connected.
 **/
static void
merge(NSMutableArray* bounding_boxes, const conn_box_t *newbox,
      short int max_xdelta, short int max_ydelta, bool merge_lines)
{
	for(conn_box_t* box in bounding_boxes) {
		// find component connected with our new component

        /* Scenario's:
           1. |     2. |     3.   |  4.  |
              | |      | |      | |    | |
              |          |      |        |
         */

        // iff bounding boxes overlap, check the individual lines.
        if (!((box->ymin >= newbox->ymin-max_ydelta && box->ymin <= newbox->ymax+max_ydelta) || // 3 & 4
              (newbox->ymin >= box->ymin-max_ydelta && newbox->ymin <= box->ymax+max_ydelta)))  // 1 & 2
        {
            /* bounding boxes vertical axis don't overlap. */
            continue;
        }

        if (!((box->xmin >= newbox->xmin-max_xdelta && box->xmin <= newbox->xmax+max_xdelta) ||
              (newbox->xmin >= box->xmin-max_xdelta && newbox->xmin <= box->xmax+max_xdelta)))
        {
            /* bounding boxes horizontal axis don't overlap. */
            continue;
        }
        
        /* Bounding boxes overlap! */
        if (!merge_lines)
        {
            /* Merge the bounding boxes, add lines from second bounding
             box to first. */
            box->xmin = std::min(box->xmin, newbox->xmin);
            box->ymin = std::min(box->ymin, newbox->ymin);
            box->xmax = std::max(box->xmax, newbox->xmax);
            box->ymax = std::max(box->ymax, newbox->ymax);
            box->e += newbox->e; box->r += newbox->r;
            box->g += newbox->g; box->b += newbox->b;

            // add all lines.
            [box->lines addObjectsFromArray:newbox->lines];

            return;
        }

        /* Check that pixels are connected. */
        for(NSValue* clval in box->lines) {
            conn_line_t comp;
            [clval getValue:&comp];

            for(NSValue* newval in newbox->lines) {
                conn_line_t newcomp;
                [newval getValue:&newcomp];

                // lines connected?
                if (comp.y >= newcomp.y-max_ydelta && comp.y <= newcomp.y+max_ydelta) {
                    if ((comp.xmin >= newcomp.xmin-max_xdelta && comp.xmin <= newcomp.xmax+max_xdelta) ||
                        (comp.xmax >= newcomp.xmin-max_xdelta && comp.xmax <= newcomp.xmax+max_xdelta) ||
                        (comp.xmin >= newcomp.xmin-max_xdelta && comp.xmax <= newcomp.xmax+max_xdelta) ||
                        (comp.xmin <= newcomp.xmin-max_xdelta && comp.xmax >= newcomp.xmax+max_xdelta)) {
                        // yes
                        /* Merge the bounding boxes, add lines from second bounding
                         box to first. */
                        box->xmin = std::min(box->xmin, newbox->xmin);
                        box->ymin = std::min(box->ymin, newbox->ymin);
                        box->xmax = std::max(box->xmax, newbox->xmax);
                        box->ymax = std::max(box->ymax, newbox->ymax);
                        box->e += newbox->e; box->r += newbox->r;
                        box->g += newbox->g; box->b += newbox->b;

                        // add all but the first element.
                        [box->lines addObjectsFromArray:newbox->lines];

                        return;
                    }
                }
            }
        }
    }

    [bounding_boxes addObject:newbox];
}

/** Remove lines
 *
 **/
static NSArray*
remove_long_lines(const NSArray* comps, int width, int height)
{
    NSMutableArray* result = [[NSMutableArray alloc] init];

    for(conn_box_t *box in comps)
    {
        int total = box->e + box->r + box->g + box->b;

        if ((box->e * 100 / total) > 80 ||
            (box->r * 100 / total) > 80 ||
            (box->g * 100 / total) > 80 ||
            (box->b * 100 / total) > 80)
        {
            continue;
        }

        [result addObject:box];
    }
    return result;
}

/**
 * remove_overlapping searches the list of bounding boxes for those that seem
 * to group other smaller components. This often happens when text has a 
 * rectangular background. We want to remove the component matching the
 * background.
 **/
static NSArray*
remove_overlapping(const NSArray* comps,
                   int minWidth, int minHeight, int maxChildComps)
{
    /* If box is smaller than minwidth or minheight, it's probably not a
       grouping component. */
    NSMutableArray* result = [[NSMutableArray alloc] init];

    for(int i = 0; i < [comps count]; i++)
    {
        conn_box_t *box = [comps objectAtIndex:i];
        if ((box->xmax - box->xmin > minWidth) &&
            (box->ymax - box->ymin > minHeight))
        {
            int childComps = 0;

            for(int j = 0; j < [comps count]; j++)
            {
                conn_box_t *box2 = [comps objectAtIndex:j];
                if (box == box2)
                    continue;

                /* Don't count very small boxes */
                if ((box2->xmax - box2->xmin < 5) ||
                    (box2->ymax - box2->ymin < 5))
                    continue;

                if (box->xmin <= box2->xmin &&
                    box->ymin <= box2->ymin &&
                    box->xmax >= box2->xmax &&
                    box->ymax >= box2->ymax)
                {
                    childComps++;
                }
            }

            if (childComps > maxChildComps)
            {
                dsptest_log(LOG_BB, __FILE__,
                            " remove bounding box with %d children: "\
                            "(%d,%d)-(%d,%d)\n",
                            childComps, box->xmin, box->ymin, box->xmax, box->ymax);
                continue;
            }
        }
        [result addObject:box];
    }

    return result;
}

/* Returns a new array of connected components, from which all those that
   are either wider than maxWidth and/or bigger than maxHeight are removed. */
static NSArray*
remove_too_big(const NSArray* comps, int maxWidth, int maxHeight)
{
    NSMutableArray* bounding_boxes = [[NSMutableArray alloc] init];
    for(conn_box_t *box in comps)
    {
        // skip too big
        if ((box->xmax - box->xmin > maxWidth) ||
            (box->ymax - box->ymin > maxHeight))
        {
            dsptest_log(LOG_BB, __FILE__,
                        " remove too big bounding box: (%d,%d)-(%d,%d)\n",
                        box->xmin, box->ymin, box->xmax, box->ymax);
            continue;
        }
        [bounding_boxes addObject:box];
    }

    return bounding_boxes;
}

/* Returns a new array of connected components, from which all those that
   are either smaller than minWidth and/or shorter than minHeight are removed. */
static NSArray*
remove_too_small(const NSArray* comps, int minWidth, int minHeight)
{
    NSMutableArray* bounding_boxes = [[NSMutableArray alloc] init];
    for(conn_box_t *box in comps)
    {
        // skip too small
        if ((box->xmax - box->xmin < minWidth) ||
            (box->ymax - box->ymin < minHeight))
        {
            dsptest_log(LOG_BB, __FILE__,
                        " remove too small bounding box: (%d,%d)-(%d,%d)\n",
                        box->xmin, box->ymin, box->xmax, box->ymax);

            continue;
        }
        [bounding_boxes addObject:box];
    }

    return bounding_boxes;
}

NSArray* group_bounding_boxes(const NSArray* comps, int width, int height)
{
    size_t size, prev_size = 0;
    NSArray* result;

    //    NSArray* result = remove_long_lines(lines, width, height);

    /* Remove boxes that are completely overlapped by other boxes. */
    const int minWidth = 10;
    const int minHeight = 10;
    const int maxChildComps = 2;
    result = remove_overlapping(comps, minWidth, minHeight, maxChildComps);

    /* Cleanup and merging parameters */
    const int maxWidth = width; // (width * 3) / 4;
    const int maxHeight = height; // (height * 3) / 4;
//    const int maxXdelta = 2;
//    const int maxYdelta = 2;

    result = remove_too_big(result, maxWidth, maxHeight);

    size = [result count];

    // combine small components into characters
    // skip too large components
    // keep merging bounding boxes until the minimum is reached.
    /* Merge components in larger groups, preferably along the horizontal
       axis. */
    while (size != prev_size && size != 1)
    {
        prev_size = size;

        NSMutableArray* bounding_boxes = [[NSMutableArray alloc] init];
        for(conn_box_t *box in result)
        {
            int maxXdelta = box->xmax - box->xmin;
            int maxYdelta = 2;

            merge(bounding_boxes, box, maxXdelta, maxYdelta, false);
        }
        result = bounding_boxes;
        size = [result count];
    }

    result = remove_too_small(result, minWidth, minHeight);
    
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
    const int maxwidth = width / 2;

    NSMutableArray* comps = [[NSMutableArray alloc] init];

    // colors should be either 0 (OFF) or 255 (ON). Use 0 or > 0 as check
    // just to be sure.

	// find horizontal lines of ON pixels
    for (int y = 0; y < height; y++) {
		for (int x = 0; x < width;) {
            // select a line of connected ON pixels
            for (cur = inptr + y * width + x ; x < width && (*cur) > 0 ; cur++, x++) {
                if (!cur_line) {
                    cur_line = (conn_line_t *)malloc(sizeof(conn_line_t));
                    cur_line->e = cur_line->r = cur_line->g = cur_line->b = 0;
                    cur_line->y = y;
                    cur_line->xmin = cur_line->xmax = x;
                } else {
                    cur_line->xmax = x;
                }
                switch (*cur) {
                    case 0: break;
                    case 1: cur_line->e++;break;
                    case 2: cur_line->r++;break;
                    case 3: cur_line->g++;break;
                    case 4: cur_line->b++;break;
                }
            }
            if (cur_line) {
                if (cur_line->xmax - cur_line->xmin > maxwidth) {
                    cur_line = 0l;
                    continue;
                }

                // store cur_line, merge with previous lines if possible
                conn_box_t *cur_bbox = [[conn_box_t alloc] init];
                cur_bbox->e = cur_line->e; cur_bbox->r = cur_line->r;
                cur_bbox->g = cur_line->g; cur_bbox->b = cur_line->b;
                cur_bbox->xmin = cur_line->xmin; cur_bbox->xmax = cur_line->xmax;
                cur_bbox->ymin = cur_bbox->ymax = cur_line->y;
                cur_bbox->lines = [[NSMutableArray alloc] init];

                NSValue *cur_lineval = [[NSValue alloc] initWithBytes:&(*cur_line) objCType:@encode(conn_line_t)];
                [cur_bbox->lines addObject:cur_lineval];

                merge(comps, cur_bbox, 1, 1, TRUE);
                cur_line = 0l;
            } else {
                x++; // skip an OFF pixel
            }
        }
    }

//    lines = remove_long_lines(lines, width, height);

    // combine connected components
    size_t size = [comps count], prev_size = 0;
    while (size != prev_size && size != 1)
    {
        prev_size = size;

        NSMutableArray* bounding_boxes = [[NSMutableArray alloc] init];
        for(conn_box_t *box in comps)
        {
            merge(bounding_boxes, box, 2, 2, TRUE); // skip a few empty pixels, but not more.
        }
        comps = bounding_boxes;
        size = [comps count];
    }
    
    return comps;
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

void log_bounding_boxes(const NSArray *comps)
{
    for(conn_box_t *box in comps)
    {
        int total = box->e + box->r + box->g + box->b;
        dsptest_log(LOG_BB, __FILE__,
                    "bounding box: (%d,%d)-(%d,%d) y:%d,r:%d,g:%d,b:%d\n",
                    box->xmin, box->ymin, box->xmax, box->ymax,
                    (box->e * 100)/total, (box->r * 100)/total,
                    (box->g * 100)/total, (box->b * 100)/total);
    }
}

/**
 * Takes a line of text, received from the ocr engine, and cleans up.
 * returns 0l for unwanted lines.
 */
char* filter_ocr_string(const char *txt)
{
    char *result, *outp;
    const char *p;
    int alphabetic_chars = 0;

    /* String is NULL */
    if (!txt)
        return 0l;

    /* String too long */
    size_t len = strlen(txt);
    if (len > 1024)
        return 0l;
    result = (char*)malloc(len);

    p = txt; outp = result;

    /* Tesseract has the habbit of adding crlf add the end of the line.
       remove it. */
    for (const char *p = txt; *p;)
    {
        if (*p == '\n' || *p == '\r')
        {
            *outp = 0;
            break;
        }
        if ((*p >= 'A' && *p <= 'Z') || (*p >= 'a' && *p <= 'z'))
            alphabetic_chars++;

        *outp++ = *p++;
    }
    *outp = 0;

    /* Should have at least one alphabetic character */
    if (alphabetic_chars == 0)
        return 0l;

    return result;
}


void
binarization_bounding_boxes(const unsigned char *inlum, unsigned char *outlum,
                            const NSArray* comps,
                            int width, int height)
{
    for(conn_box_t *box in comps) {

        binarization(inlum, outlum,
                     box->xmin, box->ymin, width,
                     box->xmax - box->xmin, box->ymax - box->ymin,
                     box->xmin, box->ymin, height);
    }
}
