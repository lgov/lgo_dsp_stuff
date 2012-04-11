//
//  dsptestview.m
//  dsptest1
//
//  Created by Lieven Govaerts on 08/02/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "dsptestview.h"
#include <Accelerate/Accelerate.h>
#include "stdlib.h"

@implementation dsptestview

float sharpen[3][3]  = { { -1, -1, -1 },
	                  { -1,  8, -1 },
					  { -1, -1, -1 } };

float smoothen[3][3]  = { { 1, 1, 1 },
	{ 1, 1, 1 },
	{ 1, 1, 1 } };

float LoG[9][9] = {
	{ 0, 1, 1, 2, 2, 2, 1, 1, 0 },
	{ 1, 2, 4, 5, 5, 5, 4, 2, 1 },
	{ 1, 4, 5, 3, 0, 3, 5, 4, 1 },
	{ 2, 5, 3, -12, -24, -12, 3, 5, 2 },
	{ 2, 5, 0, -24, -40, -24, 0, 5, 2 },
	{ 2, 5, 3, -12, -24, -12, 3, 5, 2 },
	{ 1, 4, 5, 3, 0, 3, 5, 4, 1 },
	{ 1, 4, 5, 3, 0, 3, 5, 4, 1 },
	{ 0, 1, 1, 2, 2, 2, 1, 1, 0 } };

// both x and y in bytes.
// outptr points to x,y point in output buffer.
void convolution_and_convert_to_gray(unsigned char *inptr, float *outptr,
				 int x, int y,
				 int width, int height, int bitsPerPixel,
				 float *matrix, int matrixSize,
				 float *min, float *max)
{
	float r=0, g=0, b=0;
	int offset = matrixSize / 2;  // should be 1 for a matrix of size 3.
	int rowPixels = width * bitsPerPixel / 8;
	unsigned char *incur;

	// calculate convolution of one pixel!
	for (int i = 0; i < matrixSize; i++) {
		int yloc = (y + (i - offset)) * rowPixels;
		if (yloc < 0) continue;

		for (int j= 0; j < matrixSize; j++) {
			int xloc = (x + (j - offset)) * bitsPerPixel / 8;
			if (xloc < 0) continue;

			incur = inptr + yloc + xloc;
			float m = *(matrix + (i * matrixSize) + j);
			r += (float)(*incur++) * m;  // r
			g += (float)(*incur++) * m;  // g
			b += (float)(*incur++) * m;  // b
		}
	}

	// calculate luminance from rgb
	float lum = 0.3 * r + 0.59 * g + 0.11 * b;
	if (lum < *min)
		*min = lum;
	if (lum > *max)
		*max = lum;
	*outptr = lum;
}

void filter(unsigned char *inbuf, unsigned char *outbuf, int width, int height,
			int bitsPerPixel)
{
	float* lumbuf = (float*)malloc(width * height * sizeof(float));
	float* lumptr;
	float min = 0, max = 0;
	int rowPixels = width * bitsPerPixel / 8;
	unsigned char *curout;

	for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
			lumptr = lumbuf + y * width + x;
			convolution_and_convert_to_gray(inbuf, lumptr,
											x, y, width, height, bitsPerPixel,
											LoG, 9,
											&min, &max);
		}
	}

	// minimum and maximum luminance is stored in min and max respectively.

	// copy luminance buffer to out rgb buffer, adapt range.
	for (int y = 0; y < height; y++) {
		int yloc = y * rowPixels;
		for (int x = 0; x < width; x++) {
			int xloc = x * bitsPerPixel / 8;

			lumptr = lumbuf + y * width + x;
			curout = outbuf + yloc + xloc;
			float lum = *lumptr;

			float gray = ((lum - min) / ((max - min)/255));
			*curout++ = gray; // r
			*curout++ = gray; // g
			*curout++ = gray; // b
			*curout++ = 0;
		}
	}
}

void binarization(unsigned char *inptr, unsigned char *outptr, int width, int height, int bitsPerPixel)
{
	unsigned char *curin, *curout;
	int r,g,b;
	int newcolor;

	for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
			int xloc = x * bitsPerPixel / 8;
			int yloc = y * width * bitsPerPixel / 8;

			curin = inptr + xloc + yloc;
			curout = outptr + xloc + yloc;

			r = *curin++; g = *curin++; b = *curin++; curin++;

			if (r * r + g * g + b * b > 128 * 128 * 3)
				newcolor = 255;
			else
				newcolor =	0;
			*curout++ = newcolor; *curout++ = 0; *curout++ = 0;
		}
	}
}

#define T 15
#define SHADES 32

// ensure that pixels of similar color will have the exact same color.
void prepare(unsigned char *inptr, unsigned char *outptr, int width, int height, int bitsPerPixel)
{
	int r,g,b;
	int prevr,prevg,prevb;
	unsigned char* cur;
	int newcolor = 255;

	for (int y = 0; y < height; y++) {
		int yloc = y * width * bitsPerPixel / 8;

		// setup the first pixel on the left.
		// ...

		for (int x = 1; x < width; x++) {
			int prevxloc = (x - 1) * bitsPerPixel / 8;
			int xloc = x * bitsPerPixel / 8;

			cur = inptr + yloc + prevxloc;
			prevr = *cur++; prevg = *cur++; prevb = *cur++; cur++;
			r = *cur++; g = *cur++; b = *cur++; cur++;

			long delta = (prevr-r) * (prevr-r) + (prevg-g) * (prevg-g) + (prevb-b) * (prevb-b);
			if (delta < T * T) {
				cur = outptr + yloc + prevxloc;
				prevr = *cur++; prevg = *cur++; prevb = *cur++; cur++;
				newcolor = ((prevr+prevg+prevb) / SHADES) * SHADES / 3;
			} else
			{
				int avg = (r+g+b) / 3;
				newcolor = (avg / SHADES) * SHADES;
			}

			r = newcolor;
			g = newcolor;
			b = newcolor;

			*(outptr + xloc + yloc) = r;
			*(outptr + xloc + yloc + 1) = g;
			*(outptr + xloc + yloc + 2) = b;
		}
	}
}

typedef struct {
	short int xmin;
	short int ymin;
	short int xmax;
	short int ymax;
} comp_range;

void connected(unsigned char *inptr, unsigned char *outptr, int width, int height, int bitsPerPixel)
{
	int r,g,b;
	int prevr,prevg,prevb;
	unsigned char* cur;
	int prevcolor, curcolor;
	int newcolor = 0x080808;
	int prevx, prevy, prevxloc, prevyloc;
	int* comps = (int*)malloc(width * height * sizeof(int));
	comp_range* compsranges = (comp_range*)malloc(width * height *
												  sizeof(comp_range));

	int currentcomp=0;
	int maxcomp = 0;

	*comps = 0;
	for (int y = 0; y < height; y++) {
		int yloc = y * width * bitsPerPixel / 8;

		for (int x = 0; x < width; x++) {
			int xloc = x * bitsPerPixel / 8;
			cur = inptr + xloc + yloc;
			r = *cur++; g = *cur++; b = *cur++; cur++;
			curcolor = r + g + b;

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

				prevyloc = prevy * width * bitsPerPixel / 8;
				prevxloc = prevx * bitsPerPixel / 8;

				cur = inptr + prevyloc + prevxloc;
				prevr = *cur++; prevg = *cur++; prevb = *cur++; cur++;
				prevcolor = prevr + prevg + prevb;
				if (abs(curcolor - prevcolor) == 0) {
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
				x < compsranges[currentcomp].xmin)
				compsranges[currentcomp].xmin = x + 1;
			if (compsranges[currentcomp].xmax == 0 ||
				x > compsranges[currentcomp].xmax)
				compsranges[currentcomp].xmax = x + 1;
			if (compsranges[currentcomp].ymin == 0 ||
				y < compsranges[currentcomp].ymin)
				compsranges[currentcomp].ymin = y + 1;
			if (compsranges[currentcomp].ymax == 0 ||
				y > compsranges[currentcomp].ymax)
				compsranges[currentcomp].ymax = y + 1;

            *(comps+y*width+x) = currentcomp;
		}
	}

	int minwidth=10;
	int minheight=15;
	int maxwidth = 500;
	int maxheight = 500;
	int maxratio = 2;

	for (int y = 0; y < height; y++) {
		int yloc = y * width * bitsPerPixel / 8;

		for (int x = 0; x < width; x++) {
			int xloc = x * bitsPerPixel / 8;

			int comp = *(comps+y*width+x);

			newcolor = comp;

			// only keep those components that match certain shape requirements.
			if (compsranges[comp].xmax - compsranges[comp].xmin < minwidth)
				newcolor = 0x000000;
			if (compsranges[comp].xmax - compsranges[comp].xmin > maxwidth)
				newcolor = 0x000000;
#if 0
			if (compsranges[comp].ymax - compsranges[comp].ymin < minheight)
				newcolor = 0x000000;
			if (compsranges[comp].ymax - compsranges[comp].ymin > maxheight)
				newcolor = 0x000000;
			if ((compsranges[comp].ymax - compsranges[comp].ymin) >
				(compsranges[comp].xmax - compsranges[comp].xmin) * maxratio)
				newcolor = 0x000000;
			if ((compsranges[comp].xmax - compsranges[comp].xmin) >
				(compsranges[comp].ymax - compsranges[comp].ymin) * maxratio)
				newcolor = 0x000000;
#endif

			r = newcolor & 0xff;
			g = (newcolor >> 8) & 0xff;
			b = (newcolor >> 16) & 0xff;

			*(outptr + xloc + yloc) = r;
			*(outptr + xloc + yloc + 1) = g;
			*(outptr + xloc + yloc + 2) = b;
		}
	}

	printf("result\n");
}

- (void) awakeFromNib
{
	NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/P1180863.JPG";
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

	filter(inputImgBytes, outputImgBytes, width, height, bitsPerPixel);

	[imageView setImage:outImage];
}


- (IBAction)prepare:(id)sender
{
	int bitsPerPixel  = [inImageRep bitsPerPixel];
	int width = [inImageRep pixelsWide];
	int height = [inImageRep pixelsHigh];

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

	prepare(inputImgBytes, outputImgBytes, width, height, bitsPerPixel);

	[imageView setImage:outImage];
}

- (IBAction)calcConnCons:(id)sender
{
	int bitsPerPixel  = [inImageRep bitsPerPixel];
	int width = [inImageRep pixelsWide];
	int height = [inImageRep pixelsHigh];

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

//	prepare(inputImgBytes, outputImgBytes, width, height, bitsPerPixel);
	filter(inputImgBytes, outputImgBytes, width, height, bitsPerPixel);
	binarization(outputImgBytes, outputImgBytes, width, height, bitsPerPixel);

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
	connected(outputImgBytes, outputImg2Bytes, width, height, bitsPerPixel);

	[imageView setImage:outImage];
}


@end
