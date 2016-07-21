//
//  YYYTextLine.m
//  YYText <https://github.com/ibireme/YYText>
//
//  Created by ibireme on 15/3/3.
//  Copyright (c) 2015 ibireme.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "YYTextLine.h"
#import "YYTextUtilities.h"


@implementation YYTextLine {
    CGFloat _firstGlyphPos; // first glyph position for baseline, typically 0.
}

+ (instancetype)lineWithCTLine:(CTLineRef)CTLine position:(CGPoint)position vertical:(BOOL)isVertical {
    if (!CTLine) return nil;
    YYTextLine *line = [self new];
    line->_position = position;
    line->_vertical = isVertical;
    [line setCTLine:CTLine];
    return line;
}

- (void)dealloc {
    if (_CTLine) CFRelease(_CTLine);
}

- (void)setCTLine:(CTLineRef)CTLine {
    if (_CTLine != CTLine) {
        if (CTLine) CFRetain(CTLine);
        if (_CTLine) CFRelease(_CTLine);
        _CTLine = CTLine;
        if (_CTLine) {
            _lineWidth = CTLineGetTypographicBounds(_CTLine, &_ascent, &_descent, &_leading);
            CFRange range = CTLineGetStringRange(_CTLine);
            _range = NSMakeRange(range.location, range.length);
            if (CTLineGetGlyphCount(_CTLine) > 0) {
                CFArrayRef runs = CTLineGetGlyphRuns(_CTLine);
                CTRunRef run = CFArrayGetValueAtIndex(runs, 0);
                //第一个字形的位置
                CGPoint pos;
                CTRunGetPositions(run, CFRangeMake(0, 1), &pos);
                _firstGlyphPos = pos.x;
            } else {
                _firstGlyphPos = 0;
            }
            _trailingWhitespaceWidth = CTLineGetTrailingWhitespaceWidth(_CTLine);
        } else {
            _lineWidth = _ascent = _descent = _leading = _firstGlyphPos = _trailingWhitespaceWidth = 0;
            _range = NSMakeRange(0, 0);
        }
        [self reloadBounds];
    }
}

- (void)setPosition:(CGPoint)position {
    _position = position;
    [self reloadBounds];
}

- (void)reloadBounds {
    if (_vertical) {
        _bounds = CGRectMake(_position.x - _descent, _position.y, _ascent + _descent, _lineWidth);
        _bounds.origin.y += _firstGlyphPos;
    } else {
        _bounds = CGRectMake(_position.x, _position.y - _ascent, _lineWidth, _ascent + _descent);
        _bounds.origin.x += _firstGlyphPos;
    }
    
    _attachments = nil;
    _attachmentRanges = nil;
    _attachmentRects = nil;
    if (!_CTLine) return;
    CFArrayRef runs = CTLineGetGlyphRuns(_CTLine);
    NSUInteger runCount = CFArrayGetCount(runs);
    if (runCount == 0) return;
    
    //YYTextAttachment
    NSMutableArray *attachments = [NSMutableArray new];
    //NSValue-NSRange 占位符的range
    NSMutableArray *attachmentRanges = [NSMutableArray new];
    //YYTextAttachment所占的大小
    NSMutableArray *attachmentRects = [NSMutableArray new];
    ///遍历取出CTLine中的YYTextAttachment属性
    for (NSUInteger r = 0; r < runCount; r++) {
        CTRunRef run = CFArrayGetValueAtIndex(runs, r);
        //字形数量
        CFIndex glyphCount = CTRunGetGlyphCount(run);
        if (glyphCount == 0) continue;
        //属性
        NSDictionary *attrs = (id)CTRunGetAttributes(run);
        
        //图片或View
        YYTextAttachment *attachment = attrs[YYTextAttachmentAttributeName];
        if (attachment) {
            CGPoint runPosition = CGPointZero;
            //CTRun位置
            CTRunGetPositions(run, CFRangeMake(0, 1), &runPosition);
            
            CGFloat ascent, descent, leading, runWidth;
            CGRect runTypoBounds;
            //CTRun的宽度
            runWidth = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), &ascent, &descent, &leading);
            
            if (_vertical) {
                YYTEXT_SWAP(runPosition.x, runPosition.y);
                runPosition.y = _position.y + runPosition.y;
                runTypoBounds = CGRectMake(_position.x + runPosition.x - descent, runPosition.y , ascent + descent, runWidth);
            } else {
                //_position 0 22 runPosition 202 0 ascent 21.6 descent 10 runWidth 32
                //runPosition表示baseline相对于本CTLine的位置
                runPosition.x += _position.x;
                runPosition.y = _position.y - runPosition.y;//???
                runTypoBounds = CGRectMake(runPosition.x, runPosition.y - ascent, runWidth, ascent + descent);
            }
            //占位符的range
            NSRange runRange = YYTextNSRangeFromCFRange(CTRunGetStringRange(run));
            [attachments addObject:attachment];
            [attachmentRanges addObject:[NSValue valueWithRange:runRange]];
            [attachmentRects addObject:[NSValue valueWithCGRect:runTypoBounds]];
        }
    }
    _attachments = attachments.count ? attachments : nil;
    _attachmentRanges = attachmentRanges.count ? attachmentRanges : nil;
    _attachmentRects = attachmentRects.count ? attachmentRects : nil;
}

- (CGSize)size {
    return _bounds.size;
}

- (CGFloat)width {
    return CGRectGetWidth(_bounds);
}

- (CGFloat)height {
    return CGRectGetHeight(_bounds);
}

- (CGFloat)top {
    return CGRectGetMinY(_bounds);
}

- (CGFloat)bottom {
    return CGRectGetMaxY(_bounds);
}

- (CGFloat)left {
    return CGRectGetMinX(_bounds);
}

- (CGFloat)right {
    return CGRectGetMaxX(_bounds);
}

- (NSString *)description {
    NSMutableString *desc = @"".mutableCopy;
    NSRange range = self.range;
    [desc appendFormat:@"<YYTextLine: %p> row:%zd range:%tu,%tu",self, self.row, range.location, range.length];
    [desc appendFormat:@" position:%@",NSStringFromCGPoint(self.position)];
    [desc appendFormat:@" bounds:%@",NSStringFromCGRect(self.bounds)];
    return desc;
}

@end


@implementation YYTextRunGlyphRange
+ (instancetype)rangeWithRange:(NSRange)range drawMode:(YYTextRunGlyphDrawMode)mode {
    YYTextRunGlyphRange *one = [self new];
    one.glyphRangeInRun = range;
    one.drawMode = mode;
    return one;
}
@end
