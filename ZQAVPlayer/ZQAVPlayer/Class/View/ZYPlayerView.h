//
//  ZYPlayerView.h
//  ZQAVPlayer
//
//  Created by zhouyu on 11/04/2018.
//  Copyright © 2018 zhouyu. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ZYPlayerViewDelegate <NSObject>
@optional
- (void)swiftPlayScreenWithFullScreenButton:(UIButton *)button;
@end

@interface ZYPlayerView : UIView
@property (nonatomic, copy) NSString *urlString;//视频连接...

@property (nonatomic, weak) id<ZYPlayerViewDelegate> delegate;

@end
