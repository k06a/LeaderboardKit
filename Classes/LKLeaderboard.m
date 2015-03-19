//
//  LKLeaderboard.m
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import "LKLeaderboard.h"

@implementation LKArrayLeaderBoard

- (void)setSortedScores:(NSArray *)sortedScores
{
    _sortedScores = [sortedScores sortedArrayUsingComparator:^NSComparisonResult(LKPlayerScore *ps1, LKPlayerScore *ps2) {
        return [ps1.score compare:ps2.score];
    }];
}

@end
