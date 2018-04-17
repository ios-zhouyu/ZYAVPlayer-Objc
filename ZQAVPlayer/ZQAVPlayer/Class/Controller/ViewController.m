//
//  ViewController.m
//  ZQAVPlayer
//
//  Created by zhouyu on 2018/4/10.
//  Copyright © 2018 zhouyu. All rights reserved.
//

#import "ViewController.h"
#import "ZYPlayerController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"视频播放demo";
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(50, 250, 300, 60)];
    [button setTitle:@"点击播放" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    button.backgroundColor = [UIColor darkGrayColor];
    [self.view addSubview:button];
    [button addTarget:self action:@selector(buttonClick) forControlEvents:UIControlEventTouchUpInside];
    
}

- (void)buttonClick{
    [self.navigationController pushViewController:[[ZYPlayerController alloc] init] animated:YES];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:NO];
}

//- (void)viewDidAppear:(BOOL)animated {
//    [super viewDidAppear:animated];
//
////    http://static.smartisanos.cn/common/video/proud-farmer.mp4
////    http://bos.nj.bpc.baidu.com/tieba-smallvideo/11772_3c435014fb2dd9a5fd56a57cc369f6a0.mp4
//    //http://dlhls.cdn.zhanqi.tv/zqlive/22578_yKdJM.m3u8
//    //http://218.22.1.146:9090/server/static/study/video/2018/01/18/20180118172604551.MP4
//    NSString *baseURLString = @"http://img.aifootball365.cn/appbi/tmp/video";
//    NSString *typeString = @"mpeg4_xvid_aac.mp4";
//    NSString *urlString = @"http://bos.nj.bpc.baidu.com/tieba-smallvideo/11772_3c435014fb2dd9a5fd56a57cc369f6a0.mp4";
////    self.playerView.urlString = [NSString stringWithFormat:@"%@/%@",baseURLString,typeString];
//    self.playerView.urlString = urlString;
//}
/*
 正常播放
 avc_h264_aac.mov          : video/quicktime
 mjpeg_pcm.avi                : video/x-msvideo
 mpeg4_xvid_aac.mp4     : video/mp4
 
 
 能播放,但是没有声音,没有图像
 avc_h264_mp3_vbr.avi         : video/x-msvideo
 h263_arm_wb.3gp                : video/3gpp
 mpeg4_divx_arm_nb.3gp     : video/3gpp
 
 
  播放不出来
 mpeg2_av3.vob        : text/html
 flv1_mp3.flv             : video/x-flv
 flv1_mp3.swf            : application/x-shockwave-flash
 hevc_h264_ac3.mkv : text/plain
 mjpeg_mp3.swf        : application/x-shockwave-flash
 mpeg1_mp2.mpg      : video/mpeg
 vp8_opus.webm        : video/webm
 vp9_vorbis.webm      : video/webm
 wmv2_wmav2.wmv  : video/x-ms-wmv
 */

#pragma mark - ZYPlayerViewDelegate
- (void)swiftPlayScreenWithFullScreenButton:(UIButton *)button {
    
}



@end
