//
//  sqlite_store.m
//  dsptest1
//
//  Created by Lieven Govaerts on 23/01/13.
//
//

#import "fuzzy_search_db.h"
#import "fuzzy_search.h"

@implementation fuzzy_search_db
-(id)init_db:(NSString *)db_name
{
    if (self = [super init])
    {
        int rc;
        rc = sqlite3_open([db_name UTF8String], &db);
        if(rc)
        {
            fprintf(stderr, "Can't open database: %s\n", sqlite3_errmsg(db));
            sqlite3_close(db);
            exit(1);
        }
    }

    return self;
}

-(void)dealloc
{
    if (db)
        sqlite3_close(db);

    [super dealloc];
}

-(NSArray*) str_to_ngrams:(NSString *)str
{
    NSMutableArray *results = [[NSMutableArray alloc] init];
    str = [str lowercaseString];
    int ngramlen = (int)[str length];
    ngramlen = ngramlen < 3 ? ngramlen : 3;
    
    for (int i = 0;i <= (int)[str length] -3; i++)
    {
        NSString *ngram3 = [str substringWithRange:NSMakeRange(i, ngramlen)];
        [results addObject:ngram3];
    }
    return results;
}

static const char* top_movie_query = "select movies.name, count(*) as match from ngrams,movies where " \
    "ngram in ('@@') "\
    "and movies.id=ngrams.movie  group by movie order by match desc limit 10;";

-(NSArray*)find_best_matching_movies:(NSString *)movie
                                topk:(int)topk
{
    NSArray *ngrams = [self str_to_ngrams:movie];
    NSString *query = [[NSString alloc] initWithUTF8String:top_movie_query];
    NSString *values = [ngrams componentsJoinedByString:@"','"];
    query = [query stringByReplacingOccurrencesOfString:@"@@"
                                             withString:values];

    sqlite3_stmt *find_movie_stmt;
    int rc = sqlite3_prepare_v2(db, [query UTF8String], [query length],
                                &find_movie_stmt, NULL);
    if (rc)
        return nil;

    NSMutableArray *toplist = [[NSMutableArray alloc] init];
    for (int i=0; i<topk; i++)
    {
        if (sqlite3_step(find_movie_stmt) != SQLITE_ROW)
            break;

        char *name = (char *)sqlite3_column_text(find_movie_stmt, 0);
//        double score = sqlite3_column_double(find_movie_stmt, 1);

        [toplist addObject:[NSString stringWithFormat:@"%s", name]];
    }
    
    return toplist;
}
@end
