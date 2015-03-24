//
//  LKScoreTableViewCell.m
//  LeaderboardKit
//
//  Created by Anton Bukov on 24.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import "LKScoreTableViewCell.h"

@interface LKScoreTableViewCell ()

@property (nonatomic, strong) UILabel *rankLabel;

@end

@implementation LKScoreTableViewCell

- (UILabel *)rankLabel
{
    if (_rankLabel == nil) {
        _rankLabel = [[UILabel alloc] init];
        _rankLabel.textAlignment = NSTextAlignmentCenter;
        _rankLabel.font = [UIFont systemFontOfSize:24];
        _rankLabel.minimumScaleFactor = 0.6;
        [self.contentView addSubview:_rankLabel];
    }
    return _rankLabel;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat width = self.indentationLevel * self.indentationWidth;
    self.imageView.frame = CGRectOffset(self.imageView.frame, width, 0);
    self.rankLabel.frame = CGRectMake(10, 0, width, self.contentView.bounds.size.height);
}

@end
