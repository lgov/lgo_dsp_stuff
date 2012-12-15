//
//  util.h
//  dsptest1
//
//  Created by Lieven Govaerts on 14/12/12.
//
//

#ifndef dsptest1_util_h
#define dsptest1_util_h

#define LOG_BB 1
#define LOG_OCR 1

void dsptest_log(int verbose_flag, const char *filename, const char *fmt, ...);

void lum_convert_to_rgb(unsigned char *lumbuf, unsigned char *outbuf,
						int width, int height, int bitsPerPixel);
void rgb_convert_to_lum(unsigned char *inbuf, unsigned char *lumbuf,
						int width, int height, int bitsPerPixel);
void rgb_convert_to_bw_treshold(unsigned char *inbuf, unsigned char *lumbuf,
                                int width, int height, int bitsPerPixel,
                                int treshold);
void histogram(unsigned char *inbuf, unsigned int *histogram,
               int inleft, int intop,
               int inwidth,
               int boxwidth, int boxheight);

#endif
