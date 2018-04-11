//
//  ZYPlayerView.m
//  ZYAVPlayer
//
//  Created by zhouyu on 11/04/2018.
//  Copyright © 2018 zhouyu. All rights reserved.
//

#import "ZYPlayerView.h"
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSInteger, ZYAVPlayerPlayStatus) {
    ZYAVPlayerPlayStatusUnknown = 0,//默认未知
    ZYAVPlayerPlayStatusPreparePlay,//准备播放
    ZYAVPlayerPlayStatusLoading,//加载视频
    ZYAVPlayerPlayStatusPlay,//正在播放
    ZYAVPlayerPlayStatusPause,//暂停
    ZYAVPlayerPlayStatusEnd,//结束
    ZYAVPlayerPlayStatusCaching,//缓冲视频
    ZYAVPlayerPlayStatusCached,//缓冲结束
    ZYAVPlayerPlayStatusEnterBack,//app进入后台
    ZYAVPlayerPlayStatusBecomeActive,//从后台返回
    ZYAVPlayerPlayStatusFailed//失败
};

static NSString * ZYAVPlayerStatus = @"status";//playerItem的状态
static NSString * ZYAVPlayerLoadedTimeRanges = @"loadedTimeRanges";//缓冲的状态
static NSString * ZYAVPlayerPlaybackBufferEmpty = @"playbackBufferEmpty";//缓冲的状态
static NSString * ZYAVPlayerPlaybackLikelyToKeepUp = @"playbackLikelyToKeepUp";//缓冲的状态

@interface ZYPlayerView ()
@property (nonatomic, strong) UIButton *backButton;//返回
@property (nonatomic, strong) UIButton *downloadButton;//下载
@property (nonatomic, strong) UIButton *playButton;//下载
@property (nonatomic, strong) UIButton *fullScreenButton;//全屏
@property (nonatomic, strong) UIButton *lockButton;//锁屏
@property (nonatomic, strong) UILabel *titleLabel;//标题
@property (nonatomic, strong) UILabel *currentTimeLabel;//当前播放时间
@property (nonatomic, strong) UILabel *totalTimeLabel;//总时间
@property (nonatomic, strong) UISlider *progressSlider;//进度条
@property (nonatomic, strong) UIView *progressSliderBackView;//进度条背景框
@property (nonatomic, strong) UIView *progressSliderBufferView;//缓冲进度条
@property (nonatomic, assign, getter=isSliderDragging) BOOL sliderDragging;

@property (nonatomic, strong) AVPlayer *player;//播放器
@property (nonatomic, strong) AVPlayerItem *playerItem;//播放单元
@property (nonatomic, strong) AVPlayerLayer *playerLayer;//播放界面（layer）
@property (nonatomic, strong)  AVURLAsset *urlAsset;//播放集合

@property (nonatomic, assign, getter=isTouchedHidenSubviews) BOOL touchedHidenSubviews;//是否点击了屏幕,一遍隐藏和显示按钮
@property (nonatomic, assign) ZYAVPlayerPlayStatus playStatus;//播放状态
@property (nonatomic, strong) id playerTimeObserve;//监听时时播放时间
@property (nonatomic, assign) NSInteger currentTimeNum;//当前播放的秒数,方便切换屏幕继续播放

@property (nonatomic, weak) NSTimer *timer;//添加定时器,10秒后自动隐藏所有按钮,使用timerInterval
@property (nonatomic, assign) NSTimeInterval timerInterval;//
@end

@implementation ZYPlayerView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _timerInterval = 10.0;
        _playStatus = ZYAVPlayerPlayStatusUnknown;
        _currentTimeNum = 0;
        _sliderDragging = NO;
        
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
        
        [self addSubview:self.progressSliderBackView];
        [self addSubview:self.progressSliderBufferView];
        [self addSubview:self.progressSlider];
        
        [self palyerViewLayeroutSubView];
        
        //自动隐藏所有按钮--意义不大
//        self.timer = [NSTimer scheduledTimerWithTimeInterval:_timerInterval target:self selector:@selector(autoHidenAllButton) userInfo:nil repeats:YES];
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
    self.playStatus = ZYAVPlayerPlayStatusEnd;
    self.playButton.selected = NO;
    self.lockButton.selected = NO;
    
    self.touchedHidenSubviews = NO;
    self.lockButton.hidden = self.touchedHidenSubviews;
    self.backButton.hidden = self.touchedHidenSubviews;
    self.playButton.hidden = self.touchedHidenSubviews;
    self.downloadButton.hidden = self.touchedHidenSubviews;
    self.fullScreenButton.hidden = self.touchedHidenSubviews;
    self.titleLabel.hidden = self.touchedHidenSubviews;
    self.currentTimeLabel.hidden = self.touchedHidenSubviews;
    self.totalTimeLabel.hidden = self.touchedHidenSubviews;
    self.progressSliderBackView.hidden = self.touchedHidenSubviews;
    self.progressSliderBufferView.hidden = self.touchedHidenSubviews;
    self.progressSlider.hidden = self.touchedHidenSubviews;
    
    [self.timer invalidate];
    self.timer = nil;
}
- (void)playerPlayToError:(NSNotification *)notification {
    self.playStatus = ZYAVPlayerPlayStatusFailed;
}
- (void)playerPlayToEnterBack:(NSNotification *)notification {
    self.playStatus = ZYAVPlayerPlayStatusEnterBack;
}
- (void)playerPlayToBecomeActive:(NSNotification *)notification {
    self.playStatus = ZYAVPlayerPlayStatusBecomeActive;
}

#pragma mark - playerItem observer
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if (object == self.playerItem && [keyPath isEqualToString:ZYAVPlayerStatus]) {//播放状态
        [self detalPlayerItemStatus];
    } else if (object == self.playerItem && [keyPath isEqualToString:ZYAVPlayerLoadedTimeRanges]) {//视频缓冲
        [self detalPlayerItemLoadedTimeRanges];
    } else if (object == self.playerItem && [keyPath isEqualToString:ZYAVPlayerPlaybackBufferEmpty]) {// 监听播放器在缓冲数据的状态,VPlayer 缓存不足就会自动暂停
        self.playStatus = ZYAVPlayerPlayStatusPause;
    } else if (object == self.playerItem && [keyPath isEqualToString:ZYAVPlayerPlaybackLikelyToKeepUp]) {// AVPlayer 缓存不足就会自动暂停，所以缓存充足了需要手动播放，才能继续播放
        [self.player play];
        self.playStatus = ZYAVPlayerPlayStatusPlay;
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
    
    __block CGFloat bufferViewWidth = (timeInterval / totalDuration) * CGRectGetWidth(self.progressSliderBackView.bounds);
    
    [self.progressSliderBufferView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(bufferViewWidth);
    }];
    [self layoutIfNeeded];
}
- (void)detalPlayerItemStatus {
    if (self.playerItem.status == AVPlayerItemStatusReadyToPlay) {//将要播放
        self.playButton.selected = YES;
        [self.player play];
        self.playStatus = ZYAVPlayerPlayStatusPlay;
        
        //获取总时长
        __block double totalTimeSecond = (double)self.urlAsset.duration.value / (double)self.urlAsset.duration.timescale;
        NSInteger totalMinute = totalTimeSecond / 60;
        NSInteger totalSecond = (int)totalTimeSecond % 60;
        self.totalTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d",(int)totalMinute,(int)totalSecond];
        self.progressSlider.maximumValue = floor(totalTimeSecond);
        
        //获取当前时长
        [self setplayerTimeObserveWithTotalTimeSecond:totalTimeSecond];

    } else if (self.playerItem.status == AVPlayerItemStatusFailed) {//播放失败
        self.playStatus = ZYAVPlayerPlayStatusFailed;
        [self.player pause];
    } else if (self.playerItem.status == AVPlayerItemStatusUnknown) {//未知错误
        self.playStatus = ZYAVPlayerPlayStatusUnknown;
        [self.player pause];
    }
}

//获取当前时长
- (void)setplayerTimeObserveWithTotalTimeSecond:(double)totalTimeSecond {
    __weak typeof(self) weakSelf = self;
    self.playerTimeObserve = [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 1.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        double currentTimeSecond  = CMTimeGetSeconds(time);
        weakSelf.currentTimeNum = (NSInteger)currentTimeSecond;
        if (currentTimeSecond) {
            NSInteger currentMinute =  currentTimeSecond / 60;
            NSInteger currentSecond =  (int)currentTimeSecond % 60;
            weakSelf.currentTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d",(int)currentMinute,(int)currentSecond];
            weakSelf.progressSlider.value = currentTimeSecond;
            if (floor(currentTimeSecond) == floor(totalTimeSecond)) {
                weakSelf.playStatus = ZYAVPlayerPlayStatusEnd;
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
    [self.timer invalidate];
    self.timer = nil;
}

#pragma mark - event
- (void)slideValueChanged:(UIPanGestureRecognizer *)panGesture {
    CGFloat totalTimeSecond = self.urlAsset.duration.value / self.urlAsset.duration.timescale;
    CGPoint sliderPoint = [panGesture locationInView:self.progressSlider];
    CGFloat sliderWidth = CGRectGetWidth(self.progressSlider.bounds);
    NSLog(@"%f",sliderPoint.x);
    if (sliderPoint.x < 0 || sliderPoint.x > sliderWidth) {
        return;
    }
    
    //当前滑动距离换算成对应的秒数
     CGFloat slideValue = sliderPoint.x / sliderWidth * totalTimeSecond;
    
    NSInteger currentMinute =  slideValue / 60;
    NSInteger currentSecond =  (int)slideValue % 60;
    
    if (panGesture.state == UIGestureRecognizerStatePossible) {
        self.sliderDragging = NO;
    } else if (panGesture.state == UIGestureRecognizerStateBegan) {//拖拽开始时,取消监听播放状态对slider的值得修改,由拖拽手势来修改
        self.sliderDragging = YES;
        [self.playerItem removeObserver:self forKeyPath:ZYAVPlayerStatus];
    } else if (panGesture.state == UIGestureRecognizerStateChanged) {//拖拽时只修改显示的时间和滑动值,不触发对应播放,维持原有播放
        self.sliderDragging = YES;
        self.currentTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d",(int)currentMinute,(int)currentSecond];
        self.progressSlider.value = slideValue;
    } else if (panGesture.state == UIGestureRecognizerStateEnded) {//拖拽结束再播放,在监听播放状态
        self.sliderDragging = NO;
        [self.player seekToTime:CMTimeMake(slideValue, 1) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        // 监听播放状态--slider控件有问题?
        [self.playerItem addObserver:self forKeyPath:ZYAVPlayerStatus options:NSKeyValueObservingOptionNew context:nil];
    } else if (panGesture.state == UIGestureRecognizerStateCancelled) {
        self.sliderDragging = NO;
    } else if (panGesture.state == UIGestureRecognizerStateFailed) {
        self.sliderDragging = NO;
    } else if (panGesture.state == UIGestureRecognizerStateRecognized) {
        self.sliderDragging = NO;
    }
}
- (void)backButtonClick:(UIButton *)button {//返回
    
}
- (void)downloadButtonClick:(UIButton *)button {//下载
    
}
- (void)lockButtonClick:(UIButton *)button {//锁屏
    button.selected = !button.selected;
    self.backButton.hidden = button.selected;
    self.playButton.hidden = button.selected;
    self.downloadButton.hidden = button.selected;
    self.fullScreenButton.hidden = button.selected;
    self.titleLabel.hidden = button.selected;
    self.currentTimeLabel.hidden = button.selected;
    self.totalTimeLabel.hidden = button.selected;
    self.progressSliderBackView.hidden = button.selected;
    self.progressSliderBufferView.hidden = button.selected;
    self.progressSlider.hidden = button.selected;
}
- (void)playButtonClick:(UIButton *)button {//播放/暂停
    button.selected = !button.selected;
    if (button.isSelected) {
        if (self.playStatus == ZYAVPlayerPlayStatusEnd) {//播放结束后又重新点击播放
            [self.player seekToTime:CMTimeMake(1, 1) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        }
        [self.player play];
        self.playStatus = ZYAVPlayerPlayStatusPlay;
    } else {
        [self.player pause];
        self.playStatus = ZYAVPlayerPlayStatusPause;
    }
}
- (void)fullScreenButtonClick:(UIButton *)button {//全屏
    button.selected = !button.selected;
    if (self.delegate && [self.delegate respondsToSelector:@selector(swiftPlayScreenWithFullScreenButton:)]) {
        [self.delegate swiftPlayScreenWithFullScreenButton:button];
    }
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.lockButton.selected) {
        return;
    }
    self.touchedHidenSubviews = !self.touchedHidenSubviews;
    
    self.lockButton.hidden = self.touchedHidenSubviews;
    self.backButton.hidden = self.touchedHidenSubviews;
    self.playButton.hidden = self.touchedHidenSubviews;
    self.downloadButton.hidden = self.touchedHidenSubviews;
    self.fullScreenButton.hidden = self.touchedHidenSubviews;
    self.titleLabel.hidden = self.touchedHidenSubviews;
    self.currentTimeLabel.hidden = self.touchedHidenSubviews;
    self.totalTimeLabel.hidden = self.touchedHidenSubviews;
    self.progressSliderBackView.hidden = self.touchedHidenSubviews;
    self.progressSliderBufferView.hidden = self.touchedHidenSubviews;
    self.progressSlider.hidden = self.touchedHidenSubviews;
}

#pragma mark - NSTimer
- (void)autoHidenAllButton {
    self.touchedHidenSubviews = YES;
    self.lockButton.hidden = self.touchedHidenSubviews;
    self.backButton.hidden = self.touchedHidenSubviews;
    self.playButton.hidden = self.touchedHidenSubviews;
    self.downloadButton.hidden = self.touchedHidenSubviews;
    self.fullScreenButton.hidden = self.touchedHidenSubviews;
    self.titleLabel.hidden = self.touchedHidenSubviews;
    self.currentTimeLabel.hidden = self.touchedHidenSubviews;
    self.totalTimeLabel.hidden = self.touchedHidenSubviews;
    self.progressSliderBackView.hidden = self.touchedHidenSubviews;
    self.progressSliderBufferView.hidden = self.touchedHidenSubviews;
    self.progressSlider.hidden = self.touchedHidenSubviews;
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
    
    [self.progressSliderBackView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.currentTimeLabel.mas_right);
        make.right.mas_equalTo(self.totalTimeLabel.mas_left);
        make.centerY.mas_equalTo(self.playButton);
        make.height.mas_equalTo(3);
    }];
    
    [self.progressSliderBufferView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.currentTimeLabel.mas_right);
        make.centerY.mas_equalTo(self.playButton);
        make.height.mas_equalTo(3);
        make.width.mas_equalTo(0);
    }];
    
    [self.progressSlider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.currentTimeLabel.mas_right);
        make.right.mas_equalTo(self.totalTimeLabel.mas_left);
        make.centerY.mas_equalTo(self.playButton.mas_centerY).offset(-1.2);
        make.height.mas_equalTo(10);
    }];
}

#pragma mark - getter
- (UISlider *)progressSlider {
    if (!_progressSlider) {
        _progressSlider = [[UISlider alloc] init];
        _progressSlider.backgroundColor = [UIColor clearColor];
        _progressSlider.minimumValue = 0.0f;
        _progressSlider.value = 0.0f;
        _progressSlider.maximumValue = 3000.0f;
        _progressSlider.continuous = YES;
        _progressSlider.minimumTrackTintColor = [UIColor greenColor];
        _progressSlider.maximumTrackTintColor = [UIColor clearColor];
        [_progressSlider setThumbImage:[UIImage imageNamed:@"ZFPlayer.bundle/ZFPlayer_slider"] forState:UIControlStateNormal];
        [_progressSlider setThumbImage:[UIImage imageNamed:@"ZFPlayer.bundle/ZFPlayer_slider"] forState:UIControlStateHighlighted];
        [_progressSlider addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(slideValueChanged:)]];
    }
    return _progressSlider;
}
- (UIView *)progressSliderBackView {
    if (!_progressSliderBackView) {
        _progressSliderBackView = [[UIView alloc] init];
        _progressSliderBackView.backgroundColor = [UIColor clearColor];
        _progressSliderBackView.layer.cornerRadius = 1.5f;
        _progressSliderBackView.layer.masksToBounds = YES;
        _progressSliderBackView.layer.borderColor = [UIColor whiteColor].CGColor;
        _progressSliderBackView.layer.borderWidth = 0.5f;
    }
    return _progressSliderBackView;
}
- (UIView *)progressSliderBufferView {
    if (!_progressSliderBufferView) {
        _progressSliderBufferView = [[UIView alloc] init];
        _progressSliderBufferView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
        _progressSliderBufferView.layer.cornerRadius = 1.5f;
        _progressSliderBufferView.layer.masksToBounds = YES;
    }
    return _progressSliderBufferView;
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
