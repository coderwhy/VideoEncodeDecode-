//
//  H264Encoder.m
//  01-视频采集
//
//  Created by coderwhy on 2017/2/23.
//  Copyright © 2017年 coderwhy. All rights reserved.
//

#import "H264Encoder.h"
#import "avformat.h"
#import "avcodec.h"
#import <CoreMedia/CoreMedia.h>

@interface H264Encoder ()
{
    AVFormatContext *pFormatCtx;
    AVOutputFormat *pOutFormat;
    AVStream *pStream;
    AVCodecContext *pCodecCtx;
    AVCodec *pCodec;
    AVFrame *pFrame;
    AVPacket packet;
    uint8_t *buffer;
    int y_size;
    
    int frame_width;
    int frame_height;
}

@end

@implementation H264Encoder

- (void)setPropertiesWithWidth:(int)width height:(int)height
{
    // 1.注册所有的格式和编码器
    av_register_all();
    
    // 2.初始化AVFormatContext
    // 2.1.初始化AVFormatContext
    pFormatCtx = avformat_alloc_context();
    
    // 2.2.设置输出的路径
    NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true) firstObject] stringByAppendingPathComponent:@"123.h264"];
    const char *cFilePath = [filePath UTF8String];
    pOutFormat = av_guess_format(NULL, cFilePath, NULL);
    pFormatCtx->oformat = pOutFormat;
    
    // 2.3.打开文件
    if (avio_open(&pFormatCtx->pb, cFilePath, AVIO_FLAG_READ_WRITE) < 0) {
        NSLog(@"打开文件的输入流失败");
        return;
    }
    
    // 3.创建一个新的输入流
    // 3.1.创建视频流
    // 参数一: 格式上下文
    // 参数二: 编码器, 如果还没有设置编码器, 则先填入0, 后续需要设置
    pStream = avformat_new_stream(pFormatCtx, 0);
    
    // 3.2.设置视频流的参数
    // 设置pts的时间刻度
    // PTS : presentation time stamp, 在展示的时间顺序, 计算PTS需要使用刻度
    // time_base : 分数
    // num : 分子
    // den : 分母
    pStream->time_base.num = 1;
    pStream->time_base.den = 90000;
    
    // 3.3.判断输入流是否创建成功
    if (pStream == NULL) {
        NSLog(@"创建输入流失败");
        return;
    }
    
    // 4.设置编码相关的参数
    // 4.1.给编码上下文赋值
    pCodecCtx = pStream->codec;
    
    // 4.2.设置编码的类型(音频编码还是视频编码)
    pCodecCtx->codec_type = AVMEDIA_TYPE_VIDEO;
    
    // 4.3.设置是视频编码的标准:  h264
    // pCodecCtx->codec_id = AV_CODEC_ID_H264;
    // 使用默认的视频编码id, 默认就是H264编码
    pCodecCtx->codec_id = AV_CODEC_ID_H264;
    
    // 4.4.设置像素格式
    pCodecCtx->pix_fmt = PIX_FMT_YUV420P;
    
    // 4.5.设置视频的宽度&高度
    pCodecCtx->width = width;
    pCodecCtx->height = height;
    
    // 4.6.设置编码的时间刻度
    pCodecCtx->time_base.num = 1;
    pCodecCtx->time_base.den = 25;
    
    // 4.7.设置比特率
    pCodecCtx->bit_rate = 1500000;
    
    // 4.8.设置视频的质量
    pCodecCtx->qmin = 10;
    pCodecCtx->qmax = 51;
    
    // 4.9.设置GOP的大小
    pCodecCtx->gop_size = 50;
    
    // 4.10.设置B帧的数量
    pCodecCtx->max_b_frames = 5;
    
    // 5.设置编码信息
    // 5.1.查找对应的编码器
    pCodec = avcodec_find_encoder(pCodecCtx->codec_id);
    if (pCodec == NULL) {
        NSLog(@"查找对应的编码器失败");
        return;
    }
    
    // 5.2.打开编码器, 并且设置一些参数
    // 5.2.1.获取参数信息
    AVDictionary *param = 0;
    // H.264
    if(pCodecCtx->codec_id == AV_CODEC_ID_H264) {
        // 通过--preset的参数调节编码速度和质量的平衡。
        av_dict_set(&param, "preset", "slow", 0);
        
        // 通过--tune的参数值指定片子的类型，是和视觉优化的参数，或有特别的情况。
        // zerolatency: 零延迟，用在需要非常低的延迟的情况下，比如视频直播的编码
        av_dict_set(&param, "tune", "zerolatency", 0);
    }
    
    // 5.2.2.打开编码器
    if (avcodec_open2(pCodecCtx, pCodec, &param) < 0) {
        NSLog(@"打开编码器失败");
        return;
    }
    
    // 6.创建AVFrame对象, 用于存放编码前数据
    // 编码: AVFrame -> AVPacket
    // 解码: AVpacket -> AVFrame
    pFrame = av_frame_alloc();
    if (pFrame == NULL) {
        NSLog(@"AVFrame创建失败");
        return;
    }
    
    // 7.根据当前帧的大小, 获取缓存大小, 帮助申请内存, 用于存放编码前的数据
    avpicture_fill((AVPicture *)pFrame, buffer, pCodecCtx->pix_fmt, pCodecCtx->width, pCodecCtx->height);
    
    y_size = width * height;
    frame_width = width;
    frame_height = height;
}

- (void)ecodeSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    // 1.从CMSampleBuffer中获取像素数据
    CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    
    // 2.锁定该地址, 进行解码
    if (CVPixelBufferLockBaseAddress(imageBuffer, 0) == kCVReturnSuccess) {
        
        // 3.从CVPixelBufferRef读取YUV的值
        // NV12和NV21属于YUV格式，是一种two-plane模式，即Y和UV分为两个Plane，但是UV（CbCr）为交错存储，而不是分为三个plane
        // 3.1.获取Y分量的地址
        UInt8 *bufferPtr = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,0);
        // 3.2.获取UV分量的地址
        UInt8 *bufferPtr1 = (UInt8 *)CVPixelBufferGetBaseAddressOfPlane(imageBuffer,1);
        
        // 3.3.根据像素获取图片的真实宽度&高度
        size_t width = CVPixelBufferGetWidth(imageBuffer);
        size_t height = CVPixelBufferGetHeight(imageBuffer);
        // 获取Y分量长度
        size_t yBPR = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,0);
        size_t uvBPR = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer,1);
        UInt8 *yuv420_data = (UInt8 *)malloc(width * height *3/2);
        
        // 3.4.将NV12数据转成YUV420数据
        UInt8 *pU = yuv420_data + width*height;
        UInt8 *pV = pU + width*height/4;
        for(int i =0;i<height;i++)
        {
            memcpy(yuv420_data+i*width,bufferPtr+i*yBPR,width);
        }
        
        for(int j = 0;j<height/2;j++)
        {
            for(int i =0;i<width/2;i++)
            {
                *(pU++) = bufferPtr1[i<<1];
                *(pV++) = bufferPtr1[(i<<1) + 1];
            }
            bufferPtr1+=uvBPR;
        }
        
        // 4.给AVFrame设置数据
        // 4.1.设置YUV值
        pFrame->data[0] = yuv420_data;              // Y
        pFrame->data[1] = yuv420_data + y_size;      // U
        pFrame->data[2] = yuv420_data + y_size*5/4;  // V
        
        // 4.2.设置宽度和高度
        pFrame->width = frame_width;
        pFrame->height = frame_height;
        
        // 4.3.设置格式
        pFrame->format = PIX_FMT_YUV420P;
        
        // 5.对AVFrame进行编码
        // 5.1.定义标识, 记录是否编码成功
        int got_picture = 0;
        // 5.2.开始编码
        if (avcodec_encode_video2(pCodecCtx, &packet, pFrame, &got_picture) < 0) {
            NSLog(@"编码失败");
            return;
        }
        
        // 6.编码成功, 写入文件
        if (got_picture) {
            // 6.2.设置视频流的index
            packet.stream_index = pStream->index;
            
            // 6.3.写入文件
            av_write_frame(pFormatCtx, &packet);
            
            // 6.4.释放packet资源
            av_free_packet(&packet);
        }
        
        // 7.释放YUV数据
        free(yuv420_data);
    }
    
    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
}

- (void)endEncode {
    // 1.将还未输出的AVPacket继续写入文件
    av_write_trailer(pFormatCtx);
    
    // 2.释放资源
    avcodec_close(pCodecCtx);
    av_free(pFrame);
    avio_close(pFormatCtx->pb);
    avformat_free_context(pFormatCtx);
}

@end
