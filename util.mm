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
	short int ymin;
	short int xmax;
	short int ymax;
	int index;
} comp_range_t;

NSArray* connected(unsigned char *inptr, unsigned char *outptr, int width, int height, int bitsPerPixel)
{
	int r,g,b;
	unsigned char* cur;
	int prevcolor, curcolor;
	int newcolor = 0x080808;
	int prevx, prevy;
	int* comps = (int*)malloc(width * height * sizeof(int));

	comp_range_t* compsranges = (comp_range_t*)malloc(width * height *
                                                      sizeof(comp_range_t));

	int currentcomp=0;
	int maxcomp = 0;

	*comps = 0;
	for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
			cur = inptr + y * width + x;
			curcolor = *cur++;

			// check if this pixel has the same color as all 4 previous
			// connecting pixels.
			int firstline = (y == 0 ? 3 : 0); // don't check prev. line pixels
            // if we're processing the first line.
			int firstcol = (x == 0 ? 2 : 4); // don't check prev. col pixels on
            // first column.
			int found = FALSE;
			for (int i = firstline ; i < firstcol; i++) {
				switch(i) {
				    case 0: // y-1, x
						prevy = y - 1; prevx = x;
						break;
				    case 1: // y-1, x + 1
						prevy = y - 1; prevx = x + 1;
						break;
				    case 2: // y-1, x-1
						prevy = y - 1; prevx = x - 1;
						break;
				    case 3: // y, x - 1
						prevy = y; prevx = x - 1;
						break;
				}

				cur = inptr + prevy * width + prevx;
				prevcolor = *cur++;
				if (abs(curcolor - prevcolor) < 10) {
					currentcomp = *(comps+prevy*width+prevx);
					found = TRUE;
					break;
				}
			}
			if (!found) {
				currentcomp = maxcomp++;
			}

			// use x + 1 and y + 1 to use 0 as uninitialized.
			// doesn't matter for calculating width/height.
			if (compsranges[currentcomp].xmin == 0 ||
				x + 1 < compsranges[currentcomp].xmin)
				compsranges[currentcomp].xmin = x + 1;
			if (compsranges[currentcomp].xmax == 0 ||
				x + 1 > compsranges[currentcomp].xmax)
				compsranges[currentcomp].xmax = x + 1;
			if (compsranges[currentcomp].ymin == 0 ||
				y + 1 < compsranges[currentcomp].ymin)
				compsranges[currentcomp].ymin = y + 1;
			if (compsranges[currentcomp].ymax == 0 ||
				y + 1 > compsranges[currentcomp].ymax)
				compsranges[currentcomp].ymax = y + 1;
			compsranges[currentcomp].index = -1;

            *(comps+y*width+x) = currentcomp;
		}
	}

	int minwidth=2;
	int minheight=2;
	int maxwidth = 50;
	int maxheight = 50;
    //	int maxratio = 5;

	for (int y = 0; y < height; y++) {
		int yloc = y * width * bitsPerPixel / 8;

		for (int x = 0; x < width; x++) {
			int xloc = x * bitsPerPixel / 8;

			int comp = *(comps+y*width+x);

			newcolor = comp;
			// only keep those components that match certain shape requirements.
			if (compsranges[comp].xmax - compsranges[comp].xmin > maxwidth)
				newcolor = 0x000000;
			if (compsranges[comp].ymax - compsranges[comp].ymin > maxheight)
				newcolor = 0x000000;
			if ((compsranges[comp].xmax - compsranges[comp].xmin < minwidth) &&
				(compsranges[comp].ymax - compsranges[comp].ymin < minheight))
				newcolor = 0x000000;
			if (compsranges[comp].xmax - compsranges[comp].xmin < minwidth)
				newcolor = 0x000000;
			if (compsranges[comp].ymax - compsranges[comp].ymin < minheight)
				newcolor = 0x000000;

#if 0
			if (compsranges[comp].xmax - compsranges[comp].xmin < minwidth)
				newcolor = 0x000000;
			if (compsranges[comp].ymax - compsranges[comp].ymin < minheight)
				newcolor = 0x000000;
			if ((compsranges[comp].ymax - compsranges[comp].ymin) >
				(compsranges[comp].xmax - compsranges[comp].xmin) * maxratio)
				newcolor = 0x000000;
			if ((compsranges[comp].xmax - compsranges[comp].xmin) >
				(compsranges[comp].ymax - compsranges[comp].ymin) * maxratio)
				newcolor = 0x000000;
#endif
			r = newcolor & 0xff;
			g = 0x00; //(newcolor >> 8) & 0xff;
			b = 0x00; // (newcolor >> 16) & 0xff;

			*(outptr + xloc + yloc) = r;
			*(outptr + xloc + yloc + 1) = g;
			*(outptr + xloc + yloc + 2) = b;
		}
	}

	int maxdelta = 20;

	NSMutableArray* lines = [[NSMutableArray alloc] init];

	// create connected sets along the horizontal axis.
	for (int y = 0; y < height; y+=3) {
		int prevcomp = -1;
		for (int x = 0; x < width; x+=3) {
			int comp = *(comps+y*width+x);

			if (comp == prevcomp)
				continue;
			// only keep those components that match certain shape requirements.
			if (compsranges[comp].xmax - compsranges[comp].xmin > maxwidth)
				continue;
			if (compsranges[comp].ymax - compsranges[comp].ymin > maxheight)
				continue;
			if ((compsranges[comp].xmax - compsranges[comp].xmin < minwidth) &&
				(compsranges[comp].ymax - compsranges[comp].ymin < minheight))
				continue;
			if (compsranges[comp].xmax - compsranges[comp].xmin < minwidth)
				continue;
			if (compsranges[comp].ymax - compsranges[comp].ymin < minheight)
				continue;

			if (prevcomp != -1 && compsranges[comp].xmin - compsranges[prevcomp].xmax < maxdelta) {
				// add to same set.
				int index = compsranges[prevcomp].index;
				compsranges[comp].index = index;
				NSMutableSet *line = [lines objectAtIndex:index];
				NSValue *crval = [NSValue value:&compsranges[comp] withObjCType:@encode(comp_range_t)];
				[line addObject:crval];
			} else {
				// add to new set.
				NSMutableSet *newline = [[NSMutableSet alloc] init];
				compsranges[comp].index = [lines count]; // current index = (current array size++) - 1
				NSValue *crval = [NSValue value:&compsranges[comp] withObjCType:@encode(comp_range_t)];
				[newline addObject:crval];
				[lines addObject:newline];
			}
			prevcomp = comp;
		}
	}

	NSMutableArray* bounding_boxes = [[NSMutableArray alloc] init];
	for(NSMutableSet* set in lines) {
		// calculate bounding box for each set
		int bbxmin=width, bbxmax=0, bbymin=height, bbymax=0;
		for(NSValue* crval in set) {
			comp_range_t comp;
			[crval getValue:&comp];
			if (comp.xmin < bbxmin) bbxmin = comp.xmin - 1;
			if (comp.ymin < bbymin) bbymin = comp.ymin - 1;
			if (comp.xmax > bbxmax) bbxmax = comp.xmax - 1;
			if (comp.ymax > bbymax) bbymax = comp.ymax - 1;
		}

		if ((bbxmax - bbxmin < 10) &&
			(bbymax - bbymin < 10))
			continue;

		// store bounding box
		conn_box_t* bb = (conn_box_t *)malloc(sizeof(conn_box_t));
		bb->xmin = bbxmin; bb->xmax = bbxmax; bb->ymin = bbymin; bb->ymax = bbymax;
		NSValue *crval = [NSValue value:bb withObjCType:@encode(conn_box_t)];
		[bounding_boxes addObject:crval];

		// TODO: cleanup all compranges in the set.

		// draw a blue bounding box
		for (int x = bbxmin; x < bbxmax; x++) {
			int xloc = x * bitsPerPixel / 8;
			// top
			int yloc = bbymin * width * bitsPerPixel / 8;
			*(outptr + xloc + yloc) = 0;
			*(outptr + xloc + yloc + 1) = 0;
			*(outptr + xloc + yloc + 2) = 255;
			// bottom
			yloc = bbymax * width * bitsPerPixel / 8;
			*(outptr + xloc + yloc) = 0;
			*(outptr + xloc + yloc + 1) = 0;
			*(outptr + xloc + yloc + 2) = 255;
		}

		for (int y = bbymin; y < bbymax; y++) {
			int yloc = y * width * bitsPerPixel / 8;

			int xloc = bbxmin * bitsPerPixel / 8;
			*(outptr + xloc + yloc) = 0;
			*(outptr + xloc + yloc + 1) = 0;
			*(outptr + xloc + yloc + 2) = 255;
            
			xloc = bbxmax * bitsPerPixel / 8;
			*(outptr + xloc + yloc) = 0;
			*(outptr + xloc + yloc + 1) = 0;
			*(outptr + xloc + yloc + 2) = 255;
		}
	}

	return bounding_boxes;
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

NSArray* group_bounding_boxes(NSArray* lines, int width, int height)
{
    // combine small components into characters
    // skip too large components
    // keep merging bounding boxes until minimum number was reached.
    int size = [lines count], prev_size = 0;
    const int maxwidth = (width * 3) / 4;
    const int maxheight = (height * 3) / 4;
    bool first_run = TRUE;

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
        lines = bounding_boxes;
        size = [lines count];
        first_run = false;
    }

    // remove bounding boxes that are too small
    NSMutableArray* bounding_boxes = [[NSMutableArray alloc] init];
    for(NSArray* list in lines) {
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
    lines = bounding_boxes;

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
    
	return lines;
}

// implemented connected components with the same approach as opengl shaders.
NSArray* connected_div_and_conq(unsigned char *inptr, int width, int height)
{
    unsigned char *cur, *buf;
    unsigned char* outbuf = (unsigned char*)malloc(width * height * sizeof(unsigned char) * 4);


    // iterate over all pixels, assign join or merge
    for (int y = 1; y < height; y++) {
		for (int x = 1; x < width;x++) {
            cur = inptr + y * width + x;
            buf = outbuf + y * width + x;

            unsigned char *topLeft = inptr + (y-1) * width + x-1;
            unsigned char *left = inptr + y * width + x-1;
            unsigned char *top = inptr + (y-1) * width + x;
            unsigned char *topRight = inptr + (y-1) * width + x+1;
            unsigned char *right = inptr + y * width + x+1;

            int sum = 16.0 * (*topLeft==255?1:0) + 8.0 * (*top==255?1:0) + 4.0 * (*topRight==255?1:0) +
            1.0 * (*left==255?1:0)                       + 2.0 * (*right==255?1:0);


            float merge = 1.0 / 5.0; // join up
            unsigned char connectToX = 0; // X delta to next lookup pixel
            unsigned char connectToY = 0; // Y delta to next lookup pixel

            if (sum >= 16.0) {
                connectToX = -1;
                connectToY = -1;

                if (sum >= 20.0 && sum <= 22.0)
                    merge = 3.0/5.0;
            } else if (sum >= 8.0) {
                connectToX = 0;
                connectToY = -1;

                if (sum % 2 == 1.0)
                    merge = 4.0/5.0;
            } else if (sum >= 3.0) {
                connectToX = 1;
                connectToY = 1;

                if (sum == 5.0)
                    merge = 5.0/5.0;
            } else if (sum % 2 == 1.0) {
                connectToX = -1;
                connectToY = 0;
            }

            float label = 1.0; //mod(connectTo.x, 16.0/256.0) * 16.0/256.0 + mod(connectTo.y, 16.0/256.0);

            // join the label at connectTo, tell our right/top oriented neighbours they
            // should take over our label.

            //  gl_FragColor = vec4(label, connectTo, merge);
            *buf++ = label * 256;
            *buf++ = connectToX + 128;
            *buf++ = connectToY + 128;
            *buf++ = merge * 256;
        }
    }


    for (int iter = 0;iter < 1; iter++) {
        for (int y = 1; y < height; y++) {
            for (int x = 1; x < width;x++) {
                cur = inptr + y * width + x;
                buf = outbuf + y * width + x;
            }
        }
    }

    return NULL;
}

/** Find connected components in a binary image.
 *  inptr: one-byte per pixel array
 *  returns an array of bounding boxes.
 *
 **/
NSArray* connected_binary(unsigned char *inptr, int width, int height)
{
	unsigned char* cur;
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
void histogram_bounding_boxes(unsigned char *inbuf, NSArray* lines, unsigned int *histogram, int width, int height)
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
            unsigned char *curin = inbuf + line.y * width + x;

            (*(histogram+(unsigned int)*curin))++;
        }
    }
}
#endif

void log_bounding_boxes(NSArray* lines)
{
    for(NSArray* list in lines) {
        NSValue* bbval = [list objectAtIndex:0];
        conn_box_t box;
        [bbval getValue:&box];

        dsptest_log(LOG_BB, __FILE__, "bounding box: (%d,%d)-(%d,%d)\n",
                    box.xmin, box.ymin, box.xmax, box.ymax);
    }
}
