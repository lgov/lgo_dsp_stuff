//
//  dsptestview.m
//  dsptest1
//
//  Created by Lieven Govaerts on 08/02/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "dsptestview.h"
#import "tessocr.h"
#include <Accelerate/Accelerate.h>
#include "stdlib.h"
#include <math.h>

@implementation dsptestview

int sharpen[3][3]  = { { -1, -1, -1 },
    { -1,  8, -1 },
    { -1, -1, -1 } };

int smoothen[3][3]  = { { 1, 1, 1 },
	{ 1, 1, 1 },
	{ 1, 1, 1 } };

int LoG[9][9] = {
	{ 0, 1, 1, 2, 2, 2, 1, 1, 0 },
	{ 1, 2, 4, 5, 5, 5, 4, 2, 1 },
	{ 1, 4, 5, 3, 0, 3, 5, 4, 1 },
	{ 2, 5, 3, -12, -24, -12, 3, 5, 2 },
	{ 2, 5, 0, -24, -40, -24, 0, 5, 2 },
	{ 2, 5, 3, -12, -24, -12, 3, 5, 2 },
	{ 1, 4, 5, 3, 0, 3, 5, 4, 1 },
	{ 1, 4, 5, 3, 0, 3, 5, 4, 1 },
	{ 0, 1, 1, 2, 2, 2, 1, 1, 0 } };

int Gaussian[5][5] = {
    { 1, 4, 7, 4, 1 },
    { 4, 16, 26, 16, 4 },
    { 7, 26, 41, 26, 7 },
    { 4, 16, 26, 16, 4 },
    { 1, 4, 7, 4, 1 },
};
int GaussianDivider = 273;

int SobelHorizontal[3][3] = {
    { -1, 0, +1 },
    { -2, 0, +2 },
    { -1, 0, +1 },
};

int SobelVertical[3][3] = {
    { +1, +2, +1 },
    {  0,  0,  0 },
    { -1, -2, -1 },
};

void lum_convert_to_rgb(unsigned char *lumbuf, unsigned char *outbuf,
						int width, int height, int bitsPerPixel)
{
	int rowPixels = width * bitsPerPixel / 8;
    
	for (int y = 0; y < height; y++) {
		int yloc = y * rowPixels;
		unsigned char *lumptr = lumbuf + y * width;
        
		for (int x = 0; x < width; x++) {
			int xloc = x * bitsPerPixel / 8;
            
			unsigned char *curout = outbuf + yloc + xloc;
            
			*curout++ = *lumptr; // r
			*curout++ = *lumptr; // g
			*curout++ = *lumptr++; // b
			*curout++ = 0;
		}
	}
}

void histogram(unsigned char *inbuf, unsigned int *histogram, 
               int inleft, int intop,
               int inwidth,
               int boxwidth, int boxheight)
{
    memset(histogram, 0, 256 * sizeof(unsigned int));

	for (int y = 0; y < boxheight; y++) {
		for (int x = 0; x < boxwidth; x++) {
			unsigned char *curin = inbuf + (intop + y) * inwidth + (x + inleft);

            (*(histogram+(unsigned int)*curin))++;
        }
    }
}

void rgb_convert_to_lum(unsigned char *inbuf, unsigned char *lumbuf,
						int width, int height, int bitsPerPixel)
{    
	int rowPixels = width * bitsPerPixel / 8;
    
	for (int y = 0; y < height; y++) {
		int yloc = y * rowPixels;
		unsigned char *lumptr = lumbuf + y * width;
        
		for (int x = 0; x < width; x++) {
			int xloc = x * bitsPerPixel / 8;
            
			unsigned char *curin = inbuf + yloc + xloc;
            
			unsigned char r = *curin++, g = *curin++, b = *curin++;
			// calculate luminance from rgb
			float lum = 0.3 * r + 0.59 * g + 0.11 * b;
            
			*lumptr++ = lum; // r
		}
	}
}

// both x and y in bytes.
// outptr points to x,y point in output buffer.
void convolution(unsigned char *lumin, int *outptr,
                 int x, int y,
                 int width, int height,
                 int *matrix, int matrixSize,
                 int matrix_divider,
                 int *min, int *max)
{
	int offset = matrixSize / 2;  // should be 1 for a matrix of size 3.
	unsigned char *incur;
    int lum = 0;
    
	// calculate convolution of one pixel!
	for (int i = 0; i < matrixSize; i++) {
		int yloc = (y + (i - offset)) * width;
		if (yloc < 0 || (y + (i - offset)) >= height) continue;
        
		for (int j= 0; j < matrixSize; j++) {
			int xloc = x + (j - offset);
			if (xloc < 0 || (x + (j - offset)) >= width) continue;
            
			incur = lumin + yloc + xloc;
			int m = *(matrix + (i * matrixSize) + j);
			lum += (int)*incur * m;
		}
	}
    
    lum /= matrix_divider;
    
	if (lum < *min)
		*min = lum;
	if (lum > *max)
		*max = lum;
	*outptr = lum;
}

void convolution_in_range(unsigned char *lumin, unsigned char *lumout,
                          int x, int y,
                          int width, int height,
                          int *matrix, int matrixSize,
                          int matrix_divider)
{
	int offset = matrixSize / 2;  // should be 1 for a matrix of size 3.
	unsigned char *incur;
    int lum = 0;
    
	// calculate convolution of one pixel!
	for (int i = 0; i < matrixSize; i++) {
		int yloc = (y + (i - offset)) * width;
		if (yloc < 0 || (y + (i - offset)) >= height) continue;
        
		for (int j= 0; j < matrixSize; j++) {
			int xloc = x + (j - offset);
			if (xloc < 0 || (x + (j - offset)) >= width) continue;
            
			incur = lumin + yloc + xloc;
			int m = *(matrix + (i * matrixSize) + j);
			lum += (int)*incur * m;
		}
	}
    
    lum /= matrix_divider;
    
	*lumout = lum;
}

void filter_and_convert_to_gray(unsigned char *inbuf, unsigned char *outbuf,
								int width, int height, int bitsPerPixel)
{
	unsigned char* lumin = (unsigned char*)malloc(width * height * sizeof(unsigned char));
	int* lumbuf = (int*)malloc(width * height * sizeof(int));
	int* lumptr;
	int min = 0, max = 0;
	unsigned char *curout;
    unsigned int histogram[256];
    
    rgb_convert_to_lum(inbuf, lumin, width, height, bitsPerPixel);
    
	for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
			lumptr = lumbuf + y * width + x;
			convolution(lumin, lumptr,
                        x, y, width, height,
                        (int*)sharpen, 3, 1,
                        &min, &max);
		}
	}
    
	// minimum and maximum luminance is stored in min and max respectively.
    
	// copy intermediate luminance buffer to output luminance buffer,
	// adapt values to range.
	for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
			lumptr = lumbuf + y * width + x;
			int lum = *lumptr;
			float gray = ((lum - min) / ((max - min)/255));
            
			curout = outbuf + y * width + x;
            
			*curout++ = (unsigned char)gray;
		}
	}
}

void gaussian_blur(unsigned char *inlum, unsigned char *outlum,
                   int width, int height)
{
    unsigned char *lumptr;

 	for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
			lumptr = outlum + y * width + x;
			convolution_in_range(inlum, lumptr,
                                 x, y, width, height,
                                 (int*)Gaussian, 5, GaussianDivider);
		}
	}
}

#define PI 3.14159265

void sobel_edge_detection(unsigned char *inlum, unsigned char *outlum,
                          int width, int height)
{
    int lumx, lumy, lumsum;
	int min = 0, max = 0;
    unsigned char *lumptr;

 	for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
			lumptr = outlum + y * width + x;
			convolution(inlum, &lumy,
                        x, y, width, height,
                        (int*)SobelVertical, 3, 1,
                        &min, &max);

			convolution(inlum, &lumx,
                        x, y, width, height,
                        (int*)SobelHorizontal, 3, 1,
                        &min, &max);
            
            // edge strength
            lumsum = sqrt(lumx * lumx + lumy * lumy);
            if (lumsum > 255) lumsum = 255;
            if (lumsum < 0) lumsum = 0;
            
            *lumptr = lumsum;
		}
	}
}

// http://dasl.mem.drexel.edu/alumni/bGreen/www.pages.drexel.edu/_weg22/can_tut.html
void canny_edge_detection(unsigned char *inlum, unsigned char *outbuf,
                          int width, int height, int bitsperpixel)
{
    unsigned char* templum = (unsigned char*)malloc(width * height * sizeof(unsigned char));
    unsigned char* gradiants = (unsigned char*)malloc(width * height * sizeof(unsigned char));
    unsigned char* strengths = (unsigned char*)malloc(width * height * sizeof(unsigned char));

    // step 1: gaussian blur
    gaussian_blur(inlum, templum, width, height);
    
    // step 2: sobel horizontal & vertical edge filtering
    int Gx, Gy, strength;
	int min = 0, max = 0;
    unsigned char *outptr, *strengthptr, *gradptr;
    
 	for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
			outptr = outbuf + y * (width * bitsperpixel / 8) + x * (bitsperpixel / 8);
            strengthptr = strengths + y * width + x;
            gradptr = gradiants + y * width + x;
            
			convolution(inlum, &Gy,
                        x, y, width, height,
                        (int*)SobelVertical, 3, 1,
                        &min, &max);
            
			convolution(inlum, &Gx,
                        x, y, width, height,
                        (int*)SobelHorizontal, 3, 1,
                        &min, &max);
            
            // edge strength
            strength = sqrt(Gx * Gx + Gy * Gy);
            if (strength > 255) strength = 255;
            if (strength < 0) strength = 0;
            
            double edge_dir;
            if (strength > 128) {                
                // edge direction
                if (Gx == 0 && Gy == 0) {
                    edge_dir = 0;
                }
                edge_dir = atan2(Gx, Gy) * 180 / PI;
                
                // assign edge to range
                if (((edge_dir < 22.5) && (edge_dir > -22.5)) || (edge_dir > 157.5) || (edge_dir < -157.5)) {
                    edge_dir = 0;
                    *outptr++ = 255; *outptr++ = 255; *outptr++ = 0; *outptr = 0; // yellow
                }
                if (((edge_dir > 22.5) && (edge_dir < 67.5)) || ((edge_dir < -112.5) && (edge_dir > -157.5))) {
                    edge_dir = 45;
                    *outptr++ = 0; *outptr++ = 255; *outptr++ = 0; *outptr = 0; // green
                }
                if (((edge_dir > 67.5) && (edge_dir < 112.5)) || ((edge_dir < -67.5) && (edge_dir > -112.5))) {
                    edge_dir = 90;
                    *outptr++ = 0; *outptr++ = 0; *outptr++ = 255; *outptr = 0; // blue
                }
                if (((edge_dir > 112.5) && (edge_dir < 157.5)) || ((edge_dir < -22.5) && (edge_dir > -67.5))) {
                    edge_dir = 135;
                    *outptr++ = 255; *outptr++ = 0; *outptr++ = 0; *outptr = 0; // red
                }
            } else {
                edge_dir = 255;
                *outptr++ = 0; *outptr++ = 0; *outptr++ = 0; *outptr = 0;
            }

            *strengthptr = strength;
            *gradptr = (int)edge_dir;
		}
	}

    // step 3: non-maximum suppression
    for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
            strengthptr = strengths + y * width + x;
            gradptr = gradiants + y * width + x;
			outptr = outbuf + y * (width * bitsperpixel / 8) + x * (bitsperpixel / 8);

            switch (*gradptr) {
                case 0: {
                    unsigned char *strength_top = strengths + (y-1) * width + x;
                    unsigned char *strength_bottom = strengths + (y+1) * width + x;
                    strength = *strength_bottom > *strength_top ? *strength_bottom : *strength_top;
                    break;
                }
                    
                case 45: {
                    unsigned char *strength_righttop = strengths + (y-1) * width + x + 1;
                    unsigned char *strength_leftbottom = strengths + (y+1) * width + x - 1;
                    strength = *strength_leftbottom > *strength_righttop ? *strength_leftbottom : *strength_righttop;
                    break;
                }
                    
                case 90: {
                    unsigned char *strength_left = strengths + y * width + x - 1;
                    unsigned char *strength_right = strengths + y * width + x + 1;
                    strength = *strength_right > *strength_left ? *strength_right : *strength_left;
                    break;
                }
                    
                case 135: {
                    unsigned char *strength_lefttop = strengths + (y-1) * width + x - 1;
                    unsigned char *strength_rightbottom = strengths + (y+1) * width + x + 1;
                    strength = *strength_rightbottom > *strength_lefttop ? *strength_rightbottom : *strength_lefttop;
                    break;
                }
                    
                default:
                    break;
            }
            if (*strengthptr <= strength) {
                *strengthptr = 0;
                *outptr++ = 0; *outptr++ = 0; *outptr++ = 0; *outptr = 0;
            }
            
        }
    }
    
    
    free(templum);
}
void binarization_threshold(unsigned char* inlum, unsigned char* outlum,
                            int inleft, int intop,
                            int inwidth,
                            int boxwidth, int boxheight,
                            int outleft, int outtop,
                            int outwidth,
                            int threshold)
{
    unsigned char *curin, *curout;

    for (int y = 0; y < boxheight; y++) {
		for (int x = 0; x < boxwidth; x++) {
            
			curin = inlum + (((y + intop) * inwidth) + (x + inleft));
			curout = outlum + (((y + outtop) * inwidth) + (x + outleft));
            
            unsigned char lum = *curin;
            
            if (lum >= threshold)
                *curout = 255;
            else
                *curout = 0;
		}
	}
}

void binarization(unsigned char* inlum, unsigned char* outlum,
                  int inleft, int intop,
                  int inwidth,
                  int boxwidth, int boxheight,
                  int outleft, int outtop,
                  int outwidth)
{
    unsigned int histbuf[256];

    // histogram
    histogram(inlum, histbuf, inleft, intop, inwidth, boxwidth, boxheight);

    // calculate tresholds with otsu
    unsigned int threshold = 0;
    
    // http://www.labbookpages.co.uk/software/imgProc/otsuThreshold.html
    // Total number of pixels
    int total = boxwidth * boxheight;
    float sum = 0;
    for (int t=0 ; t<256 ; t++) sum += t * histbuf[t];
    
    float sumB = 0;
    int wB = 0;
    int wF = 0;
    
    float varMax = 0;

    for (int t = 0; t < 256; t++) {
        wB += histbuf[t];               // Weight Background
        if (wB == 0) continue;
        
        wF = total - wB;                 // Weight Foreground
        if (wF == 0) break;
        
        sumB += (float) (t * histbuf[t]);
        
        float mB = sumB / wB;            // Mean Background
        float mF = (sum - sumB) / wF;    // Mean Foreground
        
        // Calculate Between Class Variance
        float varBetween = (float)wB * (float)wF * (mB - mF) * (mB - mF);
        
        // Check if new maximum found
        if (varBetween > varMax) {
            varMax = varBetween;
            threshold = t;
        }
    }
    
    binarization_threshold(inlum, outlum, inleft, intop, inwidth, boxwidth, boxheight, outleft, outtop, outwidth, threshold);
}


#define T 5
#define SHADES 32

// ensure that pixels of similar color will have the exact same color.
void prepare(unsigned char *inlum, unsigned char *outlum, int width, int height, int bitsPerPixel)
{
	unsigned char lum, prevlum;
	unsigned char* cur;
	int newlum = 255;

	for (int y = 0; y < height; y++) {
		// setup the first pixel on the left.
		// ...

		for (int x = 1; x < width; x++) {
			int prevx = (x - 1);

			cur = inlum + y * width + prevx;
			prevlum = *cur++;
			lum = *cur++;

			unsigned char delta = abs(prevlum - lum);
			if (delta < T) {
				cur = outlum + y * width + prevx;
				prevlum = *cur++;
				newlum = (prevlum / SHADES) * SHADES;
			} else
			{
				newlum = (lum / SHADES) * SHADES;
			}

			*(outlum + y * width + x) = newlum;
		}
	}
}

typedef struct {
	short int xmin;
	short int xmax;
	short int y;
} conn_line_t;

typedef struct {
	short int xmin;
	short int xmax;
	short int ymin;
    short int ymax;
} conn_box_t;

// merge a set of lines in an existing set if connected. Add as new if no connection found.
void merge(NSMutableArray* bounding_boxes, NSArray* newlist, short int max_xdelta, short int max_ydelta, bool merge_lines)
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

NSArray* connected_binary(unsigned char *inptr, int width, int height)
{
	unsigned char* cur;
	int curcolor;
    conn_line_t *cur_line = 0l;

    NSMutableArray* lines = [[NSMutableArray alloc] init];

    // colors should be either 0 (OFF) or 255 (ON). Use <128 or >= 128 as check just to be sure.
    
	// find horizontal lines of ON pixels
    for (int y = 6; y < height; y++) {
		for (int x = 0; x < width;) {
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

    int size = [lines count], prev_size = 0;

    // combine small components into characters
    // skip too large components
    // keep merging bounding boxes until minimum number was reached.
    const int maxwidth = width / 4;
    const int maxheight = height / 4;
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
            continue;
        }
        [bounding_boxes addObject:list];
    }
    lines = bounding_boxes;

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
    
	return lines;
}

void draw_bounding_boxes(unsigned char *outptr, NSArray* lines,
                         int width, int height, int bitsPerPixel)
{
    for(NSArray* list in lines) {
        NSValue* bbval = [list objectAtIndex:0];
        conn_box_t box;
        [bbval getValue:&box];
            
		// TODO: cleanup all compranges in the set.
        
		// draw a blue bounding box
		for (int x = box.xmin; x < box.xmax; x++) {
			int xloc = x * bitsPerPixel / 8;
			// top
			int yloc = box.ymin * width * bitsPerPixel / 8;
			*(outptr + xloc + yloc) = 255;
			*(outptr + xloc + yloc + 1) = 0;
			*(outptr + xloc + yloc + 2) = 0;
			// bottom
			yloc = box.ymax * width * bitsPerPixel / 8;
			*(outptr + xloc + yloc) = 255;
			*(outptr + xloc + yloc + 1) = 0;
			*(outptr + xloc + yloc + 2) = 0;
		}
        
		for (int y = box.ymin; y < box.ymax; y++) {
			int yloc = y * width * bitsPerPixel / 8;
            
			int xloc = box.xmin * bitsPerPixel / 8;
			*(outptr + xloc + yloc) = 255;
			*(outptr + xloc + yloc + 1) = 0;
			*(outptr + xloc + yloc + 2) = 0;
            
			xloc = box.xmax * bitsPerPixel / 8;
			*(outptr + xloc + yloc) = 255;
			*(outptr + xloc + yloc + 1) = 0;
			*(outptr + xloc + yloc + 2) = 0;
		}
	}
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

void binarization_bounding_boxes(unsigned char *inlum, unsigned char *outlum, NSArray* lines,
                                 int width, int height)
{
    for(NSArray* list in lines) {
        NSValue* bbval = [list objectAtIndex:0];
        conn_box_t box;
        [bbval getValue:&box];
         
        binarization(inlum, outlum,
                     box.xmin, box.ymin, width,
                     box.xmax - box.xmin, box.ymax - box.ymin,
                     box.xmin, box.ymin, height);
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
	int maxratio = 5;

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

	printf("result\n");
	return bounding_boxes;
}

- (void) awakeFromNib
{
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/replica_state_license_plate.gif";
    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/P1180863.JPG";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/P1180863_lessbright.JPG";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/el_secreto_de_sus_ojos.JPG";
//	 NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/agent_cody_banks.JPG";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/IMG_0002_treshold.JPG";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/radio days.jpg";
//	NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/frits_and_freddy.jpg";
//  NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/a_single_man.jpg";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/canny_test.jpg";
	image = [[NSImage alloc] initWithContentsOfFile:imageName];

	NSData* fileData = [NSData dataWithContentsOfFile:imageName];
	inImageRep = [NSBitmapImageRep
				  imageRepWithData:fileData];
	if (inImageRep){
		NSImage* inImage = [[NSImage alloc] init];
		[inImage addRepresentation:inImageRep];

		inputImgBytes = [inImageRep bitmapData];

		[imageView setImage:inImage];
	}
}

- (IBAction)calcEdges:(id)sender
{
	int bitsPerPixel  = [inImageRep bitsPerPixel];
	int width = [inImageRep pixelsWide];
	int height = [inImageRep pixelsHigh];
    unsigned char* lumin = (unsigned char*)malloc(width * height * sizeof(unsigned char));
    unsigned char* lum_edge = (unsigned char*)malloc(width * height * sizeof(unsigned char));

	NSBitmapImageRep *outImageRep = [[NSBitmapImageRep alloc]
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
	NSImage* outImage = [[[NSImage alloc] init] autorelease];
	[outImage addRepresentation:outImageRep];
	outputImgBytes = [outImageRep bitmapData];

	rgb_convert_to_lum(inputImgBytes, lumin, width, height, bitsPerPixel);
    canny_edge_detection(lumin, outputImgBytes, width, height, bitsPerPixel);
//    binarization(lum_edge, lum_edge, 0, 0, width, width, height, 0, 0, height); // fixed threshold 240
//	lum_convert_to_rgb(lum_edge, outputImgBytes, width, height, bitsPerPixel);

	[imageView setImage:outImage];
    
    free(lumin);
    free(lum_edge);
}


- (IBAction)prepare:(id)sender
{
	int bitsPerPixel  = [inImageRep bitsPerPixel];
	int width = [inImageRep pixelsWide];
	int height = [inImageRep pixelsHigh];
	unsigned char* lumbuf = (unsigned char*)malloc(width * height * sizeof(unsigned char));
    
	NSBitmapImageRep *outImageRep = [[NSBitmapImageRep alloc]
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
	NSImage* outImage = [[[NSImage alloc] init] autorelease];
	[outImage addRepresentation:outImageRep];
	outputImgBytes = [outImageRep bitmapData];

/*	filter_and_convert_to_gray(inputImgBytes, lumbuf, width, height, bitsPerPixel);
	prepare(lumbuf, lumoutbuf, width, height, bitsPerPixel);*/
    
	rgb_convert_to_lum(inputImgBytes, lumbuf, width, height, bitsPerPixel);
	gaussian_blur(lumbuf, lumbuf, width, height);
    lum_convert_to_rgb(lumbuf, outputImgBytes, width, height, bitsPerPixel);
    
	[imageView setImage:outImage];
}

- (IBAction)calcConnCons:(id)sender
{
	int bitsPerPixel  = [inImageRep bitsPerPixel];
	int width = [inImageRep pixelsWide];
	int height = [inImageRep pixelsHigh];
    unsigned char* lumin = (unsigned char*)malloc(width * height * sizeof(unsigned char));
	unsigned char* lum_edge = (unsigned char*)malloc(width * height * sizeof(unsigned char));
    unsigned char* lumbuf = (unsigned char*)malloc(width * height * sizeof(unsigned char));
    
	NSBitmapImageRep *outImageRep = [[NSBitmapImageRep alloc]
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
	NSImage* outImage = [[[NSImage alloc] init] autorelease];
	[outImage addRepresentation:outImageRep];
	outputImgBytes = [outImageRep bitmapData];

    rgb_convert_to_lum(inputImgBytes, lumin, width, height, bitsPerPixel);
	
    // localize text
    gaussian_blur(lumin, lumbuf, width, height);
    sobel_edge_detection(lumbuf, lum_edge, width, height);
    binarization(lum_edge, lum_edge, 0, 0, width, width, height, 0, 0, height); // fixed threshold 240

    NSArray *bounding_boxes = connected_binary(lum_edge, width, height);
	
    binarization_bounding_boxes(lumin, lumbuf, bounding_boxes, width, height);
    
    // draw bounding boxes on screen.
    lum_convert_to_rgb(lumbuf, outputImgBytes, width, height, bitsPerPixel);
    draw_bounding_boxes(outputImgBytes, bounding_boxes, width, height, bitsPerPixel); 
    
	[imageView setImage:outImage];
}

- (IBAction)ocr:(id)sender
{
	int bitsPerPixel  = [inImageRep bitsPerPixel];
	int width = [inImageRep pixelsWide];
	int height = [inImageRep pixelsHigh];
    
	tessocr* ocr = [[tessocr alloc] init];
    unsigned char* lumin = (unsigned char*)malloc(width * height * sizeof(unsigned char));
	unsigned char* lum_edge = (unsigned char*)malloc(width * height * sizeof(unsigned char));
    unsigned char* lumbuf = (unsigned char*)malloc(width * height * sizeof(unsigned char));

	NSBitmapImageRep *outImageRep = [[NSBitmapImageRep alloc]
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
	NSImage* outImage = [[[NSImage alloc] init] autorelease];
	[outImage addRepresentation:outImageRep];
	outputImgBytes = [outImageRep bitmapData];

    
    rgb_convert_to_lum(inputImgBytes, lumin, width, height, bitsPerPixel);
	
    // localize text
    gaussian_blur(lumin, lumbuf, width, height);
    sobel_edge_detection(lumbuf, lum_edge, width, height);
    binarization(lum_edge, lum_edge, 0, 0, width, width, height, 0, 0, height); // fixed threshold 240
    
    NSArray *bounding_boxes = connected_binary(lum_edge, width, height);
    binarization_bounding_boxes(lumin, lumbuf, bounding_boxes, width, height);
    	
    // draw bounding boxes on screen.
    lum_convert_to_rgb(lumbuf, outputImgBytes, width, height, bitsPerPixel);
    draw_bounding_boxes(outputImgBytes, bounding_boxes, width, height, bitsPerPixel); 
    
	[imageView setImage:outImage];
    
    for(NSArray* list in bounding_boxes) {
        NSValue* bbval = [list objectAtIndex:0];
		conn_box_t bb;
		[bbval getValue:&bb];
		char* text = [ocr run_tesseract:lumbuf
						bytes_per_pixel:1
						 bytes_per_line:width
								   left:bb.xmin
									top:bb.ymin
								  width:bb.xmax - bb.xmin
								 height:bb.ymax - bb.ymin
					  ];
        // TODO: split on cariage return
        // remove one character phrases
        if (text && strlen(text)>0)
            printf("%s\n", text);
	}
//	NSString *str = [[NSString alloc] initWithUTF8String:text];
//	[lbl setStringValue:str];
}

@end
