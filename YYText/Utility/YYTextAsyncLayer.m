//
//  YYTextAsyncLayer.m
//  YYText <https://github.com/ibireme/YYText>
//
//  Created by ibireme on 15/4/11.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "YYTextAsyncLayer.h"
#import <libkern/OSAtomic.h>


/// Global display queue, used for content rendering.！
static dispatch_queue_t YYTextAsyncLayerGetDisplayQueue() {
#define MAX_QUEUE_COUNT 16
    static int queueCount;
    //数组
    static dispatch_queue_t queues[MAX_QUEUE_COUNT];
    static dispatch_once_t onceToken;
    static int32_t counter = 0;
    dispatch_once(&onceToken, ^{
        queueCount = (int)[NSProcessInfo processInfo].activeProcessorCount;
        queueCount = queueCount < 1 ? 1 : queueCount > MAX_QUEUE_COUNT ? MAX_QUEUE_COUNT : queueCount;
        if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0) {
            //ios8+
            for (NSUInteger i = 0; i < queueCount; i++) {
                //QOS_CLASS_USER_INITIATED表示任务由UI发起并且可以异步执行 用户期望(不要放太耗时操作)
                dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0);
                queues[i] = dispatch_queue_create("com.ibireme.text.render", attr);
            }
        } else {
            for (NSUInteger i = 0; i < queueCount; i++) {
                //线性队列
                queues[i] = dispatch_queue_create("com.ibireme.text.render", DISPATCH_QUEUE_SERIAL);
                /**
                 1.相当于给队列设置优先级
                 2.设置队列的层级结构
                 所有的用户队列都有一个目标队列概念。从本质上讲，一个用户队列实际上是不执行任何任务的，但是它会将任务传递给它的目标队列来执行。通常，目标队列是默认优先级的全局队列。
                 
                 用户队列的目标队列可以用函数 dispatch_set_target_queue来修改。我们可以将任意dispatch queue传递给这个函数，甚至可以是另一个用户队列，只要别构成循环就行。
                 
                 一般都是把一个任务放到一个串行的queue中，如果这个任务被拆分了，被放置到多个串行的queue中，但实际还是需要这个任务同步执行，那么就会有问题，因为多个串行queue之间是并行的。这时使用dispatch_set_target_queue将多个串行的queue指定到了同一目标，那么着多个串行queue在目标queue上就是同步执行的，不再是并行执行。
                 */
                dispatch_set_target_queue(queues[i], dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0));
            }
        }
    });
    
    counter = INT32_MAX;
    int32_t cur = OSAtomicIncrement32(&counter);
    //bug https://github.com/ibireme/YYText/issues/399 作者已修复
    if (cur < 0) {
        cur = -cur;
    }

    return queues[(cur) % queueCount];
#undef MAX_QUEUE_COUNT
}

///dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0)!
static dispatch_queue_t YYTextAsyncLayerGetReleaseQueue() {
#ifdef YYDispatchQueuePool_h
    return YYDispatchQueueGetForQOS(NSQualityOfServiceDefault);
#else
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
#endif
}


/// a thread safe incrementing counter.!
@interface _YYTextSentinel : NSObject
/// Returns the current value of the counter. atomic
@property (atomic, readonly) int32_t value;
/// Increase the value atomically. @return The new value.
- (int32_t)increase;
@end

@implementation _YYTextSentinel {
    int32_t _value;
}
- (int32_t)value {
    return _value;
}
- (int32_t)increase {
    return OSAtomicIncrement32(&_value);
}
@end


@implementation YYTextAsyncLayerDisplayTask
@end



@implementation YYTextAsyncLayer {
    _YYTextSentinel *_sentinel;
}
#pragma mark - Override
///返回属性默认值!
+ (id)defaultValueForKey:(NSString *)key {
    if ([key isEqualToString:@"displaysAsynchronously"]) {
        return @(YES);
    } else {
        return [super defaultValueForKey:key];
    }
}
//!
- (instancetype)init {
    self = [super init];
    static CGFloat scale; //global
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        scale = [UIScreen mainScreen].scale;
    });
    self.contentsScale = scale;
    _sentinel = [_YYTextSentinel new];
    _displaysAsynchronously = YES;
    return self;
}
//!
- (void)dealloc {
    [_sentinel increase];
}
//!
- (void)setNeedsDisplay {
    [self _cancelAsyncDisplay];
    [super setNeedsDisplay];
}
//!
- (void)display {
    super.contents = super.contents;
    [self _displayAsync:_displaysAsynchronously];
}

#pragma mark - Private
//!
- (void)_displayAsync:(BOOL)async {
    //UIView是他的layer的代理
    __strong id<YYTextAsyncLayerDelegate> delegate = self.delegate;
    //调用代理方法返回一个异步绘制任务
    YYTextAsyncLayerDisplayTask *task = [delegate newAsyncDisplayTask];
    if (!task.display) {
        //无需绘制
        if (task.willDisplay) task.willDisplay(self);
        self.contents = nil;
        if (task.didDisplay) task.didDisplay(self, YES);
        return;
    }
    
    if (async) {
        //异步
        if (task.willDisplay) task.willDisplay(self);
        _YYTextSentinel *sentinel = _sentinel;
        int32_t value = sentinel.value;
        //对象释放 同步绘制 setNeedsDisplay 时sentinel.value会增加
        BOOL (^isCancelled)() = ^BOOL() {
            return value != sentinel.value;
        };
        
        CGSize size = self.bounds.size;
        //Defaults to NO
        BOOL opaque = self.opaque;
        CGFloat scale = self.contentsScale;
        
        CGColorRef backgroundColor = (opaque && self.backgroundColor) ? CGColorRetain(self.backgroundColor) : NULL;
        //尺寸小于1 不绘制
        if (size.width < 1 || size.height < 1) {
            //__bridge_retained 取出然后release
            CGImageRef image = (__bridge_retained CGImageRef)(self.contents);
            self.contents = nil;
            if (image) {
                dispatch_async(YYTextAsyncLayerGetReleaseQueue(), ^{
                    CFRelease(image);
                });
            }
            if (task.didDisplay) task.didDisplay(self, YES);
            CGColorRelease(backgroundColor);
            return;
        }
        
        /* 这里开始绘制 */
        dispatch_async(YYTextAsyncLayerGetDisplayQueue(), ^{
            if (isCancelled()) {
                //This function is equivalent to CFRelease, except that it does not cause an error if the color parameter is NULL
                CGColorRelease(backgroundColor);
                return;
            }
            //开始图片上下文
            UIGraphicsBeginImageContextWithOptions(size, opaque, scale);
            CGContextRef context = UIGraphicsGetCurrentContext();
            if (opaque) {
                /*opaque一般是NO 这里表示非透明 */
                //保存上下文状态
                CGContextSaveGState(context); {
                    if (!backgroundColor || CGColorGetAlpha(backgroundColor) < 1) {
                        CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
                        CGContextAddRect(context, CGRectMake(0, 0, size.width * scale, size.height * scale));
                        CGContextFillPath(context);
                    }
                    if (backgroundColor) {
                        //填充背景色
                        CGContextSetFillColorWithColor(context, backgroundColor);
                        CGContextAddRect(context, CGRectMake(0, 0, size.width * scale, size.height * scale));
                        CGContextFillPath(context);
                    }
                }
                //取回保存的上下文
                CGContextRestoreGState(context);
                CGColorRelease(backgroundColor);
            }
            //绘制
            task.display(context, size, isCancelled);
            //取消的话则不生成图片
            if (isCancelled()) {
                UIGraphicsEndImageContext();
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (task.didDisplay) task.didDisplay(self, NO);
                });
                return;
            }
            //生成图片然后关闭上下文
            UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            //取消的话不设置内容
            if (isCancelled()) {
                //didDisplay总是在主线程调用
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (task.didDisplay) task.didDisplay(self, NO);
                });
                return;
            }
            //设置内容
            dispatch_async(dispatch_get_main_queue(), ^{
                if (isCancelled()) {
                    if (task.didDisplay) task.didDisplay(self, NO);
                } else {
                    self.contents = (__bridge id)(image.CGImage);
                    if (task.didDisplay) task.didDisplay(self, YES);
                }
            });
        });
    } else {
        //同步绘制 这里先关闭异步绘制
        [_sentinel increase];
        if (task.willDisplay) task.willDisplay(self);
        //开始图片上下文
        UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.opaque, self.contentsScale);
        CGContextRef context = UIGraphicsGetCurrentContext();
        if (self.opaque) {
            CGSize size = self.bounds.size;
            size.width *= self.contentsScale;
            size.height *= self.contentsScale;
            CGContextSaveGState(context); {
                if (!self.backgroundColor || CGColorGetAlpha(self.backgroundColor) < 1) {
                    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
                    CGContextAddRect(context, CGRectMake(0, 0, size.width, size.height));
                    CGContextFillPath(context);
                }
                if (self.backgroundColor) {
                    CGContextSetFillColorWithColor(context, self.backgroundColor);
                    CGContextAddRect(context, CGRectMake(0, 0, size.width, size.height));
                    CGContextFillPath(context);
                }
            } CGContextRestoreGState(context);
        }
        //绘制 设置内容 
        task.display(context, self.bounds.size, ^{return NO;});
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        self.contents = (__bridge id)(image.CGImage);
        if (task.didDisplay) task.didDisplay(self, YES);
    }
}
//!
- (void)_cancelAsyncDisplay {
    [_sentinel increase];
}

@end
