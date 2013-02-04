//
//  sqlite_store.h
//  dsptest1
//
//  Created by Lieven Govaerts on 23/01/13.
//
//

#import <Cocoa/Cocoa.h>

#include <sqlite3.h>

@class weighted_str_t;

@interface fuzzy_search_db : NSObject {
    sqlite3 *db;
}

-(id)init_db:(NSString *)db_name;
-(NSArray*)find_best_matching_movies:(NSString *)movie
                                topk:(int)topk;

@end
