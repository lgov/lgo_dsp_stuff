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

// both x and y in bytes.
void convolution(unsigned char *inptr, unsigned char *outptr, int x, int y, int width, int height, int bitsPerPixel,
				 float *matrix)
{
	unsigned char *cur;
	float r=0, g=0, b=0;
	int matrixSize = 3;
	int rowPixels = width * bitsPerPixel / 8;

	int offset = matrixSize / 2;  // should be 1 for a matrix of size 3.

	for (int i = 0; i < matrixSize; i++) {
		int yloc = y + ((i - offset) * rowPixels);
		if (yloc < 0) continue;

		for (int j= 0; j < matrixSize; j++) {
			int xloc = x + ((j - offset) * bitsPerPixel / 8);
			if (xloc < 0) continue;

			cur = inptr + yloc + xloc;

			float m = *(matrix + i * matrixSize + j);
			r += (float)(*cur++) * m;
			g += (float)(*cur++) * m;
			b += (float)(*cur++) * m;
		}
	}
	cur = outptr + x + y;
	if (r < 0) r = 0; 	if (g < 0) g = 0; 	if (b < 0) b = 0;
	if (r > 255) r = 255; if (g > 255) g = 255; if (b > 255) b = 255;

	*cur++ = r; *cur++ = g; *cur++ = b; *cur++ = 0;
}

void filter(unsigned char *inptr, unsigned char *outptr, int width, int height, int bitsPerPixel)
{
	for (int y = 0; y < height; y++) {
		for (int x = 0; x < width; x++) {
			int xloc = x * bitsPerPixel / 8;
			int yloc = y * width * bitsPerPixel / 8;
			convolution(inptr, outptr, xloc, yloc, width, height, bitsPerPixel,
						sharpen);
		}
	}
}

#define T 1000
#define SHADES 128

void prepare(unsigned char *inptr, unsigned char *outptr, int width, int height, int bitsPerPixel)
{
	int r,g,b;
	int prevr,prevg,prevb;
	unsigned char* cur;
	int prevcolor, curcolor;
	int newcolor = 255;

	for (int y = 0; y < height; y++) {
		int yloc = y * width * bitsPerPixel / 8;

		for (int x = 1; x < width; x++) {
			int xloc = x * bitsPerPixel / 8;
			int prevxloc = (x - 1) * bitsPerPixel / 8;

			cur = inptr + yloc + prevxloc;
			prevr = *cur++; prevg = *cur++; prevb = *cur++; cur++;
			prevcolor = (prevr * prevr + prevg * prevg + prevb * prevb);

			r = *cur++; g = *cur++; b = *cur++; cur++;
			curcolor = (r * r + g * g + b * b);

			if (abs((prevr-r)^2 + (prevg-g)^2 + (prevb-b) ^2) < T * T) {
				newcolor = ((prevr+prevg+prevb) / SHADES) * SHADES / 3; // (newcolor==255?0:255);
			} else
			{
				newcolor = ((r+g+b) / SHADES) * SHADES / 3; // (newcolor==255?0:255);
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

void connected(unsigned char *inptr, unsigned char *outptr, int width, int height, int bitsPerPixel)
{
	int r,g,b;
	int prevr,prevg,prevb;
	unsigned char* cur;
	int prevcolor, curcolor;
	int newcolor = 0x080808;

	for (int y = 0; y < height; y++) {
		int yloc = y * width * bitsPerPixel / 8;

		for (int x = 1; x < width; x++) {
			int xloc = x * bitsPerPixel / 8;
			int prevxloc = (x - 1) * bitsPerPixel / 8;

			cur = inptr + yloc + prevxloc;
			prevr = *cur++; prevg = *cur++; prevb = *cur++; cur++;
			prevcolor = (prevr * prevr + prevg * prevg + prevb * prevb);

			r = *cur++; g = *cur++; b = *cur++; cur++;
			curcolor = (r * r + g * g + b * b);

			if (curcolor - prevcolor < T) {
				newcolor += 17;
			}

			r = newcolor % 0xff;
			g = (newcolor >> 8) % 0xff;
			b = (newcolor >> 17) % 0xff;

			*(outptr + xloc + yloc) = r;
			*(outptr + xloc + yloc + 1) = g;
			*(outptr + xloc + yloc + 2) = b;
		}
	}
}

- (IBAction)loadImage:(id)sender
{
	NSString* imageName = @"/Users/lgo/macdev/ProjectNrOne/tvgids-fotos/P1180863.JPG";
	image = [[NSImage alloc] initWithContentsOfFile:imageName];

	NSData* fileData = [NSData dataWithContentsOfFile:imageName];
	NSBitmapImageRep* inImageRep = [NSBitmapImageRep
						  		    imageRepWithData:fileData];
	if (inImageRep){
		NSImage* inImage = [[[NSImage alloc] init] autorelease];
		[inImage addRepresentation:inImageRep];

		inputImgBytes = [inImageRep bitmapData];
		int bitsPerPixel  = [inImageRep bitsPerPixel];
		int width = [inImageRep pixelsWide];
		int height = [inImageRep pixelsHigh];

		NSBitmapImageRep *outImageRep = [[NSBitmapImageRep alloc]
										 initWithBitmapDataPlanes:NULL
										 pixelsWide:width
										 pixelsHigh:height
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
//		filter(inputImgBytes, outputImgBytes, width, height, bitsPerPixel);

		prepare(inputImgBytes, outputImgBytes, width, height, bitsPerPixel);

		NSBitmapImageRep *outImage2Rep = [[NSBitmapImageRep alloc]
										 initWithBitmapDataPlanes:NULL
										 pixelsWide:width
										 pixelsHigh:height
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
		[imageView setImage:outImage2];
	}
}

- (IBAction)calcEdge:(id)sender;
{

}

@end
