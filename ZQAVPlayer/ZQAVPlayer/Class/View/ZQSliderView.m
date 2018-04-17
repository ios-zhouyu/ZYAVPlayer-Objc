//
//  ZQSliderView.m
//  ZQAVPlayer
//
//  Created by zhouyu on 12/04/2018.
//  Copyright © 2018 zhouyu. All rights reserved.
//

#import "ZQSliderView.h"
#import "Masonry.h"

@interface ZQSliderView ()
@property (nonatomic, strong) UISlider *slider;//进度条...
@property (nonatomic, strong) UIView *circleView;//滚动按钮小白点
@property (nonatomic, strong) UIView *sliderCurrentView;//进度条
@property (nonatomic, strong) UIView *sliderBackView;//进度条背景框
@property (nonatomic, strong) UIView *sliderBufferView;//缓冲进度条
@end

@implementation ZQSliderView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        [self addSubview:self.sliderBackView];
        [self addSubview:self.sliderBufferView];
        [self addSubview:self.sliderCurrentView];
        [self addSubview:self.sliderCircleView];
        [self.sliderCircleView addSubview:self.circleView];
        
        [self.sliderBackView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_equalTo(self);
            make.right.mas_equalTo(self);
            make.centerY.mas_equalTo(self);
            make.height.mas_equalTo(3);
        }];
        
        [self.sliderBufferView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_equalTo(self);
            make.centerY.mas_equalTo(self);
            make.height.mas_equalTo(3);
            make.width.mas_equalTo(0);
        }];
        
        [self.sliderCurrentView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_equalTo(self);
            make.centerY.mas_equalTo(self);
            make.height.mas_equalTo(3);
        }];
        
        [self.sliderCircleView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.mas_equalTo(self);
            make.centerY.mas_equalTo(self);
            make.width.mas_equalTo(15);
            make.height.mas_equalTo(self);
        }];
        
        [self.circleView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.mas_equalTo(self.sliderCircleView);
            make.height.width.mas_equalTo(15);
        }];
    }
    return self;
}

#pragma mark - UIPanGestureRecognizer
- (void)sliderValueChanged:(UIPanGestureRecognizer *)panGesture {
    if (self.delegate && [self.delegate respondsToSelector:@selector(sliderValueChangedWithPanGesture:)]) {
        [self.delegate sliderValueChangedWithPanGesture:panGesture];
    }
}

#pragma mark - setter
- (void)setSliderCurrentWidth:(CGFloat)sliderCurrentWidth {
    _sliderCurrentWidth = sliderCurrentWidth;
    [self.sliderCurrentView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(sliderCurrentWidth);
    }];
    [self.sliderCircleView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self).offset(sliderCurrentWidth);
    }];
    [self layoutIfNeeded];
}

- (void)setSliderBufferViewWidth:(CGFloat)sliderBufferViewWidth {
    _sliderBufferViewWidth = sliderBufferViewWidth;
    [self.sliderBufferView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.width.mas_equalTo(sliderBufferViewWidth);
    }];
    [self layoutIfNeeded];
}

#pragma mark - getter
- (UIView *)sliderCircleView {
    if (!_sliderCircleView) {
        _sliderCircleView = [[UIView alloc] init];
        _sliderCircleView.backgroundColor = [UIColor clearColor];
        [_sliderCircleView addGestureRecognizer:self.panGesture];
    }
    return _sliderCircleView;
}
- (UIPanGestureRecognizer *)panGesture {
    if (!_panGesture) {
        _panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(sliderValueChanged:)];
    }
    return _panGesture;
}
- (UIView *)circleView {
    if (!_circleView) {
        _circleView = [[UIView alloc] init];
        _circleView.layer.cornerRadius = 7.5f;
        _circleView.layer.masksToBounds = YES;
        _circleView.backgroundColor = [UIColor whiteColor];
    }
    return _circleView;
}
- (UIView *)sliderCurrentView {
    if (!_sliderCurrentView) {
        _sliderCurrentView = [[UIView alloc] init];
        _sliderCurrentView.backgroundColor = [UIColor greenColor];
        _sliderCurrentView.layer.cornerRadius = 1.5f;
        _sliderCurrentView.layer.masksToBounds = YES;
    }
    return _sliderCurrentView;
}
- (UIView *)sliderBackView {
    if (!_sliderBackView) {
        _sliderBackView = [[UIView alloc] init];
        _sliderBackView.backgroundColor = [UIColor clearColor];
        _sliderBackView.layer.cornerRadius = 1.5f;
        _sliderBackView.layer.masksToBounds = YES;
        _sliderBackView.layer.borderColor = [UIColor whiteColor].CGColor;
        _sliderBackView.layer.borderWidth = 0.5f;
    }
    return _sliderBackView;
}
- (UIView *)sliderBufferView {
    if (!_sliderBufferView) {
        _sliderBufferView = [[UIView alloc] init];
        _sliderBufferView.backgroundColor = [[UIColor whiteColor] colorWithAlphaComponent:0.7];
        _sliderBufferView.layer.cornerRadius = 1.5f;
        _sliderBufferView.layer.masksToBounds = YES;
    }
    return _sliderBufferView;
}

@end
