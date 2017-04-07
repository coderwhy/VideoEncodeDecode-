//
//  VideoCapture.h
//  01-视频采集
//
//  Created by coderwhy on 2017/2/23.
//  Copyright © 2017年 coderwhy. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VideoCapture : NSObject

- (void)startCapturing:(UIView *)preview ;
- (void)stopCapturing;

@end
