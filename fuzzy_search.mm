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

        if (str->similarity > ws->similarity)
            break;

        if ((str->similarity == ws->similarity) &&
            (str->weight > ws->weight))
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
        weighted_str_t *wstr = [[weighted_str_t alloc] init];
        wstr->str = str; wstr->strid = (long)str;
        wstr->weight = weight;
        wstr->ngram = ng;

        NSMutableArray *strings = [ngrams objectForKey:ng];
        if (strings == nil)
        {
            strings = [[NSMutableArray alloc] init];
            [ngrams setObject:strings forKey:ng];
        }
        /* Ordered insert */
        [self ordered_insert:strings wstr:wstr];
    }
}

static const int top_k = 1;

-(int)required_freq_treshold:(NSArray*)top_list
{
    if ([top_list count] < top_k)
        return 1;

    weighted_str_t *last = [top_list objectAtIndex:[top_list count]-1];
    return last->similarity;
}

-(void)push_next_elements_to_heap:(NSArray *)str_ngrams
                       pop_ngrams:(NSMutableArray *)pop_ngrams
                          minimum:(weighted_str_t *)minimum
                             heap:(NSMutableArray *)heap
{
    NSArray *ngrams_to_pop = pop_ngrams ? pop_ngrams : str_ngrams;

    /* Insert the top element on each list to the heap */
    for (NSString *ng in ngrams_to_pop)
    {
        NSMutableArray *ar = [ngrams objectForKey:ng];
        weighted_str_t *wstr;

        if (ar == nil || [ar count] == 0)
            continue; /* no more strings for this ngram */

        if (minimum)
        {
            /* find elements to skip and remove them from the ngram stack */
            int elems_to_skip;
            for (elems_to_skip = 0; elems_to_skip < [ar count]; elems_to_skip++)
            {
                wstr = [ar objectAtIndex:0];
                if (wstr->weight <= minimum->weight)
                    break;
            }
            for (int j=0;j < elems_to_skip; j++)
                [ar removeObjectAtIndex:0];
        }

        /* Remove the element from the stack and return to the caller. */
        if ([ar count] > 0)
        {
            wstr = [ar objectAtIndex:0];

            printf(" %s:%s\n", [ng UTF8String], [wstr->str UTF8String]);

            wstr = [ar objectAtIndex:0];
            [self ordered_insert:heap wstr:wstr];
            [ar removeObjectAtIndex:0];
        }
    }

    /* All ngrams replenished. */
    if (pop_ngrams)
        [pop_ngrams removeAllObjects];
}

-(weighted_str_t*)find_string:(NSString *)fs
{
    NSArray *str_ngrams = [self str_to_ngrams:fs];

    NSMutableArray *top_list = [[NSMutableArray alloc] init];
    NSMutableArray *string_heap = [[NSMutableArray alloc] init];

    /* Setup the initial heap with one element from each matching ngram. */
    [self push_next_elements_to_heap:str_ngrams
                          pop_ngrams:NULL
                             minimum:NULL
                                heap:string_heap];

    int freq_treshold = 1;

    /* TODO: take care of same ngram multiple times in string */
    while ([string_heap count] > 0 && freq_treshold < [str_ngrams count])
    {
        /* Take the top element, and count the number of appearances on the heap */
        int p = 1;
        weighted_str_t *top = [string_heap objectAtIndex:(NSUInteger)0];
        NSMutableArray *top_ngrams = [[NSMutableArray alloc] init];
        [top_ngrams addObject:top->ngram];

        printf("heap:");
        for (weighted_str_t *s in string_heap)
            printf("%s(%d),", [s->str UTF8String], s->weight);
        printf("\n");

        /* Pop all elements equal to the top element */
        for (int i = 1; i < [string_heap count]; i++)
        {
            weighted_str_t *s = [string_heap objectAtIndex:(NSUInteger)i];
            if (s->strid!= top->strid)
                break;

            [top_ngrams addObject:s->ngram];
            p++;
        }

        for (int i = 0; i<p; i++)
            [string_heap removeObjectAtIndex:(NSUInteger)0];

        /* */
        if  (p >= freq_treshold)
        {
            top->similarity = p;
            [self ordered_insert:top_list wstr:top];

            if ([top_list count] > top_k)
                [top_list removeObjectAtIndex:[top_list count] - 1];

            freq_treshold = [self required_freq_treshold:top_list];

            /* From each matching ngram list that has element top, pop it and then
             add the next element of that ngram list to the heap. */
            [self push_next_elements_to_heap:str_ngrams
                                  pop_ngrams:top_ngrams
                                     minimum:NULL
                                        heap:string_heap];

        } else
        {
            /* Pop additional freq_treshold - p - 1 elements from heap */
            int c = freq_treshold - p - 1;
            for (int i = 0; i < c; i++) {
                if ([string_heap count] == 0)
                    break;

                weighted_str_t *top = [string_heap objectAtIndex:(NSUInteger)0];
                [top_ngrams addObject:top->ngram];

                [string_heap removeObjectAtIndex:(NSUInteger)0];
            }

            if ([string_heap count] == 0)
                break; /* early exit, not enough unique ngrams left */

            top = [string_heap objectAtIndex:(NSUInteger)0];
            [self push_next_elements_to_heap:str_ngrams
                                  pop_ngrams:top_ngrams
                                     minimum:top
                                        heap:string_heap];
        }
    }

    if ([top_list count] == 0)
        return NULL;

    weighted_str_t *wstr = [top_list objectAtIndex:(NSUInteger)0];

    return wstr;
}
@end