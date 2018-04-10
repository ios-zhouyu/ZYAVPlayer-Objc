//
//  ViewController.m
//  ZQAVPlayer
//
//  Created by zhouyu on 2018/4/10.
//  Copyright © 2018 zhouyu. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()
@property (nonatomic, strong)AVPlayer *player;//播放器
@property (nonatomic, strong)AVPlayerItem *playerItem;//播放单元
@property (nonatomic, strong)AVPlayerLayer *playerLayer;//播放界面（layer）
@property (nonatomic, strong) AVURLAsset *urlAsset;//播放集合
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    NSURL *URL = [NSURL URLWithString:@"http://bos.nj.bpc.baidu.com/tieba-smallvideo/11772_3c435014fb2dd9a5fd56a57cc369f6a0.mp4"];
    
    self.urlAsset = [AVURLAsset assetWithURL:URL];
    
    self.playerItem = [AVPlayerItem playerItemWithAsset:self.urlAsset];
    
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    
    self.playerLayer.frame = self.view.bounds;
    
    [self.view.layer insertSublayer:self.playerLayer atIndex:0];
    
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.player play];
}


@end
