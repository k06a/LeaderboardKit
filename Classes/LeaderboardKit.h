//
//  ABLeaderboardKit.h
//  LeaderboardKit
//
//  Created by Anton Bukov on 17.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>
#import "LKPlayer.h"
#import "LKAccount.h"
#import "LKLeaderboard.h"
#import "LKGameCenterAccount.h"
#import "LKTwitterAccount.h"

@interface LeaderboardKit : NSObject

+ (instancetype)shared;

- (void)whenInitialized:(void(^)())block;
@property (nonatomic, readonly) BOOL isInitialized;
@property (nonatomic, strong) CKRecord *userRecord;

- (NSDictionary *)accounts;
- (id<LKAccount>)accountForIdentifier:(NSString *)identifier;
- (void)setAccount:(id<LKAccount>)account forIdentifier:(NSString *)identifier;

- (NSDictionary *)leaderboards;
- (id<LKLeaderboard>)leaderboardForName:(NSString *)name;
- (void)setLeaderboard:(id<LKLeaderboard>)leaderboard forName:(NSString *)name;

- (void)prepareLeaderboardsWithNames:(NSArray *)leaderboardNames;
- (void)updateLeaderboard:(NSString *)leaderboardName;
- (void)updateLeaderboards;

- (void)updateScore:(NSNumber *)score forName:(NSString *)name;

@end
