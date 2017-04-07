//
//  ViewController.m
//  02-硬解码
//
//  Created by coderwhy on 2017/3/2.
//  Copyright © 2017年 coderwhy. All rights reserved.
//

#import "ViewController.h"
#import "OpenGLView.h"
#import <VideoToolbox/VideoToolbox.h>
#import "AAPLEAGLLayer.h"

@interface ViewController ()
{
    VTDecompressionSessionRef mDecodeSession;
    CMFormatDescriptionRef  mFormatDescription;
    uint8_t *mSPS;
    long mSPSSize;
    uint8_t *mPPS;
    long mPPSSize;
    
    // 输入
    NSInputStream *inputStream;
    
    uint8_t*       packetBuffer;
    long         packetSize;
    
    uint8_t*       inputBuffer;
    long         inputSize;
    long         inputMaxSize;
}

@property (nonatomic , strong) CADisplayLink *mDispalyLink;
@property (nonatomic, strong) dispatch_queue_t mDecodeQueue;
@property (nonatomic, strong) AAPLEAGLLayer *playLayer;

@end

const uint8_t lyStartCode[4] = {0, 0, 0, 1};

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 1.获取mOpenGLView用于之后展示数据
    self.playLayer = [[AAPLEAGLLayer alloc] initWithFrame:self.view.bounds];
    self.playLayer.backgroundColor = [UIColor blackColor].CGColor;
    [self.view.layer insertSublayer:self.playLayer atIndex:0];
    
    
    // 2.创建CADisplayLink, 用于定时获取信息
    self.mDispalyLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
    self.mDispalyLink.frameInterval = 2; // 默认是30FPS的帧率录制
    [self.mDispalyLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.mDispalyLink setPaused:YES];
    
    // 3.创建了一个队列, 用于解码数据
    self.mDecodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
}


- (IBAction)play {
    // 1.开始读取数据
    // 1.1.创建NSInputStream, 读取流
    inputStream = [[NSInputStream alloc] initWithFileAtPath:[[NSBundle mainBundle] pathForResource:@"123" ofType:@"h264"]];
    
    // 1.2.打开流
    [inputStream open];
    
    // 1.3.初始化多少
    inputSize = 0;
    inputMaxSize = 720 * 1280;
    inputBuffer = malloc(inputMaxSize);
    
    // 2.开始执行mDispalyLink, 开始进行编码
    [self.mDispalyLink setPaused:NO];
}


#pragma mark - 开始读取帧
-(void)updateFrame {
    dispatch_sync(_mDecodeQueue, ^{
        // 1.取出数据
        [self readPacket];
        
        // 2.如果取出数据为NULL/0, 那么表示数据已经读完, 则停止读取
        if(packetBuffer == NULL || packetSize == 0) {
            [self onInputEnd];
            return ;
        }
        
        // 3.获取nalSize大小
        uint32_t nalSize = (uint32_t)(packetSize - 4);
        // 4.获取指向地址的指针
        uint32_t *pNalSize = (uint32_t *)packetBuffer;
        *pNalSize = CFSwapInt32HostToBig(nalSize);
        
        // 在buffer的前面填入代表长度的int
        CVPixelBufferRef pixelBuffer = NULL;
        // 0x1F
        // 0x27 0010 0111
        // 0x1F 0001 1111
        // 5.取出类型
        int nalType = packetBuffer[4] & 0x1F;
        switch (nalType) {
            case 0x07:
                // 5.1.获取SPS信息, 并且保存
                mSPSSize = packetSize - 4;
                mSPS = malloc(mSPSSize);
                memcpy(mSPS, packetBuffer + 4, mSPSSize);
                break;
            case 0x08:
                // 5.2.获取PPS信息, 并且保存起来
                mPPSSize = packetSize - 4;
                mPPS = malloc(mPPSSize);
                memcpy(mPPS, packetBuffer + 4, mPPSSize);
                break;
            case 0x05:
                // 5.3.初始化硬解码需要的内容
                [self initVideoToolBox];
                
                // 5.4.编码I帧数据
                pixelBuffer = [self decode];
                break;
            default:
                // 5.5.解码B/P帧数据
                pixelBuffer = [self decode];
                break;
        }
        
        if(pixelBuffer) {
            dispatch_async(dispatch_get_main_queue(), ^{
                self.playLayer.pixelBuffer = pixelBuffer;
                CVPixelBufferRelease(pixelBuffer);
            });
        }
        NSLog(@"Read Nalu size %ld", packetSize);
    });
}


#pragma mark - 从内存中读取数据
- (void)readPacket {
    if (packetSize && packetBuffer) {
        packetSize = 0;
        free(packetBuffer);
        packetBuffer = NULL;
    }
    
    if (inputSize < inputMaxSize && inputStream.hasBytesAvailable) {
        inputSize += [inputStream read:inputBuffer + inputSize maxLength:inputMaxSize - inputSize];
    }
    
    if (memcmp(inputBuffer, lyStartCode, 4) == 0) {
        if (inputSize > 4) { // 除了开始码还有内容
            uint8_t *pStart = inputBuffer + 4;
            uint8_t *pEnd = inputBuffer + inputSize;
            while (pStart != pEnd) { //这里使用一种简略的方式来获取这一帧的长度：通过查找下一个0x00000001来确定。
                if(memcmp(pStart - 3, lyStartCode, 4) == 0) { // 是开头
                    packetSize = pStart - inputBuffer - 3;
                    packetBuffer = malloc(packetSize);
                    memcpy(packetBuffer, inputBuffer, packetSize); //复制packet内容到新的缓冲区
                    memmove(inputBuffer, inputBuffer + packetSize, inputSize - packetSize); //把缓冲区前移
                    inputSize -= packetSize;
                    break;
                }
                else {
                    ++pStart;
                }
            }
        }
    }
}

- (void)initVideoToolBox {
    if (!mDecodeSession) {
        // 1. 定义SPS/PPS数据的数组
        const uint8_t* parameterSetPointers[2] = {mSPS, mPPS};
        const size_t parameterSetSizes[2] = {mSPSSize, mPPSSize};
        
        // 2.创建CMVideoFormatDescription对象
        CMVideoFormatDescriptionCreateFromH264ParameterSets(NULL, 2, parameterSetPointers, parameterSetSizes, 4,&mFormatDescription);
        
        // 3.设置参数
        NSDictionary *attr = @{(__bridge NSString*)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = didDecompress;
        
        // 5.创建VTDecompressionSession对象
        VTDecompressionSessionCreate(NULL, mFormatDescription, NULL, (__bridge CFDictionaryRef)attr, &callBackRecord, &mDecodeSession);

    }
}

-(CVPixelBufferRef)decode {
    // 1.通过之前的packetBuffer/packetSize给blockBuffer赋值
    CMBlockBufferRef blockBuffer = NULL;
    CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, (void*)packetBuffer, packetSize, kCFAllocatorNull,NULL, 0, packetSize, 0, &blockBuffer);
    
    // 2.创建准备的对象
    CMSampleBufferRef sampleBuffer = NULL;
    const size_t sampleSizeArray[] = {packetSize};
    CMSampleBufferCreateReady(NULL, blockBuffer, mFormatDescription, 0, 0, NULL, 0, sampleSizeArray, &sampleBuffer);
//    CMSampleBufferCreateReady(kCFAllocatorDefault, blockBuffer, mFormatDescription, 1, 0, NULL, 1, sampleSizeArray, &sampleBuffer);
    
    // 3.开始解码
    CVPixelBufferRef outputPixelBuffer = NULL;
    VTDecompressionSessionDecodeFrame(mDecodeSession, sampleBuffer, 0, &outputPixelBuffer, NULL);
    
    // 4.释放资源
    CFRelease(sampleBuffer);
    CFRelease(blockBuffer);
    
    return outputPixelBuffer;
}

void didDecompress(void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration ){
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(pixelBuffer);
}


- (void)onInputEnd {
    [inputStream close];
    inputStream = nil;
    if (inputBuffer) {
        free(inputBuffer);
        inputBuffer = NULL;
    }
    [self.mDispalyLink setPaused:YES];
    
    [self EndVideoToolBox];
}

- (void)EndVideoToolBox
{
    VTDecompressionSessionInvalidate(mDecodeSession);
    CFRelease(mDecodeSession);
    
    CFRelease(mFormatDescription);
    mFormatDescription = NULL;
    
    free(mSPS);
    free(mPPS);
    mSPSSize = mPPSSize = 0;
    
    [self.playLayer removeFromSuperlayer];
}



@end
