//
//  ZQPlayerView.m
//  ZQAVPlayer
//
//  Created by zhouyu on 11/04/2018.
//  Copyright © 2018 zhouyu. All rights reserved.
//

#import "ZQPlayerView.h"
#import "Masonry.h"
#import <AVFoundation/AVFoundation.h>
#import "ZQSliderView.h"

typedef NS_ENUM(NSInteger, ZQAVPlayerPlayStatus) {
    ZQAVPlayerPlayStatusUnknown = 0,//默认未知
    ZQAVPlayerPlayStatusPreparePlay,//准备播放
    ZQAVPlayerPlayStatusLoading,//加载视频
    ZQAVPlayerPlayStatusPlay,//正在播放
    ZQAVPlayerPlayStatusPause,//暂停
    ZQAVPlayerPlayStatusEnd,//结束
    ZQAVPlayerPlayStatusCaching,//缓冲视频
    ZQAVPlayerPlayStatusCached,//缓冲结束
    ZQAVPlayerPlayStatusEnterBack,//app进入后台
    ZQAVPlayerPlayStatusBecomeActive,//从后台返回
    ZQAVPlayerPlayStatusFailed//失败
};

static NSString * ZYAVPlayerStatus = @"status";//playerItem的状态
static NSString * ZYAVPlayerLoadedTimeRanges = @"loadedTimeRanges";//缓冲的状态
static NSString * ZYAVPlayerPlaybackBufferEmpty = @"playbackBufferEmpty";//缓冲的状态
static NSString * ZYAVPlayerPlaybackLikelyToKeepUp = @"playbackLikelyToKeepUp";//缓冲的状态

@interface ZQPlayerView () <ZQSliderViewDelegate>
@property (nonatomic, strong) UIButton *backButton;//返回
@property (nonatomic, strong) UIButton *downloadButton;//下载
@property (nonatomic, strong) UIButton *playButton;//下载
@property (nonatomic, strong) UIButton *fullScreenButton;//全屏
@property (nonatomic, strong) UIButton *lockButton;//锁屏
@property (nonatomic, strong) UILabel *titleLabel;//标题
@property (nonatomic, strong) UILabel *currentTimeLabel;//当前播放时间
@property (nonatomic, strong) UILabel *totalTimeLabel;//总时间
@property (nonatomic, strong) ZQSliderView *sliderView;//进度条

@property (nonatomic, strong) AVPlayer *player;//播放器
@property (nonatomic, strong) AVPlayerItem *playerItem;//播放单元
@property (nonatomic, strong) AVPlayerLayer *playerLayer;//播放界面（layer）
@property (nonatomic, strong)  AVURLAsset *urlAsset;//播放集合

@property (nonatomic, assign, getter=isTouchedHidenSubviews) BOOL touchedHidenSubviews;//是否点击了屏幕,隐藏和显示按钮
@property (nonatomic, assign) ZQAVPlayerPlayStatus playStatus;//播放状态
@property (nonatomic, strong) id playerTimeObserve;//监听时时播放时间
@property (nonatomic, assign) NSInteger currentTimeNum;//当前播放的秒数,方便切换屏幕继续播放

@end

@implementation ZQPlayerView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _playStatus = ZQAVPlayerPlayStatusUnknown;
        _currentTimeNum = 0;
        
        self.backgroundColor = [UIColor blackColor];
        self.touchedHidenSubviews = NO;
        
        [self addSubview:self.backButton];
        [self addSubview:self.downloadButton];
        [self addSubview:self.lockButton];
        [self addSubview:self.playButton];
        [self addSubview:self.fullScreenButton];
        
        [self addSubview:self.titleLabel];
        [self addSubview:self.currentTimeLabel];
        [self addSubview:self.totalTimeLabel];
        
        [self addSubview:self.sliderView];
        
        [self palyerViewLayeroutSubView];
    }
    return self;
}

#pragma mark - setter
- (void)setUrlString:(NSString *)urlString {
    _urlString = urlString;
    // 将网址进行 UTF8 转码，避免有些汉字会变乱码
    NSURL *URL = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    self.urlAsset = [AVURLAsset URLAssetWithURL:URL options:@{@"AVURLAssetPreferPreciseDurationAndTimingKey":@(YES)}];
    self.playerItem = [AVPlayerItem playerItemWithAsset:self.urlAsset];
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.playerLayer.frame = self.bounds;
    [self.layer insertSublayer:self.playerLayer atIndex:0];
    
    // 监听播放状态
    [self.playerItem addObserver:self forKeyPath:ZYAVPlayerStatus options:NSKeyValueObservingOptionNew context:nil];
    // 监听缓冲进度
    [self.playerItem addObserver:self forKeyPath:ZYAVPlayerLoadedTimeRanges options:NSKeyValueObservingOptionNew context:nil];
    // 监听网络缓冲状态: 缓冲区空了，需要等待数据
    [self.playerItem addObserver:self forKeyPath:ZYAVPlayerPlaybackBufferEmpty options:NSKeyValueObservingOptionNew context:nil];
    // 监听网络缓冲状态 :缓冲区有足够数据可以播放了
    [self.playerItem addObserver:self forKeyPath:ZYAVPlayerPlaybackLikelyToKeepUp options:NSKeyValueObservingOptionNew context:nil];
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    // 监听播放完成
    [notificationCenter addObserver:self selector:@selector(playerPlayToEnd:) name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    // 监听异常中断
    [notificationCenter addObserver:self selector:@selector(playerPlayToError:) name:AVPlayerItemPlaybackStalledNotification object:nil];
    // 监听进入后台
    [notificationCenter addObserver:self selector:@selector(playerPlayToEnterBack:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    // 监听从后台返回
    [notificationCenter addObserver:self selector:@selector(playerPlayToBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

#pragma mark - NSNotificationCenter
- (void)playerPlayToEnd:(NSNotification *)notification {
    self.playStatus = ZQAVPlayerPlayStatusEnd;
    self.playButton.selected = NO;
    self.lockButton.selected = NO;
    [self setSubviewsHiddenWithStatus:NO];
}
- (void)playerPlayToError:(NSNotification *)notification {
    self.playStatus = ZQAVPlayerPlayStatusFailed;
}
- (void)playerPlayToEnterBack:(NSNotification *)notification {
    self.playStatus = ZQAVPlayerPlayStatusEnterBack;
}
- (void)playerPlayToBecomeActive:(NSNotification *)notification {
    self.playStatus = ZQAVPlayerPlayStatusBecomeActive;
}

#pragma mark - playerItem observer
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == self.playerItem && [keyPath isEqualToString:ZYAVPlayerStatus]) {//播放状态
        [self detalPlayerItemStatus];
    } else if (object == self.playerItem && [keyPath isEqualToString:ZYAVPlayerLoadedTimeRanges]) {//视频缓冲
        [self detalPlayerItemLoadedTimeRanges];
    } else if (object == self.playerItem && [keyPath isEqualToString:ZYAVPlayerPlaybackBufferEmpty]) {// 监听播放器在缓冲数据的状态,VPlayer 缓存不足就会自动暂停
        self.playStatus = ZQAVPlayerPlayStatusPause;
    } else if (object == self.playerItem && [keyPath isEqualToString:ZYAVPlayerPlaybackLikelyToKeepUp]) {// AVPlayer 缓存不足就会自动暂停，所以缓存充足了需要手动播放，才能继续播放
        [self.player play];
        self.playStatus = ZQAVPlayerPlayStatusPlay;
    }
}
- (void)detalPlayerItemLoadedTimeRanges {
    NSArray *loadedTimeRangesArr = [[self.player currentItem] loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRangesArr.firstObject CMTimeRangeValue];// 获取缓冲区域
    float startSeconds = CMTimeGetSeconds(timeRange.start);
    float durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval timeInterval = startSeconds + durationSeconds;// 计算缓冲总进度
    
    CMTime duration = self.playerItem.duration;
    CGFloat totalDuration = CMTimeGetSeconds(duration);//总时长
    
    __block CGFloat bufferViewWidth = (timeInterval / totalDuration) * CGRectGetWidth(self.sliderView.bounds);
    
    self.sliderView.sliderBufferViewWidth = bufferViewWidth;
    
}
- (void)detalPlayerItemStatus {
    if (self.playerItem.status == AVPlayerItemStatusReadyToPlay) {//将要播放--此方法只会在最开始播放时走一次
        self.playButton.selected = YES;
        [self.player play];
        self.playStatus = ZQAVPlayerPlayStatusPlay;
        self.sliderView.userInteractionEnabled = YES;
        
        // 获取总时长
        double totalTimeSecond = (double)self.urlAsset.duration.value / (double)self.urlAsset.duration.timescale;
        NSInteger totalMinute = totalTimeSecond / 60;
        NSInteger totalSecond = (int)totalTimeSecond % 60;
        self.totalTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d",(int)totalMinute,(int)totalSecond];
        
        // 监听播放进度,添加获取当前时长
        [self setplayerTimeObserve];
        
    } else if (self.playerItem.status == AVPlayerItemStatusFailed) {//播放失败
        self.playStatus = ZQAVPlayerPlayStatusFailed;
        [self.player pause];
        self.sliderView.userInteractionEnabled = NO;
    } else if (self.playerItem.status == AVPlayerItemStatusUnknown) {//未知错误
        self.playStatus = ZQAVPlayerPlayStatusUnknown;
        [self.player pause];
        self.sliderView.userInteractionEnabled = NO;
    }
}

//获取当前时长
- (void)setplayerTimeObserve {
    __block double totalTimeSecond = (double)self.urlAsset.duration.value / (double)self.urlAsset.duration.timescale;
    __weak typeof(self) weakSelf = self;
    self.playerTimeObserve = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 1.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        double currentTimeSecond = CMTimeGetSeconds(time);//当前时长
        if (currentTimeSecond) {
            NSInteger currentMinute =  currentTimeSecond / 60;
            NSInteger currentSecond =  (int)currentTimeSecond % 60;
            weakSelf.currentTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d",(int)currentMinute,(int)currentSecond];
            weakSelf.sliderView.sliderCurrentWidth = currentTimeSecond / totalTimeSecond * (CGRectGetWidth(weakSelf.sliderView.bounds) - 15);
            if (floor(currentTimeSecond) == floor(totalTimeSecond)) {
                weakSelf.playStatus = ZQAVPlayerPlayStatusEnd;
            }
        }
    }];
}

#pragma mark - dealloc
- (void)dealloc {
    if (self.playerTimeObserve) {
        [self.player removeTimeObserver:self.playerTimeObserve];
        self.playerTimeObserve = nil;
    }
    [self.playerItem removeObserver:self forKeyPath:ZYAVPlayerStatus];
    [self.playerItem removeObserver:self forKeyPath:ZYAVPlayerLoadedTimeRanges];
    [self.playerItem removeObserver:self forKeyPath:ZYAVPlayerPlaybackBufferEmpty];
    [self.playerItem removeObserver:self forKeyPath:ZYAVPlayerPlaybackLikelyToKeepUp];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVPlayerItemPlaybackStalledNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

#pragma mark - event
- (void)sliderValueChangedWithPanGesture:(UIPanGestureRecognizer *)panGesture {
    
    CGFloat totalTimeSecond = self.urlAsset.duration.value / self.urlAsset.duration.timescale;
    CGPoint sliderPoint = [panGesture locationInView:self.sliderView];
    sliderPoint = [self.sliderView convertPoint:sliderPoint toView:self.sliderView];
    CGFloat sliderWidth = CGRectGetWidth(self.sliderView.bounds);
    
    if (sliderPoint.x <= 0) {
        sliderPoint.x = 0;
    }
    if (sliderPoint.x >= sliderWidth) {
        sliderPoint.x = sliderWidth;
    }
    
    //当前滑动距离换算成对应的秒数
    CGFloat currentTimeSecond = sliderPoint.x / sliderWidth * totalTimeSecond;
    NSInteger currentMinute =  currentTimeSecond / 60;
    NSInteger currentSecond =  (int)currentTimeSecond % 60;
    
     //拖拽时,取消监听播放状态对slider的值得修改,由拖拽手势来修改...
    [self removePlayerTimeObserve];

    if (panGesture.state == UIGestureRecognizerStateChanged) {//拖拽时只修改显示的时间和滑动值,不触发对获取当前播放时间,维持原有播放
        [self removePlayerTimeObserve];
        self.currentTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d",(int)currentMinute,(int)currentSecond];
        self.sliderView.sliderCurrentWidth = currentTimeSecond / totalTimeSecond * (sliderWidth - 15);
    } else if (panGesture.state == UIGestureRecognizerStateEnded) {//拖拽结束再播放,在监听播放当前播放时长
        [self.player seekToTime:CMTimeMake(currentTimeSecond, 1) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        if (self.playStatus == ZQAVPlayerPlayStatusPause || self.playStatus == ZQAVPlayerPlayStatusEnd) {
            [self.player play];
            self.playButton.selected = YES;
        }
        //延迟1.0秒监听当前播放时长,否则slider会出现突变现象
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setplayerTimeObserve];
        });
    } else {
        if (self.playerTimeObserve) {
            [self.player removeTimeObserver:self.playerTimeObserve];
            self.playerTimeObserve = nil;
        }
    }
}
- (void)removePlayerTimeObserve{
    if (self.playerTimeObserve) {
        [self.player removeTimeObserver:self.playerTimeObserve];
        self.playerTimeObserve = nil;
    }
}

- (void)backButtonClick:(UIButton *)button {//返回
    if (self.delegate && [self.delegate respondsToSelector:@selector(backToSuperController)]) {
        [self.delegate backToSuperController];
    }
}
- (void)downloadButtonClick:(UIButton *)button {//下载
    
}
- (void)lockButtonClick:(UIButton *)button {//锁屏
    button.selected = !button.selected;
    [self setSubviewsHiddenWithStatus:button.selected];
}
- (void)playButtonClick:(UIButton *)button {//播放/暂停
    button.selected = !button.selected;
    if (button.isSelected) {
        if (self.playStatus == ZQAVPlayerPlayStatusEnd) {//播放结束后又重新点击播放
            [self.player seekToTime:CMTimeMake(1, 1) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        }
        [self.player play];
        self.playStatus = ZQAVPlayerPlayStatusPlay;
    } else {
        [self.player pause];
        self.playStatus = ZQAVPlayerPlayStatusPause;
    }
}
- (void)fullScreenButtonClick:(UIButton *)button {//全屏
    button.selected = !button.selected;
    if (self.delegate && [self.delegate respondsToSelector:@selector(swiftPlayScreenWithFullScreenButton:)]) {
        [self.delegate swiftPlayScreenWithFullScreenButton:button];
    }
}
//- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
//    if (self.lockButton.selected) {
//        return;
//    }
//    self.touchedHidenSubviews = !self.touchedHidenSubviews;
//    self.lockButton.hidden = self.touchedHidenSubviews;
//    [self setSubviewsHiddenWithStatus:self.touchedHidenSubviews];
//}

#pragma mark - NSTimer
- (void)autoHidenAllButton {
    self.lockButton.hidden = YES;
    [self setSubviewsHiddenWithStatus:YES];
}
- (void)setSubviewsHiddenWithStatus:(BOOL)status {
    self.backButton.hidden = status;
    self.playButton.hidden = status;
    self.downloadButton.hidden = status;
    self.fullScreenButton.hidden = status;
    self.titleLabel.hidden = status;
    self.currentTimeLabel.hidden = status;
    self.totalTimeLabel.hidden = status;
    self.sliderView.hidden = status;
}

#pragma mark - Layerout SubView
- (void)palyerViewLayeroutSubView {
    [self.backButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.mas_equalTo(self).offset(5);
        make.width.height.mas_equalTo(30);
    }];
    
    [self.downloadButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.mas_equalTo(self.backButton);
        make.right.mas_equalTo(self).offset(-5);
        make.width.height.mas_equalTo(30);
    }];
    
    [self.lockButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self).offset(10);
        make.centerY.mas_equalTo(self);
        make.width.height.mas_equalTo(25);
    }];
    
    [self.playButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self).offset(10);
        make.bottom.mas_equalTo(self).offset(-5);
        make.width.height.mas_equalTo(25);
    }];
    
    [self.fullScreenButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.mas_equalTo(self).offset(-5);
        make.bottom.mas_equalTo(self).offset(-3);
        make.width.height.mas_equalTo(30);
    }];
    
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(self);
        make.centerY.mas_equalTo(self.backButton);
    }];
    
    [self.currentTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.playButton.mas_right).offset(2);
        make.centerY.mas_equalTo(self.playButton);
        make.width.mas_equalTo(42);
    }];
    
    [self.totalTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.mas_equalTo(self.fullScreenButton.mas_left).offset(-2);
        make.centerY.mas_equalTo(self.playButton);
        make.width.mas_equalTo(42);
    }];
    
    [self.sliderView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.currentTimeLabel.mas_right);
        make.right.mas_equalTo(self.totalTimeLabel.mas_left);
        make.centerY.mas_equalTo(self.playButton.mas_centerY);
        make.height.mas_equalTo(40);
    }];
}

#pragma mark - getter
- (ZQSliderView *)sliderView {
    if (!_sliderView) {
        _sliderView = [[ZQSliderView alloc] init];
        _sliderView.userInteractionEnabled = NO;
        _sliderView.delegate = (id)self;
    }
    return _sliderView;
}
- (UILabel *)titleLabel {
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.text = @"这里是视频播放的标题";
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.font = [UIFont systemFontOfSize:14.0];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _titleLabel;
}
- (UILabel *)currentTimeLabel {
    if (!_currentTimeLabel) {
        _currentTimeLabel = [[UILabel alloc] init];
        _currentTimeLabel.text = @"00:00";
        _currentTimeLabel.textColor = [UIColor whiteColor];
        _currentTimeLabel.font = [UIFont systemFontOfSize:12.0];
        _currentTimeLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _currentTimeLabel;
}
- (UILabel *)totalTimeLabel {
    if (!_totalTimeLabel) {
        _totalTimeLabel = [[UILabel alloc] init];
        _totalTimeLabel.text = @"00:00";
        _totalTimeLabel.textColor = [UIColor whiteColor];
        _totalTimeLabel.font = [UIFont systemFontOfSize:12.0];
        _totalTimeLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _totalTimeLabel;
}

- (UIButton *)backButton {
    if (!_backButton) {
        _backButton = [[UIButton alloc] init];
        [_backButton setImage:[UIImage imageNamed:@"ZFPlayer.bundle/ZFPlayer_back_full"] forState:UIControlStateNormal];
        _backButton.backgroundColor = [UIColor clearColor];
        [_backButton addTarget:self action:@selector(backButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _backButton;
}
- (UIButton *)downloadButton {
    if (!_downloadButton) {
        _downloadButton = [[UIButton alloc] init];
        [_downloadButton setImage:[UIImage imageNamed:@"ZFPlayer.bundle/ZFPlayer_download"] forState:UIControlStateNormal];
        _downloadButton.backgroundColor = [UIColor clearColor];
        [_downloadButton addTarget:self action:@selector(downloadButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _downloadButton;
}
- (UIButton *)lockButton {
    if (!_lockButton) {
        _lockButton = [[UIButton alloc] init];
        [_lockButton setImage:[UIImage imageNamed:@"ZFPlayer.bundle/ZFPlayer_unlock-nor"] forState:UIControlStateNormal];
        [_lockButton setImage:[UIImage imageNamed:@"ZFPlayer.bundle/ZFPlayer_lock-nor"] forState:UIControlStateSelected];
        _lockButton.backgroundColor = [UIColor clearColor];
        [_lockButton addTarget:self action:@selector(lockButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _lockButton;
}
- (UIButton *)playButton {
    if (!_playButton) {
        _playButton = [[UIButton alloc] init];
        [_playButton setImage:[UIImage imageNamed:@"ZYAVPlayerPauseBtn"] forState:UIControlStateNormal];
        [_playButton setImage:[UIImage imageNamed:@"ZFPlayer.bundle/ZFPlayer_pause"] forState:UIControlStateSelected];
        _playButton.backgroundColor = [UIColor clearColor];
        [_playButton addTarget:self action:@selector(playButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _playButton;
}
- (UIButton *)fullScreenButton {
    if (!_fullScreenButton) {
        _fullScreenButton = [[UIButton alloc] init];
        [_fullScreenButton setImage:[UIImage imageNamed:@"ZFPlayer.bundle/ZFPlayer_fullscreen"] forState:UIControlStateNormal];
        [_fullScreenButton setImage:[UIImage imageNamed:@"ZFPlayer.bundle/ZFPlayer_shrinkscreen"] forState:UIControlStateSelected];
        _fullScreenButton.backgroundColor = [UIColor clearColor];
        [_fullScreenButton addTarget:self action:@selector(fullScreenButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _fullScreenButton;
}

@end
