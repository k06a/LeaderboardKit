//
//  LeaderboardKit.h
//  LeaderboardKit
//
//  Created by Anton Bukov on 17.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <CloudKit/CloudKit.h>
#import <Foundation/Foundation.h>

#import "LKPlayer.h"
#import "LKAccount.h"
#import "LKLeaderboard.h"
#import "LKGameCenter.h"
#import "LKTwitter.h"
#import "LKFacebook.h"

#import "LKLeaderboardListViewController.h"

extern NSString *LKLeaderboardChangedNotification;

@interface LeaderboardKit : NSObject

+ (instancetype)shared;

- (void)whenInitialized:(void(^)())block;
@property (nonatomic, readonly) BOOL isInitialized;
@property (nonatomic, readonly) CKRecord *userRecord;

#pragma mark - Accounts

- (NSArray *)accounts;
- (void)addAccount:(id<LKAccount>)account;
- (void)removeAccount:(id<LKAccount>)account;
- (id<LKAccount>)accountWithPredicate:(BOOL(^)(id<LKAccount> account))predicate;
- (id<LKAccount>)accountWithClass:(Class)class;

#pragma mark - Leaderboards

- (NSDictionary *)cloudLeaderboards;
- (LKLeaderboard *)cloudLeaderboardForName:(NSString *)name;
- (void)setCloudLeaderboard:(LKLeaderboard *)cloudLeaderboard forName:(NSString *)name;

- (NSDictionary *)commonLeaderboards;
- (LKLeaderboard *)commonLeaderboardForName:(NSString *)name;
- (void)setCommonLeaderboard:(LKLeaderboard *)commonLeaderboard forName:(NSString *)name;
- (void)calculateCommonLeaderboard;

- (void)setupLeaderboardNames:(NSArray *)leaderboardNames;
- (void)updateLeaderboard:(NSString *)leaderboardName;
- (void)updateLeaderboards;

- (void)reportScore:(NSNumber *)score forName:(NSString *)name;

- (void)subscribeToLeaderboard:(NSString *)leaderboardName
                     withScore:(NSNumber *)myScore
                       success:(void(^)())success
                       failure:(void(^)(NSError *))failure;

@end
