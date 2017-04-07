//
//  H264Encoder.m
//  06-视频采集
//
//  Created by 小码哥 on 2017/2/26.
//  Copyright © 2017年 小码哥. All rights reserved.
//  NSFileHandle

#import "H264Encoder.h"
#import <VideoToolbox/VideoToolbox.h>

@interface H264Encoder ()

@property (nonatomic, assign) VTCompressionSessionRef compressionSession;
@property (nonatomic, assign) int frameIndex;

/** 文件写入对象 */
@property (nonatomic, strong) NSFileHandle *fileHandle;

@end

@implementation H264Encoder

- (void)prepareEncodeWithWidth:(int)width height:(int)height
{
    
    // 1.获取沙盒路径
    NSString *file = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"abc.h264"];
    
    // 2.如果原来有文件,则删除
    [[NSFileManager defaultManager] removeItemAtPath:file error:nil];
    [[NSFileManager defaultManager] createFileAtPath:file contents:nil attributes:nil];
    
    // 3.创建对象
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:file];
    
    // 0.设置默认是第0帧
    self.frameIndex = 0;
    
    // 1.创建VTCompressionSessionRef
    // 1> 参数一: CFAllocatorRef用于CoreFoundation分配内存的模式 NULL使用默认的分配方式
    // 2> 参数二: 编码出来视频的宽度 width
    // 3> 参数三: 编码出来视频的高度 height
    // 4> 参数四: 编码的标准 : H.264/AVC
    // 5> 参数五/六/七 : NULL
    // 6> 参数八: 编码成功后的回调函数
    // 7> 参数九: 可以传递到回调函数中参数, self : 将当前对象传入
    VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressionCallback, (__bridge void * _Nullable)(self), &_compressionSession);
    
    
    // 2.设置属性
    // 2.1.设置实时输出
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    
    // 2.2.设置帧率
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_ExpectedFrameRate, (__bridge CFTypeRef _Nonnull)(@24));
    
    // 2.3.设置比特率(码率) 1500000/s
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef _Nonnull)(@1500000)); // bit
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFTypeRef _Nonnull)(@[@(1500000/8), @1])); // byte
    
    // 2.4.设置GOP的大小
    VTSessionSetProperty(_compressionSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef _Nonnull)(@20));
    
    
    // 3.准备编码
    VTCompressionSessionPrepareToEncodeFrames(_compressionSession);
}

- (void)encodeFrame:(CMSampleBufferRef)sampleBuffer
{
    // 1.将CMSampleBufferRef转成CVImageBufferRef
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // 2.开始编码
    // 1> 参数一: compressionSession
    // 2> 参数二: 需要将CMSampleBufferRef转成CVImageBufferRef
    // 3> 参数三: PTS(presentationTimeStamp)/DTS(DecodeTimeStamp)
    // 4> 参数四: kCMTimeInvalid
    // 5> 参数五: 是在回调函数中第二个参数
    // 6> 参数六: 是在回调函数中第四个参数
    CMTime pts = CMTimeMake(self.frameIndex, 24);
    VTCompressionSessionEncodeFrame(self.compressionSession, imageBuffer, pts, kCMTimeInvalid, NULL, NULL, NULL);
    NSLog(@"开始编码一帧数据");
}

#pragma mark - 获取编码后的数据
void didCompressionCallback(void * CM_NULLABLE outputCallbackRefCon,
                                    void * CM_NULLABLE sourceFrameRefCon,
                                    OSStatus status,
                                    VTEncodeInfoFlags infoFlags,
                            CM_NULLABLE CMSampleBufferRef sampleBuffer) {
    
    H264Encoder *encoder = (__bridge H264Encoder *)outputCallbackRefCon;
    
    // 1.判断该帧是否是关键帧
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    CFDictionaryRef dict = CFArrayGetValueAtIndex(attachments, 0);
    BOOL isKeyFrame = !CFDictionaryContainsKey(dict, kCMSampleAttachmentKey_NotSync);
    
    // 2.如果是关键帧, 获取SPS/PPS数据, 并且写入文件
    if (isKeyFrame) {
        // 2.1.从CMSampleBufferRef获取CMFormatDescriptionRef
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        // 2.2.获取SPS信息
        const uint8_t *spsOut;
        size_t spsSize, spsCount;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &spsOut, &spsSize, &spsCount, NULL);
        
        // 2.3.获取PPS信息
        const uint8_t *ppsOut;
        size_t ppsSize, ppsCount;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &ppsOut, &ppsSize, &ppsCount, NULL);
        
        // 2.4.将SPS/PPS转成NSData, 并且写入文件
        NSData *spsData = [NSData dataWithBytes:spsOut length:spsSize];
        NSData *ppsData = [NSData dataWithBytes:ppsOut length:ppsSize];
        
        // 2.5.写入文件
        [encoder gotSpsPps:spsData pps:ppsData];
    }
    
    // 3.获取编码后的数据, 写入文件
    // 3.1.获取CMBlockBufferRef
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    
    // 3.2.从blockBuffer中获取起始位置的内存地址
    size_t totalLength = 0;
    char *dataPointer;
    CMBlockBufferGetDataPointer(blockBuffer, 0, NULL, &totalLength, &dataPointer);
    
    // 3.3.一帧的图像可能需要写入多个NALU单元 --> Slice切换
    static const int H264HeaderLength = 4;
    size_t bufferOffset = 0;
    while (bufferOffset < totalLength - H264HeaderLength) {
        // 3.4.从起始位置拷贝H264HeaderLength长度的地址, 计算NALULength
        int NALULength = 0;
        memcpy(&NALULength, dataPointer + bufferOffset, H264HeaderLength);
        
        // 大端模式/小端模式-->系统模式
        // H264编码的数据是大端模式(字节序)
        NALULength = CFSwapInt32BigToHost(NALULength);
        
        // 3.5.从dataPointer开始, 根据长度创建NSData
        NSData *data = [NSData dataWithBytes:dataPointer + bufferOffset + H264HeaderLength length:NALULength];
        
        // 3.6.写入文件
        [encoder gotEncodedData:data isKeyFrame:YES];
        
        // 3.7.重新设置bufferOffset
        bufferOffset += NALULength + H264HeaderLength;
    }
}

- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps
{
    // 1.拼接NALU的header
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1;
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    
    // 2.将NALU的头&NALU的体写入文件
    [self.fileHandle writeData:ByteHeader];
    [self.fileHandle writeData:sps];
    [self.fileHandle writeData:ByteHeader];
    [self.fileHandle writeData:pps];
    
}
- (void)gotEncodedData:(NSData*)data isKeyFrame:(BOOL)isKeyFrame
{
    NSLog(@"gotEncodedData %d", (int)[data length]);
    if (self.fileHandle != NULL)
    {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
        [self.fileHandle writeData:ByteHeader];
        [self.fileHandle writeData:data];
    }
}

@end
