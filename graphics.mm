//
//  graphics.mm
//  dsptest1
//
//  Created by Lieven Govaerts on 16/12/12.
//
//

#include <stdio.h>
#include "graphics.h"
// #include "util.h"

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

void rgb_convert_to_bw_treshold(unsigned char *inbuf, unsigned char *lumbuf,
                                int width, int height, int bitsPerPixel,
                                int treshold)
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
            
            if (lum > treshold)
                *lumptr++ = 255;
            else
                *lumptr++ = 0;
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

    // possible method to choose tresholds:
    // http://www.kerrywong.com/2009/05/07/canny-edge-detection-auto-thresholding/
    int low_treshold = 20;
	int high_treshold = 200;

    // step 1: gaussian blur
    //    templum = inlum;
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
            if (strength > low_treshold) {
                // edge direction
                if (Gx == 0 && Gy == 0) {
                    edge_dir = 0;
                }
                edge_dir = atan2(Gx, Gy) * 180 / PI;

                // assign edge to range
                if (((edge_dir < 22.5) && (edge_dir > -22.5)) || (edge_dir > 157.5) || (edge_dir < -157.5)) {
                    edge_dir = 0;
                    *outptr++ = 255; *outptr++ = 255; *outptr++ = 0; *outptr = 0; // yellow
                } else if (((edge_dir > 22.5) && (edge_dir < 67.5)) || ((edge_dir < -112.5) && (edge_dir > -157.5))) {
                    edge_dir = 45;
                    *outptr++ = 0; *outptr++ = 255; *outptr++ = 0; *outptr = 0; // green
                } else if (((edge_dir > 67.5) && (edge_dir < 112.5)) || ((edge_dir < -67.5) && (edge_dir > -112.5))) {
                    edge_dir = 90;
                    *outptr++ = 0; *outptr++ = 0; *outptr++ = 255; *outptr = 0; // blue
                } else if (((edge_dir > 112.5) && (edge_dir < 157.5)) || ((edge_dir < -22.5) && (edge_dir > -67.5))) {
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
    for (int y = 1; y < height - 1; y++) {
		for (int x = 1; x < width -1; x++) {
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

    // step 4: tresholding +
    // step 5: edge tracking by hysteris: following the edge, enhance all edges above the low threshold.
    int nr_iters = 1;
    for (int i = 0; i < nr_iters; i++) {
        for (int y = 1; y < height - 1; y++) {
            for (int x = 1; x < width -1; x++) {
                strengthptr = strengths + y * width + x;
                gradptr = gradiants + y * width + x;
                outptr = outbuf + y * (width * bitsperpixel / 8) + x * (bitsperpixel / 8);

                if (*strengthptr < low_treshold) {
                    strength = 0;
                } else if (*strengthptr > high_treshold) {
                    strength = 255;
                } else {
                    if (i == nr_iters - 1)
                        strength = 0;
                    else {
                        strength = *strengthptr;
                    }
                    // not so strong edge, only keep it when connected to strong edge.
                    int strong_lefttop = *(strengths + (y-1) * width + x - 1) > high_treshold;
                    int strong_top = *(strengths + (y-1) * width + x) > high_treshold;
                    int strong_righttop = *(strengths + (y-1) * width + x + 1) > high_treshold;
                    int strong_left = *(strengths + y * width + x - 1) > high_treshold;
                    int strong_right = *(strengths + y * width + x + 1) > high_treshold;
                    int strong_leftbottom = *(strengths + (y+1) * width + x - 1) > high_treshold;
                    int strong_bottom = *(strengths + (y+1) * width + x) > high_treshold;
                    int strong_rightbottom = *(strengths + (y+1) * width + x + 1) > high_treshold;
                    switch (*gradptr) {
                        case 0: {
                            if (strong_lefttop || strong_left || strong_leftbottom || strong_right ||
                                strong_rightbottom || strong_righttop) {
                                strength = 255;
                            }
                            break;
                        }

                        case 45: {
                            if (strong_lefttop || strong_left || strong_top || strong_right ||
                                strong_rightbottom || strong_bottom) {
                                strength = 255;
                            }
                            break;
                        }

                        case 90: {
                            if (strong_lefttop || strong_top || strong_righttop || strong_leftbottom ||
                                strong_bottom || strong_rightbottom ) {
                                strength = 255;
                            }
                            break;
                        }

                        case 135: {
                            if (strong_leftbottom || strong_left || strong_top || strong_right ||
                                strong_righttop || strong_bottom) {
                                strength = 255;
                            }
                            break;
                        }

                        default:
                            break;
                    }
                }
                *strengthptr = strength;
                if (strength == 0) {
                    *outptr++ = 0; *outptr++ = 0; *outptr++ = 0; *outptr = 0;
                }
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