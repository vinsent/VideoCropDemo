//
//  VideoCropSliderView.h
//  VideoCropDemo
//
//  Created by vinsent on 2020/7/17.
//  Copyright © 2020 vinsent. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class VideoCoverCell;

NS_ASSUME_NONNULL_BEGIN

@interface VideoCropSliderView : UIView

@property (nonatomic, assign, readonly) CMTime startTime;
@property (nonatomic, assign, readonly) CMTime endTime;
@property (nonatomic, assign, readonly) CMTimeRange selecteRange;

@property (nonatomic, copy) void(^timeChangingBlock)(CMTime time);
@property (nonatomic, copy) void(^selectRangeChangedBlock)(CMTimeRange range);

@property (nonatomic, nullable, copy) void(^editViewWillBeginDragging)(void);
@property (nonatomic, nullable, copy) void(^editViewDidEndDragging)(void);

- (instancetype)initWithFrame:(CGRect)frame asset:(AVAsset *)asset;

- (void)syncIndicatorWithTime:(CMTime)time;

@end

NS_ASSUME_NONNULL_END
