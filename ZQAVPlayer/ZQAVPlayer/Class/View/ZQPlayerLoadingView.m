//
//  ZQPlayerLoadingView.m
//  ZQAVPlayer
//
//  Created by zhouyu on 18/04/2018.
//  Copyright © 2018 zhouyu. All rights reserved.
//

#import "ZQPlayerLoadingView.h"
#import "Masonry.h"

@interface ZQPlayerLoadingView ()
@property (nonatomic, strong) UIImageView *loaddingImageView;
@end

@implementation ZQPlayerLoadingView

- (instancetype)initWithFrame:(CGRect)frame{
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.3];
        
        [self addSubview:self.loaddingImageView];
        
        [self.loaddingImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.center.mas_equalTo(self);
            make.width.height.mas_equalTo(50);
        }];
        
        CABasicAnimation *transformAnima = [CABasicAnimation animationWithKeyPath:@"transform.rotation"];
        transformAnima.toValue = @(M_PI * 2);
        transformAnima.repeatCount = HUGE_VALF;
        transformAnima.speed = 0.25;
        transformAnima.removedOnCompletion = NO;
        transformAnima.fillMode = kCAFillModeForwards;
        
        [self.loaddingImageView.layer addAnimation:transformAnima forKey:nil];
    }
    return self;
}

- (UIImageView *)loaddingImageView {
    if (!_loaddingImageView) {
        _loaddingImageView = [[UIImageView alloc] initWithImage:[self getLoadingImage]];
    }
    return _loaddingImageView;
}

//纯色背景图
- (UIImage *)getLoadingImage{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(50, 50), NO, 0.0);
    CGContextRef cxtRef = UIGraphicsGetCurrentContext();
    
    CGPoint center = CGPointMake(25, 25);
    CGFloat radius = 23;
    CGFloat startA = 0;
    CGFloat endA = M_PI * 1.5;
    BOOL clockwise = YES;
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center radius:radius startAngle:startA endAngle:endA clockwise:clockwise];
    [[UIColor whiteColor] setStroke];
    [path stroke];

    CGContextAddPath(cxtRef, path.CGPath);
    CGContextClip(cxtRef);
    UIImage *clipImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return clipImg;
}

@end
