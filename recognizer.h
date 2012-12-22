//
//  recognizer.h
//  dsptest1
//
//  Created by Lieven Govaerts on 22/12/12.
//
//

#import <Cocoa/Cocoa.h>

@interface recognizer : NSObject {
    tessocr* ocr;
}
- (NSArray *)recognize:(const unsigned char *)inlum
                 width:(int)width
                height:(int)height;
-(id)init;
-(void)dealloc;

@end
