//
//  VideoCoverCell.m
//  VideoCropDemo
//
//  Created by vinsent on 2020/4/22.
//  Copyright © 2020 vinsent. All rights reserved.
//

#import "VideoCoverCell.h"
#import <Masonry/Masonry.h>

@interface VideoCoverCell ()

@property (nonatomic, strong) UIImageView *imageView;

@end

@implementation VideoCoverCell

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.contentView.layer.masksToBounds = YES;
        [self.contentView addSubview:self.imageView];
        [self.imageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.contentView);
        }];
    }
    return self;
}

- (void)fillWithImage:(UIImage *)image {
    self.imageView.image = image;
}

- (UIImageView *)imageView {
    if (!_imageView) {
        _imageView = [UIImageView new];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
    }
    return _imageView;
}

@end
