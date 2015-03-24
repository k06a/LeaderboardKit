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

- (LKPlayerScore *)findScoreWithAccountId:(NSString *)account_id
{
    for (LKPlayerScore *score in self.sortedScores) {
        if ([score.player.account_id isEqualToString:account_id])
            return score;
    }
    return nil;
}

- (LKPlayerScore *)findScoreWithUserRecordID:(CKRecordID *)recordID
{
    for (LKPlayerScore *score in self.sortedScores) {
        if ([score.player.recordID isEqual:recordID])
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
