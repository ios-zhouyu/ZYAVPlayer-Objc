//
//  ZYSliderView.h
//  ZQAVPlayer
//
//  Created by zhouyu on 12/04/2018.
//  Copyright © 2018 zhouyu. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ZQSliderViewDelegate <NSObject>
- (void)sliderValueChangedWithPanGesture:(UIPanGestureRecognizer *)panGesture;//拖拽进度条
@end

@interface ZQSliderView : UIView
@property (nonatomic, assign) CGFloat sliderCurrentWidth;//当前slider的值
@property (nonatomic, assign) CGFloat sliderBufferViewWidth;//缓冲进度条

@property (nonatomic, weak) id<ZQSliderViewDelegate> delegate;

@property (nonatomic, strong) UIView *sliderCircleView;//滚动按钮
@property (nonatomic, strong) UIPanGestureRecognizer *panGesture;//进度条滚动按钮拖拽手势
@end
