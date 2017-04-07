//
//  VideoCapture.h
//  06-视频采集
//
//  Created by 小码哥 on 2017/2/26.
//  Copyright © 2017年 小码哥. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface VideoCapture : NSObject
    
- (void)startCapturing:(UIView *)preView;
- (void)stopCapturing;

@end
