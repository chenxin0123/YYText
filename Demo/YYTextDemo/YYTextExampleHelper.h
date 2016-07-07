//!
//  YYTextExampleHelper.h
//  YYKitExample
//
//  Created by ibireme on 15/9/3.
//  Copyright (c) 2015 ibireme. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface YYTextExampleHelper : NSObject

/**!
 *    在vc的导航栏右边加上一个uiswitch 用于打开关闭调试开关 打开则显示辅助线
 *
 *    @param vc vc
 */
+ (void)addDebugOptionToViewController:(UIViewController *)vc;

+ (void)setDebug:(BOOL)debug;
+ (BOOL)isDebug;
@end
