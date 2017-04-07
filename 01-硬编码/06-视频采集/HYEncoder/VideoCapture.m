//
//  VideoCapture.m
//  06-视频采集
//
//  Created by 小码哥 on 2017/2/26.
//  Copyright © 2017年 小码哥. All rights reserved.
//

#import "VideoCapture.h"
#import <AVFoundation/AVFoundation.h>
#import "H264Encoder.h"

@interface VideoCapture() <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, weak) AVCaptureSession *session;
@property (nonatomic, weak) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) H264Encoder *encoder;

@end

@implementation VideoCapture
    
- (void)startCapturing:(UIView *)preView
{
    // =============================== 准备编码 =================================
    self.encoder = [[H264Encoder alloc] init];
    [self.encoder prepareEncodeWithWidth:720 height:1280];
    
    // =============================== 采集视频 =================================
    // 1.创建session
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPreset1280x720;
    self.session = session;
    
    // 2.设置视频的输入
    // AVCaptureDevicePosition : 前置/后置
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error;
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:device error:&error];
    [session addInput:input];
    
    // 3.设置视频的输出
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    [output setSampleBufferDelegate:self queue:queue];
    [output setAlwaysDiscardsLateVideoFrames:YES];
    [session addOutput:output];
    
    // 视频输出的方向
    // 注意: 设置方向, 必须在将output添加到session之后
    AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
    if (connection.isVideoOrientationSupported) {
        connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    } else {
        NSLog(@"不支持设置方向");
    }
    
    // 4.添加预览图层
    AVCaptureVideoPreviewLayer *layer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    layer.frame = preView.bounds;
    [preView.layer insertSublayer:layer atIndex:0];
    self.previewLayer = layer;
    
    // 5.开始采集
    [session startRunning];
}

- (void)stopCapturing
{
    [self.previewLayer removeFromSuperlayer];
    [self.session stopRunning];
}

// 如果出现丢帧
- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    [self.encoder encodeFrame:sampleBuffer];
}

@end
