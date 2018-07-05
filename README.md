# ZQAVPlayer-Objc

ZQAVPlayer-Objc简易的视频播放器,基于AVPlayer,播放,暂停,拖拽指定时间播放,等基本功能都已实现

`QQ: 1512450002 欢迎沟通交流`

```
使用简单

    ZQPlayerView *playerView = [[ZQPlayerView alloc] init];
    playerView.delegate = self;
    [self.view addSubview:playerView];
    self.playerView = playerView;


    NSString *urlString = @"http://bos.nj.bpc.baidu.com/tieba-smallvideo/11772_3c435014fb2dd9a5fd56a57cc369f6a0.mp4";
    self.playerView.urlString = urlString;
```

```
//视频编码和音频编码组合播放测试
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
```

##效果图

<p align="center" >
<span>效果图.png</span>
<img src="视频播放.gif">
</p>
