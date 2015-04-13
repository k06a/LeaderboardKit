//
//  LKLeaderboard.m
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import "LeaderboardKit.h"
#import "LKPlayer.h"
#import "LKLeaderboard.h"

@interface LKLeaderboard ()

@property (nonatomic, strong) LKPlayerScore *localPlayerScore;
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
    NSUInteger index = [self.sortedScores indexOfObjectPassingTest:^BOOL(LKPlayerScore *obj, NSUInteger idx, BOOL *stop) {
        for (id<LKAccount> account in [LeaderboardKit shared].accounts) {
            LKPlayer *accountPlayer = [account localPlayer];
            if ([accountPlayer.account_id isEqualToString:obj.player.account_id] && [obj.player.accountType isEqualToString:accountPlayer.accountType])
                return YES;
        }
        return [obj.player.recordID isEqual:[LeaderboardKit shared].userRecord.recordID];
    }];
    self.localPlayerScore = (index == NSNotFound) ? nil : self.sortedScores[index];
}

@end
