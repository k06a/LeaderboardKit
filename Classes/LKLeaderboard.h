//
//  LKLeaderboard.h
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LKLeaderboard : NSObject

@property (nonatomic, readonly) NSArray *sortedScores;

- (LKPlayerScore *)findAccountWithId:(NSString *)account_id;
- (void)setScores:(NSArray *)scores;

@end
