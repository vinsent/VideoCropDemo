//
//  VideoCropViewController.m
//  VideoCropDemo
//
//  Created by vinsent on 2020/7/17.
//  Copyright © 2020 vinsent. All rights reserved.
//

#import "VideoCropViewController.h"
#import "VideoCoverCell.h"
#import "VideoCropSliderView.h"
#import <AVFoundation/AVFoundation.h>
#import <Masonry/Masonry.h>

static inline CGFloat safeAreaInsetTop() {
    CGFloat top = 20;
    if (@available(iOS 11.0, *)) {
        top = MAX(UIApplication.sharedApplication.keyWindow.safeAreaInsets.top, 20);
    }
    return top;
}

static inline CGFloat safeAreaInsetBottom() {
    CGFloat bottom = 0;
    if (@available(iOS 11.0, *)) {
        bottom = UIApplication.sharedApplication.keyWindow.safeAreaInsets.bottom;
    }
    return bottom;
}

@interface VideoCropViewController ()

@property (nonatomic, strong) AVPlayerItem *item;

@property (nonatomic, strong) UIButton *backButton;

@property (nonatomic, strong) UIButton *finishButton;

@property (nonatomic, strong) UILabel *titleLabel;

@property (nonatomic, strong) AVPlayer *player;

@property (nonatomic, strong) AVPlayerLayer *playerLayer;

@property (nonatomic, strong) UIButton *pauseButton;

@property (nonatomic, strong) VideoCropSliderView *editView;

@property (nonatomic, strong) UIVisualEffectView *effectView;

@property (nonatomic, strong) UILabel *choosedLabel;

@property (nonatomic, strong) id timeObserverToken;

@property (nonatomic, assign, getter=isUserPause) BOOL userPause;
@property (nonatomic, assign, getter=isDragging) BOOL dragging;

@end

@implementation VideoCropViewController

- (instancetype)init {
    if (self = [super init]) {
        NSURL *file = [[NSBundle mainBundle] URLForResource:@"IMG_8849" withExtension:@"MP4"];
        _item = [[AVPlayerItem alloc] initWithURL:file];
        self.player = [AVPlayer playerWithPlayerItem:_item];
    }
    return self;
}

- (void)loadView {
    [super loadView];
    [self initializeSubviews];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.blackColor;
    
    [self addActions];
    
    self.choosedLabel.text = [NSString stringWithFormat:@"已选择%.1fs", CMTimeGetSeconds(self.editView.selecteRange.duration)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.player seekToTime:self.editView.startTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    [self.player play];
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [self.player pause];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    }
}

- (void)dealloc {
    [self.player removeTimeObserver:self.timeObserverToken];
}

- (void)viewTapAction {
    if (self.player.rate == 0) {
        [self.player play];
        self.pauseButton.hidden = YES;
    } else {
        [self.player pause];
        self.pauseButton.hidden = NO;
    }
}

// Getter
- (BOOL)isUserPause {
    return !self.pauseButton.isHidden;
}

- (void)addActions {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewTapAction)];
    [self.view addGestureRecognizer:tap];
    [self.pauseButton addTarget:self action:@selector(viewTapAction) forControlEvents:UIControlEventTouchUpInside];
    [self.backButton addTarget:self action:@selector(backAction) forControlEvents:UIControlEventTouchUpInside];
    [self.finishButton addTarget:self action:@selector(finishAction) forControlEvents:UIControlEventTouchUpInside];
    __weak typeof(self) weakSelf = self;
    self.timeObserverToken = [self.player addPeriodicTimeObserverForInterval:CMTimeMakeWithSeconds(0.01, NSEC_PER_SEC) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf.editView syncIndicatorWithTime:time];
        
        CMTime end = CMTimeMinimum(strongSelf.editView.endTime, strongSelf.item.asset.duration);
        if (CMTimeCompare(strongSelf.player.currentTime, end) >= 0 && !strongSelf.isUserPause && !strongSelf.isDragging) {
            [strongSelf.player pause];
            [strongSelf.player seekToTime:strongSelf.editView.startTime toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
            [strongSelf.player play];
        }
        
    }];
    
    self.editView.editViewWillBeginDragging = ^{
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf setDragging:YES];
        [strongSelf.player pause];
    };
    
    self.editView.editViewDidEndDragging = ^{
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf setDragging:NO];
        
        if (!strongSelf.isUserPause) {
            [strongSelf.player play];
        }
    };
    
    [self.editView setTimeChangingBlock:^(CMTime time) {
        __strong typeof(self) strongSelf = weakSelf;
        [strongSelf seekToTime:time];
    }];
    
    [self.editView setSelectRangeChangedBlock:^(CMTimeRange range) {
        __strong typeof(self) strongSelf = weakSelf;
        strongSelf.choosedLabel.text = [NSString stringWithFormat:@"已选择%.1fs", CMTimeGetSeconds(range.duration)];
    }];
}

- (void)seekToTime:(CMTime)time {
    [self.player seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
    [self.editView syncIndicatorWithTime:time];
}

- (void)finishAction {
    CMTimeRange range = self.self.editView.selecteRange;
    NSLog(@"selected video range, start time: %.1fs, duration: %.1fs", CMTimeGetSeconds(range.start), CMTimeGetSeconds(range.duration));
    [self backAction];
}

- (void)backAction {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)initializeSubviews {
    [self initNavigationView];
    [self initEditEffectView];
    [self.view addSubview:self.editView];
    [self.view addSubview:self.choosedLabel];
    [self.view addSubview:self.pauseButton];
    [self.editView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.height.mas_equalTo(80);
        make.top.equalTo(self.effectView).mas_offset(49);
    }];
    [self.choosedLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(18);
        make.bottom.equalTo(self.editView.mas_top).mas_offset(-5);
    }];
    [self.pauseButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
    }];
    self.pauseButton.hidden = YES;
    self.playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    self.playerLayer.frame = CGRectMake(0, safeAreaInsetTop(), CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds) - safeAreaInsetTop() - safeAreaInsetBottom() - 44);
    self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.playerLayer.masksToBounds = YES;
    self.playerLayer.cornerRadius = 16.f;
    [self.view.layer insertSublayer:self.playerLayer atIndex:0];
}

- (void)initNavigationView {
    UIView *navigationView = [UIView new];
    [self.view addSubview:navigationView];
    [navigationView addSubview:self.backButton];
    [navigationView addSubview:self.finishButton];
    [navigationView addSubview:self.titleLabel];
    [navigationView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(safeAreaInsetTop());
        make.left.right.equalTo(self.view);
        make.height.mas_equalTo(44);
    }];
    [self.titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(navigationView);
    }];
    [self.finishButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.titleLabel);
        make.right.mas_equalTo(-16);
        make.width.mas_equalTo(64);
        make.height.mas_equalTo(32);
    }];
    [self.backButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.titleLabel);
        make.left.mas_equalTo(16);
        make.height.mas_equalTo(44);
        make.width.mas_equalTo(60);
    }];
}

- (void)initEditEffectView {
    _effectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleDark]];
    [self.view addSubview:_effectView];
    CGFloat effectHeight = safeAreaInsetBottom() + 160;
    [_effectView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.view);
        make.height.mas_equalTo(effectHeight);
    }];
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), effectHeight) byRoundingCorners:UIRectCornerTopLeft|UIRectCornerTopRight cornerRadii:CGSizeMake(16, 16)];
    CAShapeLayer *shapeLayer = [CAShapeLayer layer];
    shapeLayer.path = path.CGPath;
    _effectView.layer.mask = shapeLayer;
}

- (UIButton *)backButton {
    if (!_backButton) {
        _backButton = [UIButton buttonWithType:UIButtonTypeCustom];
//        [_backButton setImage:[UIImage imageNamed:@"DetailBack"] forState:UIControlStateNormal];
        [_backButton setTitle:@"Back" forState:UIControlStateNormal];
    }
    return _backButton;
}

- (UIButton *)finishButton {
    if (!_finishButton) {
        _finishButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [_finishButton setTitle:@"完成" forState:UIControlStateNormal];
        [_finishButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        _finishButton.backgroundColor = UIColor.redColor;
        _finishButton.titleLabel.font = [UIFont systemFontOfSize:16];
        _finishButton.layer.cornerRadius = 4.f;
        _finishButton.layer.masksToBounds = YES;
    }
    return _finishButton;
}

- (UILabel *)titleLabel {
    if (!_titleLabel) {
        _titleLabel = [UILabel new];
        _titleLabel.textColor = UIColor.whiteColor;
        _titleLabel.font = [UIFont systemFontOfSize:16];
        _titleLabel.text = @"选择视频范围";
    }
    return _titleLabel;
}

- (UILabel *)choosedLabel {
    if (!_choosedLabel) {
        _choosedLabel = [UILabel new];
        _choosedLabel.textColor = UIColor.whiteColor;
        _choosedLabel.font = [UIFont systemFontOfSize:14];
    }
    return _choosedLabel;
}

- (UIButton *)pauseButton {
    if (!_pauseButton) {
        _pauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
//        [_pauseButton setImage:[UIImage imageNamed:@"VideoEditSlidePause"] forState:UIControlStateNormal];
        [_pauseButton setTitle:@"暂停" forState:UIControlStateNormal];
    }
    return _pauseButton;
}

- (VideoCropSliderView *)editView {
    if (!_editView) {
        _editView = [[VideoCropSliderView alloc] initWithFrame:CGRectMake(0, 600, CGRectGetWidth(self.view.bounds), 80) asset:self.item.asset];
    }
    return _editView;
}

@end
