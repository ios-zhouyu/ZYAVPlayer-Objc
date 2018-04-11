//
//  ViewController.m
//  ZQAVPlayer
//
//  Created by zhouyu on 2018/4/10.
//  Copyright © 2018 zhouyu. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()<ZYPlayerViewDelegate>
@property (nonatomic, strong) ZYPlayerView *playerView;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    self.navigationController.navigationBar.barStyle = UIStatusBarStyleLightContent;
    
    self.title = @"视频播放";
    
    ZYPlayerView *playerView = [[ZYPlayerView alloc] init];
    playerView.delegate = self;
    [self.view addSubview:playerView];
    self.playerView = playerView;
    
    [playerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.view);
        make.left.right.mas_equalTo(self.view);
        make.height.mas_equalTo(250);
    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.playerView.urlString = @"http://bos.nj.bpc.baidu.com/tieba-smallvideo/11772_3c435014fb2dd9a5fd56a57cc369f6a0.mp4";
}

#pragma mark - ZYPlayerViewDelegate
- (void)swiftPlayScreenWithFullScreenButton:(UIButton *)button {
//    if (button.selected) {
//        self.playerView.transform = CGAffineTransformMakeRotation(M_PI / 2);
//        [self.playerView mas_remakeConstraints:^(MASConstraintMaker *make) {
//            make.top.mas_equalTo(self.view.mas_right);
//            make.left.mas_equalTo(self.view.mas_top);
//            make.right.mas_equalTo(self.view.mas_bottom);
//            make.bottom.mas_equalTo(self.view.mas_left);
//        }];
//    } else {
//        self.playerView.transform = CGAffineTransformIdentity;
//        [self.playerView mas_remakeConstraints:^(MASConstraintMaker *make) {
//            make.top.mas_equalTo(self.view);
//            make.left.right.mas_equalTo(self.view);
//            make.height.mas_equalTo(250);
//        }];
//    }
//    [self.view layoutIfNeeded];
}



@end
