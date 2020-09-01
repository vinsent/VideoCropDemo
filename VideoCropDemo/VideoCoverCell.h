//
//  VideoCoverCell.h
//  VideoCropDemo
//
//  Created by vinsent on 2020/4/22.
//  Copyright © 2020 vinsent. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VideoCoverCell : UICollectionViewCell

@property (nonatomic, assign) CMTime currentTime;

- (void)fillWithImage:(UIImage *)image;

@end

NS_ASSUME_NONNULL_END
