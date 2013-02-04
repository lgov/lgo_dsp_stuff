//
//  load_ratings.c
//  load_ratings
//
//  Created by Lieven Govaerts on 26/01/13.
//  Copyright (c) 2013 Lieven Govaerts. All rights reserved.
//

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#include "load_ratings.h"

int main(void)
{
    size_t size = 1024;
    char *line = (char*)malloc(size);
    char votes[10];
    char name[256];
    char score[10];
    size_t bytes_read;
    int phase = 0;

    /* Open sqlite db */
    store_sqlite3_t *db = store_sqlite3_init("/tmp/ramdisc/ratings");

    while (phase < 2 && getline(&line, &size, stdin) != -1)
    {
        switch (phase) {
            case 0: if (strcasestr(line, "MOVIE RATINGS REPORT"))
                phase = 1;
                break;
            case 1: phase = 2;
                break;
        }
    }

    while ((bytes_read = getline(&line, &size, stdin)) != -1)
    {
        /* |New  Distribution  Votes  Rank  Title */
        /* |      1000000103      55   4.5  "#1 Single" (2006) */
        if (bytes_read > 35)
        {
            strncpy(votes, line + 17, 7);
            strncpy(score, line + 25, 5);
            strncpy(name, line + 32, 255);

            int len = strlen(name);
            char *ptr = name + len - 1;
            while (*ptr == '\r' || *ptr == '\n')
                *ptr-- = '\0';


            store_sqlite3_movie(db, atoi(votes), atof(score), name);
            printf("found: %d,%f,%s\n", atoi(votes), atof(score), name);
        }
    }

    store_sqlite3_close(db);
    
    return 0;
}
