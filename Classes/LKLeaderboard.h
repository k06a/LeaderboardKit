//
//  LKLeaderboard.h
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LKPlayer.h"

@protocol LKLeaderboard <NSObject>

@property (nonatomic, readonly) NSArray *sortedScores;

@end

//

@interface LKArrayLeaderBoard : NSObject <LKLeaderboard>

- (void)setScores:(NSArray *)scores;

@end
