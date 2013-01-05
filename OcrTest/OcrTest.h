//
//  OcrTest.h
//  OcrTest
//
//  Created by Lieven Govaerts on 20/12/12.
//
//

#import <SenTestingKit/SenTestingKit.h>

@interface OcrTest : SenTestCase {
    NSMutableDictionary *editDistances;
}
- (int) calc_editDistance:(NSString *)a
                        b:(NSString *)b;
@end