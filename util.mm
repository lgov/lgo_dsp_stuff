//
//  util.c
//  dsptest1
//
//  Created by Lieven Govaerts on 14/12/12.
//
//

#include <stdarg.h>
#include <stdio.h>

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
