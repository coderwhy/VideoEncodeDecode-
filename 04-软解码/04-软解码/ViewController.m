//
//  ViewController.m
//  04-软解码
//
//  Created by coderwhy on 2017/3/3.
//  Copyright © 2017年 coderwhy. All rights reserved.
//

#import "ViewController.h"
#import <libavformat/avformat.h>
#import "OpenGLView20.h"

@interface ViewController ()
{
    AVFormatContext *pFormatCtx;
    AVCodecContext *pCodecCtx;
    AVCodec *pCodec;
    AVFrame *pFrame;
    AVPacket packet;
    int video_index;
    
    OpenGLView20 *_glView;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //初始化
    OpenGLView20 *glView = [[OpenGLView20 alloc] initWithFrame:self.view.bounds];
    //设置视频原始尺寸
    [glView setVideoSize:352 height:288];
    _glView = glView;
    [self.view insertSubview:glView atIndex:0];
    
    
    // 1.初始化所有的格式&编码器
    av_register_all();
    
    // 2.创建AVFormatContext指针
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"story.mp4" ofType:nil];
    if (avformat_open_input(&pFormatCtx, [filePath UTF8String], NULL, NULL) < 0) {
        NSLog(@"读取文件失败");
        return;
    }
    
    // 3.获取文件中流信息
    if (avformat_find_stream_info(pFormatCtx, NULL) < 0) {
        NSLog(@"获取流信息失败");
        return;
    }
    
    // 4.查找视频流信息
    video_index = -1;
    for (int i = 0; i < pFormatCtx->nb_streams; i++) {
        if (pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            video_index = i;
            break;
        }
    }
    if (video_index < 0) {
        NSLog(@"查找视频流失败");
        return;
    }
    
    // 5.获取编码上下文
    pCodecCtx = pFormatCtx->streams[video_index]->codec;
    if (pCodecCtx == NULL) {
        NSLog(@"获取编码上下文失败");
        return;
    }
    
    // 6.查找解码器
    pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
    if (pCodec == NULL) {
        NSLog(@"查找解码器失败");
        return;
    }
    
    // 7.打开解码器
    if (avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
        NSLog(@"打开解码器失败");
        return;
    }
    
    // 8.创建AVFrame用于保存解码后的数据
    pFrame = av_frame_alloc();
    
}
- (IBAction)play:(id)sender {
    
    // 9.开始解码
    while (av_read_frame(pFormatCtx, &packet) >= 0) {
        if (packet.stream_index == video_index) {
            int got_picture = -1;
            avcodec_decode_video2(pCodecCtx, pFrame, &got_picture, &packet);
            
            if (got_picture) {
                
                char *buf = (char *)malloc(pFrame->width * pFrame->height * 3 / 2);
                AVPicture *pict;
                int w, h, i;
                char *y, *u, *v;
                pict = (AVPicture *)pFrame;//这里的frame就是解码出来的AVFrame
                w = pFrame->width;
                h = pFrame->height;
                y = buf;
                u = y + w * h;
                v = u + w * h / 4;
                for (i=0; i<h; i++)
                    memcpy(y + w * i, pict->data[0] + pict->linesize[0] * i, w);
                for (i=0; i<h/2; i++)
                    memcpy(u + w / 2 * i, pict->data[1] + pict->linesize[1] * i, w / 2);
                for (i=0; i<h/2; i++)
                    memcpy(v + w / 2 * i, pict->data[2] + pict->linesize[2] * i, w / 2);
                if (buf == NULL) {
                    return;
                }else {
                    dispatch_async(dispatch_get_global_queue(0, 0), ^{
                        sleep(1);
                        NSLog(@"-------");
                        [_glView displayYUV420pData:buf width:pFrame -> width height:pFrame ->height];
                        free(buf);
                    });
                }
            }
        }
    }

}


@end
