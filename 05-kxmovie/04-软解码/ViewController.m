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
#import "KxMovieViewController.h"

@interface ViewController ()
{
    AVFormatContext *pFormatCtx;
    AVCodecContext *pCodecCtx;
    AVCodec *pCodec;
    AVFrame *pFrame;
    AVPacket packet;
    int video_index;
    
    OpenGLView20 *_glView;
    KxMovieViewController *vc;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    vc = [KxMovieViewController movieViewControllerWithContentPath:@"rtmp://59.110.159.169:1935/rtmplive/demo" parameters:nil];
}

- (IBAction)play:(id)sender {
    [self presentViewController:vc animated:YES completion:nil];
}


@end
