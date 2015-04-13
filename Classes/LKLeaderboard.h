//
//  LKLeaderboard.h
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <CloudKit/CloudKit.h>
#import <Foundation/Foundation.h>

@interface LKLeaderboard : NSObject

@property (nonatomic, readonly) LKPlayerScore *localPlayerScore;
@property (nonatomic, readonly) NSArray *sortedScores;

- (LKPlayerScore *)findScoreWithAccountId:(NSString *)account_id;
- (LKPlayerScore *)findScoreWithUserRecordID:(CKRecordID *)recordID;
- (void)setScores:(NSArray *)scores;

@end
