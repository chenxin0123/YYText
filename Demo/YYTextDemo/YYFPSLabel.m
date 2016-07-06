//
//  YYFPSLabel.m!
//  YYKitExample
//
//  Created by ibireme on 15/9/3.
//  Copyright (c) 2015 ibireme. All rights reserved.
//

#import "YYFPSLabel.h"
//#import <YYKit/YYKit.h>
#import "YYText.h"
#import "YYWeakProxy.h"

#define kSize CGSizeMake(55, 20)

@implementation YYFPSLabel {
    CADisplayLink *_link;
    NSUInteger _count;
    NSTimeInterval _lastTime;
    UIFont *_font;
    UIFont *_subFont;
    
    NSTimeInterval _llll;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (frame.size.width == 0 && frame.size.height == 0) {
        frame.size = kSize;
    }
    self = [super initWithFrame:frame];
    
    self.layer.cornerRadius = 5;
    self.clipsToBounds = YES;
    self.textAlignment = NSTextAlignmentCenter;
    self.userInteractionEnabled = NO;
    self.backgroundColor = [UIColor colorWithWhite:0.000 alpha:0.700];
    
    _font = [UIFont fontWithName:@"Menlo" size:14];
    if (_font) {
        _subFont = [UIFont fontWithName:@"Menlo" size:4];
    } else {
        _font = [UIFont fontWithName:@"Courier" size:14];
        _subFont = [UIFont fontWithName:@"Courier" size:4];
    }
    
    _link = [CADisplayLink displayLinkWithTarget:[YYWeakProxy proxyWithTarget:self] selector:@selector(tick:)];
    [_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    return self;
}
//!
- (void)dealloc {
    [_link invalidate];
}

/**!
 *    [self sizeToFit]调用了这个方法
 */
- (CGSize)sizeThatFits:(CGSize)size {
    [self intrinsicContentSize];
    return kSize;
}

///每一帧掉一次
- (void)tick:(CADisplayLink *)link {
    if (_lastTime == 0) {
        _lastTime = link.timestamp;
        return;
    }
    
    //累加帧数
    _count++;
    NSTimeInterval delta = link.timestamp - _lastTime;
    //不够一秒返回
    if (delta < 1) return;
    //重置_lastTime
    _lastTime = link.timestamp;
    //计算帧率
    float fps = _count / delta;
    //重置count
    _count = 0;
    //progress用来计算数字颜色
    CGFloat progress = fps / 60.0;
    UIColor *color = [UIColor colorWithHue:0.27 * (progress - 0.2) saturation:1 brightness:0.9 alpha:1];
    //round 四舍五入
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:[NSString stringWithFormat:@"%d FPS",(int)round(fps)]];
    [text yy_setColor:color range:NSMakeRange(0, text.length - 3)];
    [text yy_setColor:[UIColor whiteColor] range:NSMakeRange(text.length - 3, 3)];
    text.yy_font = _font;
    [text yy_setFont:_subFont range:NSMakeRange(text.length - 4, 1)];
    
    self.attributedText = text;
}

@end
