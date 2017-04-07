//
//  ViewController.m
//  06-视频采集
//
//  Created by 小码哥 on 2017/2/26.
//  Copyright © 2017年 小码哥. All rights reserved.
//

#import "ViewController.h"
#import "VideoCapture.h"

@interface ViewController ()

@property (nonatomic, strong) VideoCapture *videoCapture;

@end

@implementation ViewController

- (VideoCapture *)videoCapture {
    if (!_videoCapture) {
        _videoCapture = [[VideoCapture alloc] init];
    }
    return _videoCapture;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)startCapturing:(id)sender {
    [self.videoCapture startCapturing:self.view];
}

- (IBAction)stopCapturing:(id)sender {
    [self.videoCapture stopCapturing];
}

@end
