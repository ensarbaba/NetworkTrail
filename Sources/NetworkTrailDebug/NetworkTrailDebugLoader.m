#import <Foundation/Foundation.h>

extern void NetworkTrailDebugStartFromLoad(void);

@interface NetworkTrailDebugLoader : NSObject
@end

@implementation NetworkTrailDebugLoader

+ (void)load {
    // Dyld still holds its lock here. start() opens Core Data, which dlopens again.
    // Hop to the main queue so that runs after this load returns.
    dispatch_async(dispatch_get_main_queue(), ^{
        NetworkTrailDebugStartFromLoad();
    });
}

@end
