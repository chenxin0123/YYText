//
//  YYTextRunDelegate.m!
//  YYText <https://github.com/ibireme/YYText>
//
//  Created by ibireme on 14/10/14.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "YYTextRunDelegate.h"

///CTFramesetterCreateWithAttributedString将会调用下列方法
//!
static void DeallocCallback(void *ref) {
    ///__bridge_transfer将一个被__bridge_retain的C指针转换为arc管理的对象
    YYTextRunDelegate *self = (__bridge_transfer YYTextRunDelegate *)(ref);
    self = nil; // release
}
//!
static CGFloat GetAscentCallback(void *ref) {
    YYTextRunDelegate *self = (__bridge YYTextRunDelegate *)(ref);
    return self.ascent;
}
//!
static CGFloat GetDecentCallback(void *ref) {
    YYTextRunDelegate *self = (__bridge YYTextRunDelegate *)(ref);
    return self.descent;
}
//!
static CGFloat GetWidthCallback(void *ref) {
    YYTextRunDelegate *self = (__bridge YYTextRunDelegate *)(ref);
    return self.width;
}
//!
@implementation YYTextRunDelegate
//!
- (CTRunDelegateRef)CTRunDelegate CF_RETURNS_RETAINED {
    //使用CTRunDelegateCreate可以创建一个CTRunDelegate，它接收两个参数，一个是callbacks结构体，一个是所有callback调用的时候需要传入的对象。
    // callbacks的结构体为CTRunDelegateCallbacks，主要是包含一些回调函数，比如有返回当前run的ascent，descent，width这些值的回调函数，至于函数中如何鉴别当前是哪个run，可以在CTRunDelegateCreate的第二个参数来达到目的，因为CTRunDelegateCreate的第二个参数会作为每一个回调调用时的入参。
    CTRunDelegateCallbacks callbacks;
    callbacks.version = kCTRunDelegateCurrentVersion;
    callbacks.dealloc = DeallocCallback;
    callbacks.getAscent = GetAscentCallback;
    callbacks.getDescent = GetDecentCallback;
    callbacks.getWidth = GetWidthCallback;
    
    /** 相当于一次CFRetain 这个引用计数不受arc管理 */
    return CTRunDelegateCreate(&callbacks, (__bridge_retained void *)(self.copy));
}
//!
- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:@(_ascent) forKey:@"ascent"];
    [aCoder encodeObject:@(_descent) forKey:@"descent"];
    [aCoder encodeObject:@(_width) forKey:@"width"];
    [aCoder encodeObject:_userInfo forKey:@"userInfo"];
}
//!
- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    _ascent = ((NSNumber *)[aDecoder decodeObjectForKey:@"ascent"]).floatValue;
    _descent = ((NSNumber *)[aDecoder decodeObjectForKey:@"descent"]).floatValue;
    _width = ((NSNumber *)[aDecoder decodeObjectForKey:@"width"]).floatValue;
    _userInfo = [aDecoder decodeObjectForKey:@"userInfo"];
    return self;
}
//!
- (id)copyWithZone:(NSZone *)zone {
    typeof(self) one = [self.class new];
    one.ascent = self.ascent;
    one.descent = self.descent;
    one.width = self.width;
    one.userInfo = self.userInfo;
    return one;
}

@end
