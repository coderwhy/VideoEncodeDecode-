//
//  ViewController.m
//  01-视频采集
//
//  Created by coderwhy on 2017/2/23.
//  Copyright © 2017年 coderwhy. All rights reserved.
//

#import "ViewController.h"
#import "VideoCapture.h"

@interface ViewController ()

@property (nonatomic, strong) VideoCapture *capture;

@end

@implementation ViewController

- (VideoCapture *)capture {
    if (_capture == nil) {
        _capture = [[VideoCapture alloc] init];
    }
    return _capture;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (IBAction)startCapturing {
    [self.capture startCapturing:self.view];
}

- (IBAction)stopCapturing:(id)sender {
    [self.capture stopCapturing];
}


@end
