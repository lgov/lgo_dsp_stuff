//
//  fuzzy_search.h
//  dsptest1
//
//  Created by Lieven Govaerts on 20/01/13.
//
//

#import <Cocoa/Cocoa.h>
#import "fuzzy_search_db.h"

@interface weighted_str_t : NSObject {
@public     // TODO: change all these to properties
	NSString *str;
    long strid;
    int weight;
    int similarity;
    NSString *ngram;
}
@end

@interface fuzzy_search : NSObject {
    NSMutableDictionary *ngrams;
}
-(id)init;

-(void)dealloc;
-(void)load_string:(NSString *)str
            weight:(int)weight;
-(void)load_ngram_string:(NSString *)ngram
                     str:(NSString *)str
                  weight:(int)weight;
-(weighted_str_t*)find_string:(NSString *)fs;

@end
