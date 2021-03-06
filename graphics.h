//
//  graphics.h
//  dsptest1
//
//  Created by Lieven Govaerts on 16/12/12.
//
//

#ifndef dsptest1_graphics_h
#define dsptest1_graphics_h

void lum_convert_to_rgb(const unsigned char *lumbuf, unsigned char *outbuf,
						int width, int height, int bitsPerPixel);
void rgb_convert_to_lum(const unsigned char *inbuf, unsigned char *lumbuf,
						int width, int height, int bitsPerPixel);
void rgb_convert_to_bw_treshold(const unsigned char *inbuf, unsigned char *lumbuf,
                                int width, int height, int bitsPerPixel,
                                int treshold);
void rgb_convert_canny_to_code(const unsigned char *inbuf, unsigned char *lumbuf,
                               int width, int height, int bitsPerPixel);

void histogram(const unsigned char *inbuf, unsigned int *histogram,
               int inleft, int intop,
               int inwidth,
               int boxwidth, int boxheight);

void canny_edge_detection(const unsigned char *inlum, unsigned char *outbuf,
                          int width, int height, int bitsperpixel,
                          double *avg_slope);

void binarization(const unsigned char* inlum, unsigned char* outlum,
                  int inleft, int intop,
                  int inwidth,
                  int boxwidth, int boxheight,
                  int outleft, int outtop,
                  int outwidth);
void binarization_threshold(const unsigned char* inlum, unsigned char* outlum,
                            int inleft, int intop,
                            int inwidth,
                            int boxwidth, int boxheight,
                            int outleft, int outtop,
                            int outwidth,
                            int threshold);
void sobel_edge_detection(const unsigned char *inlum, unsigned char *outlum,
                          int width, int height);
void rotate(const unsigned char *lumbuf, unsigned char *outlum,
            int width, int height, double slope);

#endif
