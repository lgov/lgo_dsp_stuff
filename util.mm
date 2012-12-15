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