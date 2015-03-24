//
//  LKLeaderboard.m
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import "LKPlayer.h"
#import "LKLeaderboard.h"

@interface LKLeaderboard ()

@property (nonatomic, strong) NSArray *sortedScores;

@end

@implementation LKLeaderboard

- (LKPlayerScore *)findAccountWithId:(NSString *)account_id
{
    for (NSInteger i = 0; i < self.sortedScores.count; i++) {
        LKPlayerScore *score = self.sortedScores[i];
        if ([score.player.account_id isEqualToString:account_id])
            return score;
    }
    return nil;
}

- (void)setScores:(NSArray *)scores
{
    self.sortedScores = [scores sortedArrayUsingComparator:^NSComparisonResult(LKPlayerScore *ps1, LKPlayerScore *ps2) {
        return [ps2.score compare:ps1.score];
    }];
}

@end
