//
//  fuzzy_search.c
//  dsptest1
//
//  Created by Lieven Govaerts on 20/01/13.
//
//

#import "fuzzy_search.h"

@implementation weighted_str_t

@end

@implementation fuzzy_search
-(id)init
{
    if (self = [super init])
    {
        ngrams = [NSMutableDictionary dictionary];
    }

    return self;
}

-(void)dealloc
{
    [ngrams dealloc];

    [super dealloc];
}

-(NSArray*) str_to_ngrams:(NSString *)str
{
    NSMutableArray *results = [[NSMutableArray alloc] init];

    for (int i = 0;i <= [str length] -3; i++)
    {
        NSString *ngram3 = [str substringWithRange:NSMakeRange(i, 3)];
        [results addObject:ngram3];
    }
    return results;
}

-(void) ordered_insert:(NSMutableArray*)strings
                  wstr:(weighted_str_t *)str
{
    int index = 0;
    if (!str)
        return;
    for(index = 0; index < [strings count]; index++)
    {
        weighted_str_t *ws = [strings objectAtIndex:index];

        if (ws->weight > str->weight)
            break;
    }
    [strings insertObject:str atIndex:index];
}

-(void)load_string:(NSString *)str
            weight:(int)weight
{
    /* Add all ngrams of the string in the ngrams dictionary */
    NSArray *str_ngrams = [self str_to_ngrams:str];

    for (NSString *ng in str_ngrams)
    {
        NSMutableArray *strings = [ngrams objectForKey:ng];
        if (strings == nil)
        {
            strings = [[NSMutableArray alloc] init];
            [ngrams setObject:strings forKey:ng];
        }
        /* Ordered insert */
        weighted_str_t *wstr = [[weighted_str_t alloc] init];
        wstr->str = str; wstr->weight = weight;
        [self ordered_insert:strings wstr:wstr];
    }
}

static const int top_k = 5;

-(int)required_freq_treshold:(NSArray*)top_list
{
    if ([top_list count] <= top_k)
        return 1;
    /* fix */
    return 1000;
}

-(void)push_next_elements_to_heap:(NSArray *)str_ngrams
                          pop_str:(weighted_str_t *)pop_str
                             heap:(NSMutableArray *)heap
{
    /* Insert the top element on each list to the heap */
    for (NSString *ng in str_ngrams)
    {
        NSMutableArray *ar = [ngrams objectForKey:ng];
        if (ar == nil)
            continue; /* this ngram was found in no single string */

        weighted_str_t *str = [ar objectAtIndex:0];
        if ((pop_str == NULL) ||
            (pop_str != NULL && str == pop_str))
        {
            /* Initial setup or this string was handled, move to the next */
            if (pop_str)
                [ar removeObjectAtIndex:0];
            
            if ([ar count] > 0) {
                str = [ar objectAtIndex:0];
                [self ordered_insert:heap wstr:str];
            }
        }
    }
}

-(weighted_str_t*)find_string:(NSString *)fs
{
    NSArray *str_ngrams = [self str_to_ngrams:fs];

    NSMutableArray *top_list = [[NSMutableArray alloc] init];
    NSMutableArray *string_heap = [[NSMutableArray alloc] init];

    /* Setup the initial heap with one element from each matching ngram. */
    [self push_next_elements_to_heap:str_ngrams
                             pop_str:NULL
                                heap:string_heap];

    int freq_treshold = 1;

    /* */
    while ([string_heap count] > 0)
    {
        /* Take the top element, and count the number of appearances on the heap */
        int p = 1;
        weighted_str_t *top = [string_heap objectAtIndex:(NSUInteger)0];

        /* Pop all elements equal to the top element */
        for (weighted_str_t *s in string_heap) {
            if (p == 1) {
                top = s;
                continue;
            }
            if (s == top) {
                p++;
                continue;
            }
            break;
        }

        /* */
        if  (p >= freq_treshold)
        {
            if ([top_list count] > 0) {
                weighted_str_t *last = [top_list objectAtIndex:[top_list count] - 1];

                int weight_top = top->weight;
                int weight_last = last->weight;

                if (weight_top > weight_last) {
                    [top_list removeObjectAtIndex:[top_list count] - 1];
                }
            }
            [self ordered_insert:top_list wstr:top];

            freq_treshold = [self required_freq_treshold:top_list];
        }

        for (int i = 0; i<p; i++)
            [string_heap removeObjectAtIndex:(NSUInteger)0];

        /* From each matching ngram list that has element top, pop it and then
           add the next element of that ngram list to the heap. */
        [self push_next_elements_to_heap:str_ngrams
                                 pop_str:top
                                    heap:string_heap];


        
    }

    if ([top_list count] > 0)
        return ([top_list objectAtIndex:(NSUInteger)0]);
    else
        return NULL;
}
@end