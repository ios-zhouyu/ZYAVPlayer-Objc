//
//  ZYPlayerView.h
//  ZQAVPlayer
//
//  Created by zhouyu on 11/04/2018.
//  Copyright © 2018 zhouyu. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ZQPlayerViewDelegate <NSObject>
@optional
- (void)backToSuperController;
- (void)swiftPlayScreenWithFullScreenButton:(UIButton *)button;
@end

@interface ZQPlayerView : UIView
@property (nonatomic, copy) NSString *urlString;//视频连接...

@property (nonatomic, weak) id<ZQPlayerViewDelegate> delegate;

@end
