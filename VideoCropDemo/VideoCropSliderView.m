//
//  VideoCropSliderView.m
//  VideoCropDemo
//
//  Created by vinsent on 2020/7/17.
//  Copyright © 2020 vinsent. All rights reserved.
//

#import "VideoCropSliderView.h"
#import "VideoCoverCell.h"
#import <Masonry/Masonry.h>

// collection view height
static const CGFloat CellHeight = 72.f;
static const CGFloat CellWidth = CellHeight * 0.5;

// 截取大小限制
static const CGFloat CropDurationMaxLimit = 180.f;
static const CGFloat CropDurationMinLimit = 4.f;

@interface VideoCropSliderView () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate> {
    NSTimeInterval _rightMovedInterval;
}

@property (nonatomic, strong) UIImageView *leftView;

@property (nonatomic, strong) UIImageView *rightView;

@property (nonatomic, strong) UIView *leftMask;

@property (nonatomic, strong) UIView *rightMask;

@property (nonatomic, strong) UIView *scheduleIndicator;

@property (nonatomic, strong) UICollectionView *collectionView;

@property (nonatomic, strong) UICollectionViewFlowLayout *layout;

@property (nonatomic, strong) NSMutableArray<NSValue *> *frameTimes;
@property (nonatomic, strong) NSMutableDictionary<NSIndexPath *, UIImage *> *frameImages;

@property (nonatomic, strong) UIView *topView;

@property (nonatomic, strong) UIView *bottomView;

@property (nonatomic, strong) AVAsset *asset;

@property (nonatomic, strong) AVAssetImageGenerator *imageGenerator;

@property (nonatomic, assign) CGFloat startLocation;
@property (nonatomic, assign) CGFloat endLocation;

@property (nonatomic, assign) CGFloat assetDuration;
@property (nonatomic, assign) CGFloat collectionOriginWidth;

/// collection content size.width
@property (nonatomic, assign) CGFloat collectionWidth;

@property (nonatomic, assign) CMTime startTime;
@property (nonatomic, assign) CMTime endTime;
@property (nonatomic, assign) CMTimeRange selecteRange;

@property (nonatomic, assign) CGFloat leftOffset;

@property (nonatomic, assign) CGFloat leftViewMaxX;
@property (nonatomic, assign) CGFloat rightViewMinX;

@end

@implementation VideoCropSliderView

- (instancetype)initWithFrame:(CGRect)frame asset:(AVAsset *)asset {
    if (self = [super initWithFrame:frame]) {
        _asset = asset;
        
        _assetDuration = CMTimeGetSeconds(asset.duration);
        _collectionOriginWidth = CGRectGetWidth(self.frame) - self.collectionView.contentInset.left - self.collectionView.contentInset.right;
        
        CGFloat dur = MIN(_assetDuration, CropDurationMaxLimit);
        _collectionWidth = _assetDuration / dur * _collectionOriginWidth;
        
        _startTime = CMTimeMakeWithSeconds(0, _asset.duration.timescale);
        _endTime = CMTimeMakeWithSeconds(dur, _asset.duration.timescale);
        _selecteRange = CMTimeRangeFromTimeToTime(_startTime, _endTime);
        
        _frameTimes = [NSMutableArray array];
        _rightMovedInterval = 0;
        [self initializeSubviews];
        
        [self initGesture];
        
        [self reloadCollectionData];
    }
    return self;
}

- (void)reloadCollectionData {
    CGFloat lastCellWidth = [self lastCellWidth];
    BOOL isHaveLastCell = lastCellWidth > 0;
    NSInteger count = _collectionWidth / CellWidth + (isHaveLastCell ? 1 : 0);
    
    [self.frameTimes removeAllObjects];
    [self.frameImages removeAllObjects];
    [self.imageGenerator cancelAllCGImageGeneration];
    
    CGFloat location = 0.f;
    for (NSInteger i = 0; i < count; i++) {
        CMTime time = [self convertToTimeWithLocation:location];
        [self.frameTimes addObject:[NSValue valueWithCMTime:time]];
        
        if (i == count - 1) {
            location += isHaveLastCell ? lastCellWidth : CellWidth;
        } else {
            location += CellWidth;
        }
    }
    [self.collectionView reloadData];
}

- (void)resetCollectionData {
    
    _startLocation = [self calculateStartLocation];
    _endLocation = [self calculateEndLocation];
    
    _startTime = [self convertToTimeWithLocation:self.startLocation];
    _endTime = [self convertToTimeWithLocation:self.endLocation];
    CMTimeRange newRange = CMTimeRangeFromTimeToTime(_startTime, _endTime);
    
    if (CMTimeCompare(newRange.duration, _selecteRange.duration) == 0) {
        _selecteRange = newRange;
        return;
    }
    
    _selecteRange = newRange;
    
    CGFloat dur = CMTimeGetSeconds(_selecteRange.duration);
    
    _collectionWidth = _assetDuration / dur * _collectionOriginWidth;
    
    // offset
    CGFloat off = [self convertToLocationWithTime:_startTime] - self.collectionView.contentInset.left;
    
    [self reloadCollectionData];
    
    self.collectionView.contentOffset = CGPointMake(off, 1.f);
    
    self.leftOffset = off;
}

- (CGFloat)lastCellWidth {
    return ((NSInteger)(_collectionWidth * 1000)) % ((NSInteger)(CellWidth * 1000)) / 1000.0;
}

- (CMTime)convertToTimeWithLocation:(CGFloat)location {
    return CMTimeMakeWithSeconds(location / _collectionWidth * _assetDuration, self.asset.duration.timescale);
}

- (CGFloat)convertToLocationWithTime:(CMTime)time {
    return CMTimeGetSeconds(time) / _assetDuration * _collectionWidth;
}

- (CGFloat)calculateStartLocation {
    return CGRectGetMaxX(self.leftView.frame) + self.collectionView.contentOffset.x;
}

- (CGFloat)calculateEndLocation {
    return CGRectGetMinX(self.rightView.frame) + self.collectionView.contentOffset.x;
}

- (void)initGesture {
    UIPanGestureRecognizer *leftPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleLeftPanGesture:)];
    [self.leftView addGestureRecognizer:leftPan];
    
    UIPanGestureRecognizer *rightPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleRightPanGesture:)];
    [self.rightView addGestureRecognizer:rightPan];
    
    UIPanGestureRecognizer *slidePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleSlideViewtPanGesture:)];
    [self.scheduleIndicator addGestureRecognizer:slidePan];
}

- (void)initializeSubviews {
    [self addSubview:self.collectionView];
    [self addSubview:self.leftMask];
    [self addSubview:self.rightMask];
    [self addSubview:self.leftView];
    [self addSubview:self.rightView];
    _topView = [UIView new];
    _bottomView = [UIView new];
    _topView.backgroundColor = UIColor.redColor;
    _bottomView.backgroundColor = UIColor.redColor;
    [self addSubview:_topView];
    [self addSubview:_bottomView];
    [self addSubview:self.scheduleIndicator];
    [self.collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self);
        make.top.bottom.equalTo(self).inset(4);
    }];
    [self.leftView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.mas_equalTo(self.mas_left).offset(self.collectionView.contentInset.left);
        make.top.bottom.equalTo(self).inset(4);
        make.width.mas_equalTo(24);
    }];
    [self.rightView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.mas_left).offset(self.collectionView.contentInset.left + _collectionOriginWidth);
        make.top.bottom.width.equalTo(self.leftView);
    }];
    [self.leftMask mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self);
        make.top.bottom.equalTo(self.leftView);
        make.right.equalTo(self.leftView.mas_right);
    }];
    [self.rightMask mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self);
        make.top.bottom.equalTo(self.rightView);
        make.left.equalTo(self.rightView.mas_left);
    }];
    [self.scheduleIndicator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self);
        make.width.mas_equalTo(6);
        make.height.mas_equalTo(80);
        make.centerX.equalTo(self.mas_left).offset(self.collectionView.contentInset.left);
    }];
    [_topView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.leftView);
        make.left.equalTo(self.leftView.mas_right);
        make.right.equalTo(self.rightView.mas_left);
        make.height.mas_equalTo(2);
    }];
    [_bottomView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.leftView);
        make.left.right.height.equalTo(_topView);
    }];
}

- (void)syncIndicatorWithTime:(CMTime)time {
    CGFloat x = [self convertToLocationWithTime:time];
    CGPoint p = [self.collectionView convertPoint:CGPointMake(x, 1.f) toView:self];
    [self.scheduleIndicator mas_updateConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.mas_left).offset(p.x);
    }];
}

#pragma mark -

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    if (self.editViewWillBeginDragging) {
        self.editViewWillBeginDragging();
    }
}

- (void)handleTouchEnded {
    [self resetCollectionData];
    
    [self.leftView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.right.mas_equalTo(self.mas_left).offset(self.collectionView.contentInset.left);
    }];
    [self.rightView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.mas_left).offset(self.collectionView.contentInset.left + _collectionOriginWidth);
    }];
    [UIView animateWithDuration:0.4 animations:^{
        [self layoutIfNeeded];
    }];
    
    if (self.editViewDidEndDragging) {
        self.editViewDidEndDragging();
    }
}

- (CGFloat)limitMinWidth {
    return CropDurationMinLimit / _assetDuration * _collectionWidth;
}

- (CGFloat)limitMaxWidth {
    return CropDurationMaxLimit / _assetDuration * _collectionWidth;
}

- (void)timeChangedWithLocation:(CGFloat)x {
    CGPoint p = [self convertPoint:CGPointMake(x, 1.f) toView:self.collectionView];
    
    CMTime time = [self convertToTimeWithLocation:p.x];
    
    if (self.timeChangingBlock) {
        self.timeChangingBlock(time);
    }
    
    CGFloat startP = [self calculateStartLocation];
    CGFloat endP = [self calculateEndLocation];
    CMTime startT = [self convertToTimeWithLocation:startP];
    CMTime endT = [self convertToTimeWithLocation:endP];
    CMTimeRange range = CMTimeRangeFromTimeToTime(startT, endT);
    
    if (self.selectRangeChangedBlock) {
        self.selectRangeChangedBlock(range);
    }
}

- (void)handleLeftPanGesture:(UIPanGestureRecognizer *)ges {
    switch (ges.state) {
        case UIGestureRecognizerStateBegan: {
            _rightViewMinX = CGRectGetMinX(self.rightView.frame);
        }
            break;
        case UIGestureRecognizerStateChanged: {
            CGPoint point = [ges locationInView:self];
            
            if (point.x < self.collectionView.contentInset.left && [ges velocityInView:self].x <= 0) {
                
                point = [ges translationInView:self];
                
                if (self.leftOffset <= -self.collectionView.contentInset.left) {
                    return;
                }
                
                // 12.f buffer
                CGFloat xAll = self.collectionView.contentInset.left - 12.f;
                
                // 移动距离
                CGFloat x = fabs(point.x);
                
                CGFloat off = self.leftOffset;
                
                CGFloat move = x / xAll * (off + self.collectionView.contentInset.left);
                
                off -= move;
                
                off = MAX(off, -self.collectionView.contentInset.left);
                
                [self synchroniseRightViewWithScrollViewOffset:off];
                
            } else {
                
                CGFloat leftX = point.x;
                CGFloat maxLeftX = CGRectGetMinX(self.rightView.frame) - [self limitMinWidth];
                leftX = MIN(leftX, maxLeftX);
                leftX = MAX(leftX, self.collectionView.contentInset.left);
                
                [self.leftView mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.right.mas_equalTo(self.mas_left).offset(leftX);
                }];
                
                _leftOffset = self.collectionView.contentOffset.x;
                _rightViewMinX = CGRectGetMinX(self.rightView.frame);
            }
            
            [self timeChangedWithLocation:CGRectGetMaxX(self.leftView.frame)];
        }
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            [self handleTouchEnded];
            break;
        default:
            break;
    }
}

- (void)handleRightPanGesture:(UIPanGestureRecognizer *)ges {
    switch (ges.state) {
        case UIGestureRecognizerStateBegan: {
            _leftViewMaxX = CGRectGetMaxX(self.leftView.frame);
        }
            break;
        case UIGestureRecognizerStateChanged: {
            CGPoint point = [ges locationInView:self];
            
            if (point.x > CGRectGetWidth(self.bounds) - self.collectionView.contentInset.right && [ges velocityInView:self].x >= 0) {
                
                point = [ges translationInView:self];
                
                CGFloat maxOffset = self.collectionView.contentSize.width - CGRectGetWidth(self.collectionView.frame) + self.collectionView.contentInset.left;
                
                // 12.f buffer
                CGFloat xAll = self.collectionView.contentInset.right - 12.f;
                
                CGFloat x = fabs(point.x);
                
                
                CGFloat off = self.leftOffset;
                
                CGFloat move = x / xAll * (maxOffset - (off));
                
                off += move;
                
                off = MIN(off, maxOffset);
                
                [self synchroniseLeftViewWithScrollViewOffset:off];
                
            } else {
                CGFloat totalWidth = CGRectGetWidth(self.bounds);
                
                CGFloat rightX = totalWidth - point.x;
                CGFloat leftValue = CGRectGetMaxX(self.leftView.frame);
                CGFloat maxRightX = totalWidth - leftValue - [self limitMinWidth];
                rightX = MIN(rightX, maxRightX);
                rightX = MAX(rightX, self.collectionView.contentInset.right);
                
                [self.rightView mas_updateConstraints:^(MASConstraintMaker *make) {
                    make.left.mas_equalTo(self.mas_left).offset(CGRectGetWidth(self.bounds) - rightX);
                }];
                
                _leftOffset = self.collectionView.contentOffset.x;
                _leftViewMaxX = CGRectGetMaxX(self.leftView.frame);
            }
            
            [self timeChangedWithLocation:CGRectGetMinX(self.rightView.frame)];
        }
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            [self handleTouchEnded];
            break;
        default:
            break;
    }
}

- (void)handleSlideViewtPanGesture:(UIPanGestureRecognizer *)ges {
    switch (ges.state) {
        case UIGestureRecognizerStateBegan:
            break;
        case UIGestureRecognizerStateChanged: {
            CGPoint point = [ges locationInView:self];
            CGFloat x = MIN(CGRectGetMinX(self.rightView.frame), MAX(CGRectGetMaxX(self.leftView.frame), point.x));
            [self timeChangedWithLocation:x];
        }
            break;
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            if (self.editViewDidEndDragging) {
                self.editViewDidEndDragging();
            }
            break;
        default:
            break;
    }
}

- (void)synchroniseRightViewWithScrollViewOffset:(CGFloat)x {
    x = MAX(x, _rightViewMinX  + _leftOffset - CGRectGetMaxX(self.leftView.frame) - [self limitMaxWidth]);
    
    self.collectionView.contentOffset = CGPointMake(x, 1);
    
    [self.rightView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(self.mas_left).offset(_rightViewMinX + _leftOffset - x);
    }];
    
    [self layoutIfNeeded];
}

- (void)synchroniseLeftViewWithScrollViewOffset:(CGFloat)x {
    x = MIN(x, [self limitMaxWidth] - CGRectGetMinX(self.rightView.frame) + _leftViewMaxX + _leftOffset);
    
    self.collectionView.contentOffset = CGPointMake(x, 1);
    
    [self.leftView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.right.mas_equalTo(self.mas_left).offset(_leftViewMaxX + _leftOffset - x);
    }];
    
    [self layoutIfNeeded];
}

#pragma mark - Scroll view delegate
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (self.editViewWillBeginDragging) {
        self.editViewWillBeginDragging();
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.isDragging) {
        [self timeChangedWithLocation:CGRectGetMidX(self.scheduleIndicator.frame)];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    [self handleTouchEnded];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (!decelerate) {
        [self handleTouchEnded];
    }
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.frameTimes.count;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item == self.frameTimes.count - 1) {
        CGFloat w = [self lastCellWidth];
        if (w > 0) return CGSizeMake(w, CellHeight);
    }
    return CGSizeMake(CellWidth, CellHeight);
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    return [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    VideoCoverCell *coverCell = (VideoCoverCell *)cell;
    NSValue *value = self.frameTimes[indexPath.row];
    if (CMTimeCompare(value.CMTimeValue, coverCell.currentTime) == 0) {
        return;
    }
    
    UIImage *img = self.frameImages[indexPath];
    
    if (img) {
        [coverCell fillWithImage:img];
        coverCell.currentTime = value.CMTimeValue;
    } else {
        AVAssetImageGeneratorCompletionHandler handler = ^(CMTime requestedTime, CGImageRef imageRef, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
            if (result == AVAssetImageGeneratorSucceeded && CMTimeCompare(value.CMTimeValue, requestedTime) == 0) {
                UIImage *image = [UIImage imageWithCGImage:imageRef];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [coverCell fillWithImage:image];
                    coverCell.currentTime = value.CMTimeValue;
                    [self.frameImages setObject:image forKey:indexPath];
                });
            } else {
                NSLog(@"generate image with error => %@", error);
            }
        };
        [self.imageGenerator generateCGImagesAsynchronouslyForTimes:@[value] completionHandler:handler];
    }
}

#pragma mark - Getter
- (UIImageView *)leftView {
    if (!_leftView) {
        _leftView = [UIImageView new];
        _leftView.userInteractionEnabled = YES;
        _leftView.contentMode = UIViewContentModeRight;
        _leftView.image = [UIImage imageNamed:@"VideoEditSlideLeft"];
    }
    return _leftView;
}

- (UIImageView *)rightView {
    if (!_rightView) {
        _rightView = [UIImageView new];
        _rightView.userInteractionEnabled = YES;
        _rightView.contentMode = UIViewContentModeLeft;
        _rightView.image = [UIImage imageNamed:@"VideoEditSlideRight"];
    }
    return _rightView;
}

- (UIView *)leftMask {
    if (!_leftMask) {
        _leftMask = [UIView new];
        _leftMask.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    }
    return _leftMask;
}

- (UIView *)rightMask {
    if (!_rightMask) {
        _rightMask = [UIView new];
        _rightMask.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    }
    return _rightMask;
}

- (UIView *)scheduleIndicator {
    if (!_scheduleIndicator) {
        _scheduleIndicator = [UIView new];
        _scheduleIndicator.backgroundColor = UIColor.whiteColor;
        _scheduleIndicator.layer.cornerRadius = 3.0;
    }
    return _scheduleIndicator;
}

- (UICollectionView *)collectionView {
    if (!_collectionView) {
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:self.layout];
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        [_collectionView registerClass:VideoCoverCell.class forCellWithReuseIdentifier:@"cell"];
        _collectionView.showsHorizontalScrollIndicator = NO;
        _collectionView.showsVerticalScrollIndicator = NO;
        _collectionView.contentInset = UIEdgeInsetsMake(0, 64, 0, 64);
        _collectionView.backgroundColor = UIColor.clearColor;
        _collectionView.bounces = NO;
    }
    return _collectionView;
}

- (UICollectionViewFlowLayout *)layout {
    if (!_layout) {
        _layout = [[UICollectionViewFlowLayout alloc] init];
        _layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        _layout.minimumLineSpacing = 0;
        _layout.minimumInteritemSpacing = 0;
    }
    return _layout;
}

- (AVAssetImageGenerator *)imageGenerator {
    if (!_imageGenerator) {
        _imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:self.asset];
        _imageGenerator.maximumSize = CGSizeMake(300, 300);
        _imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
        _imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
        _imageGenerator.appliesPreferredTrackTransform = YES;
    }
    return _imageGenerator;
}

- (NSMutableDictionary<NSIndexPath *,UIImage *> *)frameImages {
    if (!_frameImages) {
        _frameImages = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    return _frameImages;
}

@end
