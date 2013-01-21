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

static const int InfHeightDev = 20000;

/**
 * Merge a set of lines in an existing set if connected. Add as new if no
 * connection found.
 *
 * input:
 *  bounding_boxes:
 *  newlist: first element is a ((NSValue*)conn_box_t), all the following
 *           are ((NSValue*)conn_line_t)
 *  maxXdelta: maximum size of the gap in pixels on the horizontal axis
 *  maxYdelta: maximum size of the gap in pixels on the vertical axis
 *  maxHeightDev: maximum height difference allowed to merge boxes
 *  merge_lines: if FALSE merge bounding boxes only (pixels don't need to be
 *               connected), if TRUE actual lines/pixels need to be connected.
 **/
static void
merge(NSMutableArray* bounding_boxes, const conn_box_t *newbox,
      short int maxXdelta, short int maxYdelta,
      short int maxHeightDev, bool merge_lines)
{
	for(conn_box_t* box in bounding_boxes) {
		// find component connected with our new component

        if (newbox->dontMergeWith == box)
            continue;

        /* Scenario's:
           1. |     2. |     3.   |  4.  |
              | |      | |      | |    | |
              |          |      |        |
         */

        // iff bounding boxes touch, check the individual lines.
        if (!((box->ymin >= newbox->ymin-maxYdelta && box->ymin <= newbox->ymax+maxYdelta) || // 3 & 4
              (newbox->ymin >= box->ymin-maxYdelta && newbox->ymin <= box->ymax+maxYdelta)))  // 1 & 2
        {
            /* bounding boxes vertical axis don't overlap. */
            continue;
        }

        if (!((box->xmin >= newbox->xmin-maxXdelta && box->xmin <= newbox->xmax+maxXdelta) ||
              (newbox->xmin >= box->xmin-maxXdelta && newbox->xmin <= box->xmax+maxXdelta)))
        {
            /* bounding boxes horizontal axis don't overlap. */
            continue;
        }

        if (abs((box->ymax - box->ymin) - (newbox->ymax - newbox->ymin)) > maxHeightDev)
        {
            /* boxes differ too much in size */
            continue;
        }

        /* Bounding boxes touch! */
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
                if (comp.y >= newcomp.y-maxYdelta && comp.y <= newcomp.y+maxYdelta) {
                    if ((comp.xmin >= newcomp.xmin-maxYdelta && comp.xmin <= newcomp.xmax+maxYdelta) ||
                        (comp.xmax >= newcomp.xmin-maxYdelta && comp.xmax <= newcomp.xmax+maxYdelta) ||
                        (comp.xmin >= newcomp.xmin-maxYdelta && comp.xmax <= newcomp.xmax+maxYdelta) ||
                        (comp.xmin <= newcomp.xmin-maxYdelta && comp.xmax >= newcomp.xmax+maxYdelta)) {
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

/**
 * Create a new bounding box containing only the lines from the source box
 * that are part of the specified region (width,height)
 */
static NSArray *
limit_box_to_region(const conn_box_t *box,
                    int top, int left, int bottom, int right,
                    int maxYdelta)
{
#if 0
    if (!(((box->ymin >= top && box->ymin <= bottom) ||
           (box->ymin <= top && box->ymax >= top)) &&
          ((box->xmin >= left && box->xmin <= right) ||
           (box->xmin <= left && box->xmax >= right))))
    {
        return NULL;
    }
#endif
    if (!((box->ymin <= top && box->ymax >= bottom) &&
          (box->xmin <= left && box->xmax >= right)))
    {
        return NULL;
    }


    NSMutableArray* result = [[NSMutableArray alloc] init];

    for(NSValue* clval in box->lines) {
        conn_line_t cur_line;
        [clval getValue:&cur_line];

        if (cur_line.y >= top - maxYdelta && cur_line.y <= bottom + maxYdelta)
        {
            conn_box_t *cur_bbox = [[conn_box_t alloc] init];
            cur_bbox->lines = [[NSMutableArray alloc] init];
            cur_bbox->xmin = cur_line.xmin;
            cur_bbox->ymin = cur_line.y;
            cur_bbox->xmax = cur_line.xmax;
            cur_bbox->ymax = cur_line.y;
            cur_bbox->e = cur_line.e; cur_bbox->r = cur_line.r;
            cur_bbox->g = cur_line.g; cur_bbox->b = cur_line.b;

            NSValue *cur_lineval = [[NSValue alloc] initWithBytes:&cur_line
                                                         objCType:@encode(conn_line_t)];
            [cur_bbox->lines addObject:cur_lineval];
            merge(result, cur_bbox, 1, 1, InfHeightDev, false);
        }
    }

    return result;
}

/** Remove lines
 *
 **/
static NSArray *
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

/* Find boxes that are more or less centered on the same horizontal lines
   with a very similar height. If there are, check if we can fill in any
   gaps between them with parts of the remaining boxes. */
static NSArray*
fill_in_gaps(const NSArray* comps, int maxCharDeltaX, int maxCharDeltaY)
{
    NSMutableArray* result = [[NSMutableArray alloc] init];

    for(int i = 0; i < [comps count]; i++)
    {
        conn_box_t *box1 = [comps objectAtIndex:i];

        for(int j = 0; j < [comps count]; j++)
        {
            conn_box_t *box2 = [comps objectAtIndex:j];

            if (box1 == box2)
                continue;

            NSArray *boxes;
            boxes = limit_box_to_region(box2,
                                        box1->ymin,
                                        box2->xmin,
                                        box1->ymax,
                                        box2->xmax,
                                        3);
            if (boxes && [boxes count] > 0)
            {
                boxes = group_into_characters(boxes,
                                              maxCharDeltaX, maxCharDeltaY);
                for (conn_box_t *tb in boxes)
                    tb->dontMergeWith = box2;

                [result addObjectsFromArray:boxes];
            }
        }

        [result addObject:box1];
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
NSArray*
remove_too_small(const NSArray* comps, int minWidth, int minHeight)
{
    NSMutableArray* bounding_boxes = [[NSMutableArray alloc] init];
    for(conn_box_t *box in comps)
    {
        // skip too small
        if ((box->xmax - box->xmin < minWidth) ||
            (box->ymax - box->ymin < minHeight))
        {
            /*
            dsptest_log(LOG_BB, __FILE__,
                        " remove too small bounding box: (%d,%d)-(%d,%d)\n",
                        box->xmin, box->ymin, box->xmax, box->ymax);
             */
            continue;
        }
        [bounding_boxes addObject:box];
    }

    return bounding_boxes;
}

static NSArray*
group(const NSArray* comps, int maxCharDeltaX, int maxCharDeltaY,
      int maxHeightDev, bool merge_lines)
{
    const NSArray* incomps = comps;
    NSMutableArray* outcomps = [[NSMutableArray alloc] init];

    // combine connected components
    size_t size = [incomps count], prev_size = 0;
    if (size == 1)
    {
        [outcomps addObject:[incomps objectAtIndex:0]];
        return outcomps;
    }
    
    while (size != prev_size && size != 1)
    {
        prev_size = size;

        outcomps = [[NSMutableArray alloc] init];
        for (conn_box_t *box in incomps)
        {
            // skip a few empty pixels, but not more.
            merge(outcomps, box, maxCharDeltaX, maxCharDeltaY,
                  maxHeightDev, merge_lines);
        }
        if (incomps != comps)
            [incomps release];
        incomps = outcomps;
        size = [incomps count];
    }
    
    return outcomps;
}

NSArray*
group_into_characters(const NSArray* comps,
                      int maxCharDeltaX, int maxCharDeltaY)
{
    return group(comps, maxCharDeltaX, maxCharDeltaY,
                 InfHeightDev, true);
}

NSArray*
group_into_lines(const NSArray* comps, int width, int height)
{
    const NSArray* incomps = comps;
    NSArray* outcomps = nil;

    const int maxCharDeltaX = 2;
    const int maxCharDeltaY= 2;
    //    NSArray* result = remove_long_lines(lines, width, height);
    incomps = group_into_characters(incomps, maxCharDeltaX, maxCharDeltaY);

    const int minWidth = 6;
    const int minHeight = 6;
    incomps = remove_too_small(incomps, minWidth, minHeight);

#if 0
    /* Remove boxes that are completely overlapped by other boxes. */
    const int maxChildComps = 2;
    incomps = remove_overlapping(incomps, minWidth, minHeight, maxChildComps);
#endif

    /* Find median character width */
    // TODO: a sorting insert would have better performance.
    NSMutableArray* medianWidth = [[NSMutableArray alloc] init];
    NSMutableArray* medianHeight = [[NSMutableArray alloc] init];
    for(conn_box_t *box in incomps)
    {
        [medianWidth insertObject:[NSNumber
                                    numberWithInt:box->xmax - box->xmin]
                          atIndex:0];
        [medianHeight insertObject:[NSNumber
                                     numberWithInt:box->ymax - box->ymin]
                           atIndex:0];
    }
    [medianWidth sortUsingSelector:@selector(compare:)];
    [medianHeight sortUsingSelector:@selector(compare:)];

    const int maxXdelta = [[medianWidth objectAtIndex:
                            [medianWidth count] / 2] intValue] * 2;
    const int maxHeightDev = [[medianHeight objectAtIndex:
                               [medianHeight count] / 2] intValue] / 2;
    [medianWidth release];
    [medianHeight release];

    /* Cleanup and merging parameters */
//    const int maxXdelta = 2;
//    const int maxYdelta = 2;
    
    // combine small components into characters
    // keep merging bounding boxes until the minimum is reached.
    /* Merge components in larger groups, preferably along the horizontal
       axis. */
    const int maxYdelta = 2;
    incomps = group(incomps, maxXdelta, maxYdelta, maxHeightDev, false);

    incomps = fill_in_gaps(incomps, maxCharDeltaX, maxCharDeltaY);
#if 0
    dsptest_log(LOG_BB, __FILE__, "|||||||||||||||||||||||||||||||||||||||||||\n");
    log_bounding_boxes(incomps);
    dsptest_log(LOG_BB, __FILE__, "|||||||||||||||||||||||||||||||||||||||||||\n");
#endif

    outcomps = group(incomps, maxXdelta, maxYdelta, maxHeightDev, false);

	return outcomps;
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
    const int maxwidth = width;

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
                cur_bbox->dontMergeWith = NULL;

                NSValue *cur_lineval = [[NSValue alloc] initWithBytes:&(*cur_line) objCType:@encode(conn_line_t)];
                [cur_bbox->lines addObject:cur_lineval];

                merge(comps, cur_bbox, 1, 1, InfHeightDev, true);
                cur_line = 0l;
            } else {
                x++; // skip an OFF pixel
            }
        }
    }

//    lines = remove_long_lines(lines, width, height);

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
binarization_bounding_boxes(const unsigned char *inlum,
                            const NSArray* comps,
                            int width, int height)
{
    for(conn_box_t *box in comps)
    {
        int bw = box->xmax - box->xmin + 1;
        int bh = box->ymax - box->ymin + 1;
        
        box->img = (unsigned char*)malloc(bw * bh * sizeof(unsigned char));

        binarization(inlum, box->img,
                     box->xmin, box->ymin, width,
                     bw, bh,
                     0, 0, bw);
    }
}

/* After binarization, make the box colors black on white, so if it's currently
   white text on black background => invert the colors.
 */
void
make_boxes_black_on_white_bg(const NSArray* comps)
{
    int black = 0, white = 0;
    for(conn_box_t *box in comps)
    {
        int boxwidth = box->xmax - box->xmin + 1;
        int boxheight = box->ymax - box->ymin + 1;
        unsigned char *inptr;

        /* Count the current blacks & whites off the border pixels */
        int x,y;
        for (x = 0; x < boxwidth; x++) {
            // top
            y = 0;
            inptr = box->img + (y * boxwidth) + x;
            if (*inptr > 128)
                white++;
            else
                black++;
			// bottom
            y = boxheight - 1;
            inptr = box->img + (y * boxwidth) + x;
            if (*inptr > 128)
                white++;
            else
                black++;
		}

		for (y = 0; y < boxheight; y++) {
            // left
            x = 0;
            inptr = box->img + (y * boxwidth) + x;
            if (*inptr > 128)
                white++;
            else
                black++;
			// bottom
            x = boxwidth - 1;
            inptr = box->img + (y * boxwidth) + x;
            if (*inptr > 128)
                white++;
            else
                black++;
		}

        if (black > white)
        {
            // invert colors
            for (y = 0; y < boxheight; y++) {
                for (x = 0; x < boxwidth; x++) {
                    inptr = box->img + (y * boxwidth) + x;
                    *inptr = 255 - *inptr;
                }
            }
        }
    }

}
