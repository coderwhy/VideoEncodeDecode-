//
//  VideoCapture.m
//  01-视频采集
//
//  Created by coderwhy on 2017/2/23.
//  Copyright © 2017年 coderwhy. All rights reserved.
//

#import "VideoCapture.h" 
#import <AVFoundation/AVFoundation.h>
#import "H264Encoder.h"

@interface VideoCapture () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, weak) AVCaptureSession *session;
@property (nonatomic, weak) AVCaptureVideoPreviewLayer *layer;
@property (nonatomic, strong) dispatch_queue_t videoQueue;
@property (nonatomic, strong) H264Encoder *encoder;

@end

@implementation VideoCapture


- (instancetype)init {
    if (self = [super init]) {
        self.videoQueue = dispatch_queue_create("com.520it.coderwhy", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - 开始/停止采集
- (void)startCapturing:(UIView *)preview {
    
    // 0.初始化编码器
    self.encoder = [[H264Encoder alloc] init];
    [self.encoder setPropertiesWithWidth:480 height:640];
    
    // 1.创建session
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    session.sessionPreset = AVCaptureSessionPreset640x480;
    self.session = session;
    
    // 2.创建输入设备
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:device error:nil];
    [session addInput:input];
    
    // 3.创建输出设备
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    [output setSampleBufferDelegate:self queue:self.videoQueue];
    // 设置输出的像素格式(YUV/RGB)
    output.videoSettings = @{(NSString *)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
    output.alwaysDiscardsLateVideoFrames = YES;
    [session addOutput:output];
    
//    AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
//    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    
    // 4.添加预览突出
    AVCaptureVideoPreviewLayer *prelayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    prelayer.frame = preview.bounds;
    [preview.layer insertSublayer:prelayer atIndex:0];
    self.layer = prelayer;
    
    
    AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
    
    if ([connection isVideoOrientationSupported]) {
        NSLog(@"支持修改");
    } else {
        NSLog(@"不知修改");
    }
    
    [connection setVideoOrientation:prelayer.connection.videoOrientation];
    
    // 5.开始采集
    [session startRunning];
}

- (void)stopCapturing {
    [self.layer removeFromSuperlayer];
    [self.session stopRunning];
    [self.encoder endEncode];
}



- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    [self.encoder ecodeSampleBuffer:sampleBuffer];
}

@end
