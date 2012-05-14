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
    { -1, -2, -1 },
    {  0,  0,  0 },
    { +1, +2, +1 },
};

typedef struct {
	short int xmin;
	short int ymin;
	short int xmax;
	short int ymax;
} bounding_box_t;

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

void histogram(unsigned char *inbuf, unsigned int *histogram, int width, int height)
{
    memset(histogram, 0, 256 * sizeof(unsigned int));

	for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
			unsigned char *curin = inbuf + y * width + x;

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
    
	// calculate luminance from rgb
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
            
            lumsum = abs(lumx) + abs(lumy);
            if (lumsum > 255) lumsum = 255;
            if (lumsum < 0) lumsum = 0;
            
            *lumptr = (unsigned char)lumsum;
		}
	}
 }

/* currently based on tresholds recovered from the histogram of the image. */
void binarization(unsigned char *inlum, unsigned char *outlum,
                  int width, int height)
{
	unsigned char *curin, *curout;
    
    // calculate tresholds
#if 0    
    unsigned char ranges[100] = { 0, 8, 21, 105, 120, 251, 255 };
    unsigned char color_per_range[100] = { 0, 64, 0, 128, 0, 255 };
    int nr_of_ranges = 6;
#endif

    unsigned char ranges[100] = { 0, 251, 255 };
    unsigned char color_per_range[100] = { 0, 255 };
    int nr_of_ranges = 2;
    
	for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {

			curin = inlum + y * width + x;
			curout = outlum + y * width + x;

            unsigned char lum = *curin;
            
            for (int i = 0; i < nr_of_ranges; i++) {
                if (lum <= ranges[i+1]) {
                    *curout = color_per_range[i];
                    break;
                }
            }
		}
	}
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
	short int ymin;
	short int xmax;
	short int ymax;
	int index;
} comp_range;

NSArray* connected(unsigned char *inptr, unsigned char *outptr, int width, int height, int bitsPerPixel)
{
	int r,g,b;
	unsigned char* cur;
	int prevcolor, curcolor;
	int newcolor = 0x080808;
	int prevx, prevy;
	int* comps = (int*)malloc(width * height * sizeof(int));

	comp_range* compsranges = (comp_range*)malloc(width * height *
												  sizeof(comp_range));

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
				NSValue *crval = [NSValue value:&compsranges[comp] withObjCType:@encode(comp_range)];
				[line addObject:crval];
			} else {
				// add to new set.
				NSMutableSet *newline = [[NSMutableSet alloc] init];
				compsranges[comp].index = [lines count]; // current index = (current array size++) - 1
				NSValue *crval = [NSValue value:&compsranges[comp] withObjCType:@encode(comp_range)];
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
			comp_range comp;
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
		bounding_box_t* bb = (bounding_box_t *)malloc(sizeof(bounding_box_t));
		bb->xmin = bbxmin; bb->xmax = bbxmax; bb->ymin = bbymin; bb->ymax = bbymax;
		NSValue *crval = [NSValue value:bb withObjCType:@encode(bounding_box_t)];
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
	NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/P1180863.JPG";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/agent_cody_banks.JPG";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/IMG_0002_treshold.JPG";
//    NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/radio days.jpg";
//	NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/frits_and_freddy.jpg";
//  NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/a_single_man.jpg";
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
    unsigned char* lumtemp = (unsigned char*)malloc(width * height * sizeof(unsigned char));
	unsigned char* lumbuf = (unsigned char*)malloc(width * height * sizeof(unsigned char));
    unsigned int histbuf[256];

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

	rgb_convert_to_lum(inputImgBytes, lumbuf, width, height, bitsPerPixel);
	gaussian_blur(lumbuf, lumtemp, width, height);
    sobel_edge_detection(lumtemp, lumbuf, width, height);
//	histogram(lumbuf, histbuf, width, height);
    binarization(lumbuf, lumbuf, width, height);
	lum_convert_to_rgb(lumbuf, outputImgBytes, width, height, bitsPerPixel);

	[imageView setImage:outImage];
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
	unsigned char* lumtemp = (unsigned char*)malloc(width * height * sizeof(unsigned char));
    unsigned char* lumbuf = (unsigned char*)malloc(width * height * sizeof(unsigned char));

    unsigned int histogram[256];
    
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

    
	NSBitmapImageRep *outImage2Rep = [[NSBitmapImageRep alloc]
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
	outputImg2Bytes = [outImage2Rep bitmapData];
	NSImage* outImage2 = [[[NSImage alloc] init] autorelease];
	[outImage2 addRepresentation:outImage2Rep];
    
	rgb_convert_to_lum(inputImgBytes, lumbuf, width, height, bitsPerPixel);
	gaussian_blur(lumbuf, lumtemp, width, height);
    sobel_edge_detection(lumtemp, lumbuf, width, height);
    //	histogram(lumbuf, histbuf, width, height);
    binarization(lumbuf, lumbuf, width, height);
	lum_convert_to_rgb(lumbuf, outputImgBytes, width, height, bitsPerPixel);
    connected(lumbuf, outputImg2Bytes, width, height, bitsPerPixel);

	[imageView setImage:outImage2];
}

- (IBAction)ocr:(id)sender
{
	int bitsPerPixel  = [inImageRep bitsPerPixel];
	int width = [inImageRep pixelsWide];
	int height = [inImageRep pixelsHigh];
	int bytesPerRow = [inImageRep bytesPerRow];
    unsigned int histogram[256];
    
	tessocr* ocr = [[tessocr alloc] init];
	unsigned char* lumbuf = (unsigned char*)malloc(width * height * sizeof(unsigned char));

	// not used for visualisation
	NSBitmapImageRep *outImage2Rep = [[NSBitmapImageRep alloc]
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
	outputImg2Bytes = [outImage2Rep bitmapData];


//	filter_and_convert_to_gray(inputImgBytes, lumbuf, width, height, bitsPerPixel);
	rgb_convert_to_lum(inputImgBytes, lumbuf, width, height, bitsPerPixel);
//    binarization(lumbuf, lumbuf, histogram, width, height);
	NSArray* bounding_boxes = connected(lumbuf, outputImg2Bytes, width, height, bitsPerPixel);

	for(NSValue* crval in bounding_boxes) {
		bounding_box_t bb;
		[crval getValue:&bb];
		char* text = [ocr run_tesseract:lumbuf
						bytes_per_pixel:1
						 bytes_per_line:width
								   left:bb.xmin
									top:bb.ymin
								  width:bb.xmax - bb.xmin
								 height:bb.ymax - bb.ymin
					  ];
		printf("%s\n", text);
	}
//	NSString *str = [[NSString alloc] initWithUTF8String:text];
//	[lbl setStringValue:str];
}

@end
