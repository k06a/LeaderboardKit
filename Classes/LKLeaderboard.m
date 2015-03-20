//
//  LKLeaderboard.m
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import "LKLeaderboard.h"

@interface LKArrayLeaderBoard ()

@property (nonatomic, strong) NSArray *sortedScores;

@end

@implementation LKArrayLeaderBoard

- (void)setScores:(NSArray *)scores
{
    self.sortedScores = [scores sortedArrayUsingComparator:^NSComparisonResult(LKPlayerScore *ps1, LKPlayerScore *ps2) {
        return [ps1.score compare:ps2.score];
    }];
}

@end
