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
#import "ZQPlayerLoadingView.h"

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
@property (nonatomic, strong) AVAssetImageGenerator *assetImageGenerator;//预览图管理
@property (nonatomic, strong) UIImageView *preViewImageView;//预览图

@property (nonatomic, assign, getter=isTouchedHidenSubviews) BOOL touchedHidenSubviews;//是否点击了屏幕,隐藏和显示按钮
@property (nonatomic, assign) ZQAVPlayerPlayStatus playStatus;//播放状态
@property (nonatomic, strong) id playerTimeObserve;//监听时时播放时间
@property (nonatomic, assign) NSInteger currentTimeNum;//当前播放的秒数,方便切换屏幕继续播放
@property (nonatomic, assign, getter=isSliderDragging) BOOL sliderDragging;//是否在拖拽小圆点

@property (nonatomic, strong) ZQPlayerLoadingView *loadingView;//网络缓冲等待
@property (nonatomic, strong) UIButton *playWrongButton;//视频加载失败
@property (nonatomic, copy) NSString *currentURLString;//当前视频连接
@end

@implementation ZQPlayerView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _playStatus = ZQAVPlayerPlayStatusUnknown;
        _currentTimeNum = 0;
        _sliderDragging = NO;
        
        self.backgroundColor = [UIColor blackColor];
        self.touchedHidenSubviews = NO;
        
        [self addSubview:self.backButton];
        [self addSubview:self.downloadButton];
        [self addSubview:self.lockButton];
        [self addSubview:self.playButton];
        [self addSubview:self.fullScreenButton];
        [self addSubview:self.playWrongButton];
        
        [self addSubview:self.titleLabel];
        [self addSubview:self.currentTimeLabel];
        [self addSubview:self.totalTimeLabel];
        
        [self addSubview:self.sliderView];
        [self addSubview:self.preViewImageView];
        [self addSubview:self.loadingView];
        
        [self sendSubviewToBack:self.loadingView];
        [self sendSubviewToBack:self.preViewImageView];
        
        [self palyerViewLayeroutSubView];
        
        //双击手势控制控件的隐藏和显示
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
        doubleTap.numberOfTapsRequired = 2;
        [self addGestureRecognizer:doubleTap];
        
    }
    return self;
}

#pragma mark - setter
- (void)setPreViewImageNameString:(NSString *)preViewImageNameString {
    _preViewImageNameString = preViewImageNameString;
    self.preViewImageView.image = [UIImage imageNamed:preViewImageNameString];
}

- (void)setUrlString:(NSString *)urlString {
    _urlString = urlString;
    self.currentURLString = urlString;
    // 将网址进行 UTF8 转码，避免有些汉字会变乱码
    NSURL *URL = [NSURL URLWithString:[urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    self.urlAsset = [AVURLAsset URLAssetWithURL:URL options:@{@"AVURLAssetPreferPreciseDurationAndTimingKey":@(YES)}];
    self.playerItem = [AVPlayerItem playerItemWithAsset:self.urlAsset];
    self.player = [AVPlayer playerWithPlayerItem:self.playerItem];
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.playerLayer.frame = self.bounds;
    [self.layer insertSublayer:self.playerLayer atIndex:0];
    
    //设置预览图
    self.preViewImageView.image = [self preViewImageWithAVURLAsset:self.urlAsset atTime:6];
    
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

//获取指定时间的预览图
- (UIImage*)preViewImageWithAVURLAsset:(AVURLAsset *)urlAsset atTime:(NSTimeInterval)time {
    self.assetImageGenerator = [[AVAssetImageGenerator alloc] initWithAsset:urlAsset];
    self.assetImageGenerator.appliesPreferredTrackTransform = YES;
    self.assetImageGenerator.apertureMode = AVAssetImageGeneratorApertureModeEncodedPixels;
    
    CGImageRef preViewImageRef = NULL;
    NSError *error = nil;
    preViewImageRef = [self.assetImageGenerator copyCGImageAtTime:CMTimeMake(time, 1)actualTime:NULL error:&error];
    
    if(!preViewImageRef || error) {//未解析到图片
        return nil;
    } else {//拿到预览图后隐藏loading图
        self.loadingView.hidden = YES;
        return [[UIImage alloc] initWithCGImage: preViewImageRef];
    }
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
        self.loadingView.hidden = NO;//缓冲的时候加载loading图
    } else if (object == self.playerItem && [keyPath isEqualToString:ZYAVPlayerPlaybackLikelyToKeepUp]) {// AVPlayer 缓存不足就会自动暂停，所以缓存充足了需要手动播放，才能继续播放
        self.loadingView.hidden = YES;//缓冲完成时关闭
        if (self.playButton.selected) {//防止首次进来时自动播放
            [self.player play];
            self.playStatus = ZQAVPlayerPlayStatusPlay;
        }
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
        self.playStatus = ZQAVPlayerPlayStatusPreparePlay;
        self.sliderView.userInteractionEnabled = YES;
        self.playWrongButton.hidden = YES;
        
        // 获取总时长
        double totalTimeSecond = (double)self.urlAsset.duration.value / (double)self.urlAsset.duration.timescale;
        NSInteger totalMinute = totalTimeSecond / 60;
        NSInteger totalSecond = (int)totalTimeSecond % 60;
        self.totalTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d",(int)totalMinute,(int)totalSecond];
        
        // 监听播放进度,添加获取当前时长
        [self setplayerTimeObserve];
        
    } else if (self.playerItem.status == AVPlayerItemStatusFailed) {//播放失败
        self.playStatus = ZQAVPlayerPlayStatusFailed;
        self.playWrongButton.hidden = NO;
        self.loadingView.hidden = YES;
        [self.player pause];
        self.sliderView.userInteractionEnabled = NO;
    } else if (self.playerItem.status == AVPlayerItemStatusUnknown) {//未知错误
        self.playStatus = ZQAVPlayerPlayStatusUnknown;
        self.playWrongButton.hidden = NO;
        [self.player pause];
        self.sliderView.userInteractionEnabled = NO;
        self.loadingView.hidden = YES;
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
            if (!weakSelf.isSliderDragging) {
                weakSelf.currentTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d",(int)currentMinute,(int)currentSecond];
                weakSelf.sliderView.sliderCurrentWidth = currentTimeSecond / totalTimeSecond * (CGRectGetWidth(weakSelf.sliderView.bounds) - 15);
            }
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

#pragma mark - ZQSliderViewDelegate
- (void)sliderValueChangedWithPanGesture:(UIPanGestureRecognizer *)panGesture {
    
    CGFloat totalTimeSecond = self.urlAsset.duration.value / self.urlAsset.duration.timescale;
    CGPoint sliderPoint = [panGesture locationInView:self.sliderView];
    sliderPoint = [self.sliderView convertPoint:sliderPoint toView:self.sliderView];
    CGFloat sliderWidth = CGRectGetWidth(self.sliderView.bounds);
    CGFloat sliderHeight = CGRectGetHeight(self.sliderView.bounds);
    
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
    
     //使用是否拖拽的bool值来控制,而不是移除playerTimeObserve,有时候移除不及时,出现小圆点突变位置的bug
    self.sliderDragging = YES;
    
    if (sliderPoint.y < -20 ||  sliderPoint.y > sliderHeight + 20) {//限制滑动的范围
        self.loadingView.hidden = NO;
        [self.sliderView.sliderCircleView removeGestureRecognizer:panGesture];//先删除手势在添加
        //调到对应播放时间播放
        [self.player seekToTime:CMTimeMake(currentTimeSecond, 1) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        
        //更改时间和进度
        self.currentTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d",(int)currentMinute,(int)currentSecond];
        self.sliderView.sliderCurrentWidth = currentTimeSecond / totalTimeSecond * (sliderWidth - 15);
        [self.sliderView.sliderCircleView addGestureRecognizer:self.sliderView.panGesture];
        
        if (self.playStatus == ZQAVPlayerPlayStatusPreparePlay || self.playStatus == ZQAVPlayerPlayStatusPause || self.playStatus == ZQAVPlayerPlayStatusEnd) {
            [self.player play];
            [self.preViewImageView removeFromSuperview];
            self.playButton.selected = YES;
            self.playStatus = ZQAVPlayerPlayStatusPlay;
        }
        //延迟1.0秒监听当前播放时长,否则slider会出现突变现象
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.loadingView.hidden = YES;
            self.sliderDragging = NO;
        });
        return;
    }
    
    //正常手势事件
    if (panGesture.state == UIGestureRecognizerStateChanged) {//拖拽时只修改显示的时间和滑动值,不触发对获取当前播放时间,维持原有播放
        self.sliderDragging = YES;
        self.currentTimeLabel.text = [NSString stringWithFormat:@"%02d:%02d",(int)currentMinute,(int)currentSecond];
        self.sliderView.sliderCurrentWidth = currentTimeSecond / totalTimeSecond * (sliderWidth - 15);
    } else if (panGesture.state == UIGestureRecognizerStateEnded) {//拖拽结束再播放,在监听播放当前播放时长
        self.loadingView.hidden = NO;
        [self.player seekToTime:CMTimeMake(currentTimeSecond, 1) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
        if (self.playStatus == ZQAVPlayerPlayStatusPreparePlay || self.playStatus == ZQAVPlayerPlayStatusPause || self.playStatus == ZQAVPlayerPlayStatusEnd) {
            [self.player play];
            [self.preViewImageView removeFromSuperview];
            self.playButton.selected = YES;
            self.playStatus = ZQAVPlayerPlayStatusPlay;
        }
        //延迟0.5秒监听当前播放时长,否则slider会出现突变现象
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.loadingView.hidden = YES;
            self.sliderDragging = NO;
        });
    } else {
        self.sliderDragging = NO;
    }
}
- (void)removePlayerTimeObserve{//移除当前播放时间监听者
    if (self.playerTimeObserve) {
        [self.player removeTimeObserver:self.playerTimeObserve];
        self.playerTimeObserve = nil;
    }
}

#pragma mark - button event
- (void)backButtonClick:(UIButton *)button {//返回
    if (self.delegate && [self.delegate respondsToSelector:@selector(backToSuperController)]) {
        [self.delegate backToSuperController];
    }
}
- (void)downloadButtonClick:(UIButton *)button {//下载
    
}
- (void)lockButtonClick:(UIButton *)button {//锁屏
    if (self.playStatus == ZQAVPlayerPlayStatusEnd) {
        return;
    }
    button.selected = !button.selected;
    [self setSubviewsHiddenWithStatus:button.selected];
}
- (void)playButtonClick:(UIButton *)button {//播放/暂停
    button.selected = !button.selected;
    if (button.isSelected) {
        [self.preViewImageView removeFromSuperview];//开始播放删除预览图
        if (self.playStatus == ZQAVPlayerPlayStatusEnd) {//播放结束后又重新点击播放
            [self.player seekToTime:CMTimeMake(1, 5) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
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
- (void)doubleTap:(UITapGestureRecognizer *)doubleTapGesture {//双击隐藏所有子控件
    if (self.lockButton.selected || self.playStatus == ZQAVPlayerPlayStatusEnd || [doubleTapGesture.view isMemberOfClass:[self class]]) {
        return;
    }
    self.touchedHidenSubviews = !self.touchedHidenSubviews;
    self.lockButton.hidden = self.touchedHidenSubviews;
    [self setSubviewsHiddenWithStatus:self.touchedHidenSubviews];
}
- (void)tryPlayAgain {
    self.loadingView.hidden = NO;
    if (self.playStatus != ZQAVPlayerPlayStatusPlay || self.playStatus != ZQAVPlayerPlayStatusPreparePlay) {
        self.urlString = self.currentURLString;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.loadingView.hidden = YES;
    });
}
//隐藏所有按钮
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
    
    [self.preViewImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(self);
    }];
    
    [self.loadingView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.bottom.left.right.mas_equalTo(self);
    }];
    
    [self.playWrongButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.mas_equalTo(self);
    }];
}

#pragma mark - getter
- (ZQPlayerLoadingView *)loadingView {
    if (!_loadingView) {
        _loadingView = [[ZQPlayerLoadingView alloc] init];
        _loadingView.hidden = NO;
    }
    return _loadingView;
}
- (UIImageView *)preViewImageView {
    if (!_preViewImageView) {
        _preViewImageView = [[UIImageView alloc] initWithFrame:self.bounds];
        _preViewImageView.image = [UIImage imageNamed:@"ZFPlayer.bundle/ZFPlayer_loading_bgView"];
    }
    return _preViewImageView;
}
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
- (UIButton *)playWrongButton {
    if (!_playWrongButton) {
        _playWrongButton = [[UIButton alloc] init];
        [_playWrongButton setTitle:@"  播放失败,点我重试  " forState:UIControlStateNormal];
        [_playWrongButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_playWrongButton setTitle:@"  播放失败,点我重试  " forState:UIControlStateNormal];
        [_playWrongButton setTitleColor:[UIColor grayColor] forState:UIControlStateHighlighted];
        _playWrongButton.titleLabel.font = [UIFont systemFontOfSize:14.0];
        _playWrongButton.hidden = YES;
        _playWrongButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        _playWrongButton.layer.cornerRadius = 3;
        _playWrongButton.layer.masksToBounds = YES;
        [_playWrongButton addTarget:self action:@selector(tryPlayAgain) forControlEvents:UIControlEventTouchUpInside];
    }
    return _playWrongButton;
}
@end
