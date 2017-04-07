//
//  H264Encoder.h
//  01-视频采集
//
//  Created by coderwhy on 2017/2/23.
//  Copyright © 2017年 coderwhy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface H264Encoder : NSObject

- (void)setPropertiesWithWidth:(int)width height:(int)height;
 
- (void)ecodeSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)endEncode;

@end
