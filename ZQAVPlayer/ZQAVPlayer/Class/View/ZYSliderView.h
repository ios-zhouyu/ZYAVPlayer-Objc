//
//  ZYSliderView.h
//  ZQAVPlayer
//
//  Created by zhouyu on 12/04/2018.
//  Copyright © 2018 zhouyu. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ZYSliderViewDelegate <NSObject>
- (void)sliderValueChangedWithPanGesture:(UIPanGestureRecognizer *)panGesture;//拖拽进度条
@end

@interface ZYSliderView : UIView
@property (nonatomic, assign) CGFloat sliderCurrentWidth;//当前slider的值...
@property (nonatomic, assign) CGFloat sliderBufferViewWidth;//缓冲进度条

@property (nonatomic, weak) id<ZYSliderViewDelegate> delegate;

@end
