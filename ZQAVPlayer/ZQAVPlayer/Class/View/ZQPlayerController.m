//
//  ZQPlayerController.m
//  ZQAVPlayer
//
//  Created by zhouyu on 17/04/2018.
//  Copyright © 2018 zhouyu. All rights reserved.
//

#import "ZQPlayerController.h"

@interface ZQPlayerController ()<ZQPlayerViewDelegate>
@property (nonatomic, strong) ZQPlayerView *playerView;
@end

@implementation ZQPlayerController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self.navigationController setNavigationBarHidden:YES animated:YES];
    self.navigationController.navigationBar.barStyle = UIStatusBarStyleLightContent;
    
    self.title = @"视频播放";
    
    ZQPlayerView *playerView = [[ZQPlayerView alloc] init];
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
    NSString *urlString = @"http://static.smartisanos.cn/common/video/proud-farmer.mp4";
    self.playerView.urlString = urlString;
}


- (void)backToSuperController {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
