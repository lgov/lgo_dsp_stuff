//
//  graphics.mm
//  dsptest1
//
//  Created by Lieven Govaerts on 16/12/12.
//
//

#include <stdio.h>
#include "graphics.h"
#include "util.h"

static const int sharpen[3][3]  = { { -1, -1, -1 },
    { -1,  8, -1 },
    { -1, -1, -1 } };

static const int smoothen[3][3]  = { { 1, 1, 1 },
	{ 1, 1, 1 },
	{ 1, 1, 1 } };

static const int LoG[9][9] = {
	{ 0, 1, 1, 2, 2, 2, 1, 1, 0 },
	{ 1, 2, 4, 5, 5, 5, 4, 2, 1 },
	{ 1, 4, 5, 3, 0, 3, 5, 4, 1 },
	{ 2, 5, 3, -12, -24, -12, 3, 5, 2 },
	{ 2, 5, 0, -24, -40, -24, 0, 5, 2 },
	{ 2, 5, 3, -12, -24, -12, 3, 5, 2 },
	{ 1, 4, 5, 3, 0, 3, 5, 4, 1 },
	{ 1, 4, 5, 3, 0, 3, 5, 4, 1 },
	{ 0, 1, 1, 2, 2, 2, 1, 1, 0 } };

static const int Gaussian[5][5] = {
    { 1, 4, 7, 4, 1 },
    { 4, 16, 26, 16, 4 },
    { 7, 26, 41, 26, 7 },
    { 4, 16, 26, 16, 4 },
    { 1, 4, 7, 4, 1 },
};
static const int GaussianDivider = 273;

static const int SobelHorizontal[3][3] = {
    { -1, 0, +1 },
    { -2, 0, +2 },
    { -1, 0, +1 },
};

static const int SobelVertical[3][3] = {
    { +1, +2, +1 },
    {  0,  0,  0 },
    { -1, -2, -1 },
};

void rgb_convert_to_lum(const unsigned char *inbuf, unsigned char *lumbuf,
						int width, int height, int bitsPerPixel)
{
	int rowPixels = width * bitsPerPixel / 8;

	for (int y = 0; y < height; y++) {
		int yloc = y * rowPixels;
		unsigned char *lumptr = lumbuf + y * width;

		for (int x = 0; x < width; x++) {
			int xloc = x * bitsPerPixel / 8;

			const unsigned char *curin = inbuf + yloc + xloc;

			unsigned char r = *curin++, g = *curin++, b = *curin++;
			// calculate luminance from rgb
			float lum = 0.3 * r + 0.59 * g + 0.11 * b;

			*lumptr++ = lum; // r
		}
	}
}

void lum_convert_to_rgb(const unsigned char *lumbuf, unsigned char *outbuf,
						int width, int height, int bitsPerPixel)
{
	int rowPixels = width * bitsPerPixel / 8;

	for (int y = 0; y < height; y++) {
		int yloc = y * rowPixels;
		const unsigned char *lumptr = lumbuf + y * width;

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

void histogram(const unsigned char *inbuf, unsigned int *histogram,
               int inleft, int intop,
               int inwidth,
               int boxwidth, int boxheight)
{
    memset(histogram, 0, 256 * sizeof(unsigned int));

	for (int y = 0; y < boxheight; y++) {
		for (int x = 0; x < boxwidth; x++) {
			const unsigned char *curin = inbuf + (intop + y) * inwidth + (x + inleft);

            (*(histogram+(unsigned int)*curin))++;
        }
    }
}

void rgb_convert_to_bw_treshold(const unsigned char *inbuf, unsigned char *lumbuf,
                                int width, int height, int bitsPerPixel,
                                int treshold)
{
	int rowPixels = width * bitsPerPixel / 8;

	for (int y = 0; y < height; y++) {
		int yloc = y * rowPixels;
		unsigned char *lumptr = lumbuf + y * width;

		for (int x = 0; x < width; x++) {
			int xloc = x * bitsPerPixel / 8;

			const unsigned char *curin = inbuf + yloc + xloc;

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
void convolution(const unsigned char *lumin, int *outptr,
                 int x, int y,
                 int width, int height,
                 int *matrix, int matrixSize,
                 int matrix_divider,
                 int *min, int *max)
{
	int offset = matrixSize / 2;  // should be 1 for a matrix of size 3.
	const unsigned char *incur;
    int lum = 0;

	// calculate convolution of one pixel!
	for (int i = 0; i < matrixSize; i++) {
		int yloc = (y + (i - offset)) * width;
		if (yloc < 0 || (y + (i - offset)) >= height) {
            yloc = (y + ((matrixSize / 2) - offset)) * width;
        }

		for (int j= 0; j < matrixSize; j++) {
			int xloc = x + (j - offset);
			if (xloc < 0 || (x + (j - offset)) >= width) {
                xloc = x + ((matrixSize / 2) - offset);
            }

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

void convolution_in_range(const unsigned char *lumin, unsigned char *lumout,
                          int x, int y,
                          int width, int height,
                          int *matrix, int matrixSize,
                          int matrix_divider)
{
	int offset = matrixSize / 2;  // should be 1 for a matrix of size 3.
	const unsigned char *incur;
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

void gaussian_blur(const unsigned char *inlum, unsigned char *outlum,
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

void sobel_edge_detection(const unsigned char *inlum, unsigned char *outlum,
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

typedef enum canny_codes_t {
    black = 0,
    yellow = 1,
    red = 2,
    green = 3,
    blue = 4
} canny_codes_t;

void rgb_convert_canny_to_code(const unsigned char *inbuf, unsigned char *lumbuf,
                               int width, int height, int bitsPerPixel)
{
	int rowPixels = width * bitsPerPixel / 8;

	for (int y = 0; y < height; y++) {
		int yloc = y * rowPixels;
		unsigned char *lumptr = lumbuf + y * width;

		for (int x = 0; x < width; x++) {
			int xloc = x * bitsPerPixel / 8;

			const unsigned char *curin = inbuf + yloc + xloc;

			unsigned char r = *curin++, g = *curin++, b = *curin++;
            canny_codes_t code;

            if (b == 255)
                code = blue;
            else if (r == 255 && g == 255)
                code = yellow;
            else if (r == 255)
                code = red;
            else if (g == 255)
                code = green;
            else
                code = black;

			*lumptr++ = (unsigned char)code;
		}
	}
}

// http://dasl.mem.drexel.edu/alumni/bGreen/www.pages.drexel.edu/_weg22/can_tut.html
void canny_edge_detection(const unsigned char *inlum, unsigned char *outbuf,
                          int width, int height, int bitsperpixel,
                          double *avg_slope)
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
    double slope = 0, slope_y = 0, slope_r = 0, slope_g = 0, slope_b = 0;
    long cur_y = 0, cur_r = 0, cur_g = 0, cur_b = 0;

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

                /* Calculate the general slope of the image:
                   Take the average angle for each major orientation.
                 */
                // assign edge to range
                if (((edge_dir < 22.5) && (edge_dir > -22.5)) || (edge_dir > 157.5) || (edge_dir < -157.5)) {
                    edge_dir += 270; edge_dir = fmod(edge_dir, 180);
                    slope_y = ((slope_y * cur_y) + edge_dir) / (++cur_y);
                    edge_dir = 0;
                    *outptr++ = 255; *outptr++ = 255; *outptr++ = 0; *outptr = 0; // yellow
                } else if (((edge_dir > 22.5) && (edge_dir < 67.5)) || ((edge_dir < -112.5) && (edge_dir > -157.5))) {
                    edge_dir = 45;
                    *outptr++ = 0; *outptr++ = 255; *outptr++ = 0; *outptr = 0; // green
                } else if (((edge_dir > 67.5) && (edge_dir < 112.5)) || ((edge_dir < -67.5) && (edge_dir > -112.5))) {
                    if (edge_dir > 0) edge_dir = edge_dir; // do nothing
                    else edge_dir = 180 + edge_dir;
                    slope_b = ((slope_b * cur_b) + edge_dir) / (++cur_b);
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

    /* calculate slope as angle where positive = from 0 (right) to bottom. */
    slope_y -= 90; slope_b -= 90;
    if (slope_y * slope_b > 0 &&      // same sign?
        abs(slope_b - slope_y) < 2)
    {
        slope = ((slope_y * cur_y) + (slope_b * cur_b)) / (cur_y + cur_b);
        dsptest_log(1, __FILE__, "Uniform slope found: %f (%f,%f)\n", slope, slope_y, slope_b);
        *avg_slope = slope;
    } else {
        *avg_slope = -1000;
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

void binarization_threshold(const unsigned char* inlum, unsigned char* outlum,
                            int inleft, int intop,
                            int inwidth,
                            int boxwidth, int boxheight,
                            int outleft, int outtop,
                            int outwidth,
                            int threshold)
{
    const unsigned char *curin;
    unsigned char *curout;

    for (int y = 0; y < boxheight; y++) {
		for (int x = 0; x < boxwidth; x++) {

			curin = inlum + (((y + intop) * inwidth) + (x + inleft));
			curout = outlum + (((y + outtop) * outwidth) + (x + outleft));

            unsigned char lum = *curin;

            if (lum >= threshold)
                *curout = 255;
            else
                *curout = 0;
		}
	}
}

void binarization(const unsigned char* inlum, unsigned char* outlum,
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
void prepare(const unsigned char *inlum, unsigned char *outlum,
             int width, int height, int bitsPerPixel)
{
	unsigned char lum, prevlum;
	const unsigned char* cur;
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

void
rotate(const unsigned char *lumbuf, unsigned char *outlum,
       int width, int height, double slope)
{
    double angle = slope * M_PI / 180;
    double ca = cos(angle); double sa = sin(angle);

	for (int y = 0; y < height; y++) {
		int yloc = y * width;

		for (int x = 0; x < width; x++) {
			unsigned char *curout = outlum + yloc + x;
            int lx = x * ca - y * sa;
            int ly = x * sa + y * ca;

            const unsigned char *lumptr = lumbuf + ly * width + lx;

            if (lx < 0 || lx >= width || ly < 0 || ly >= height)
                *curout = 255;
            else
                *curout = *lumptr;
        }
    }
}
