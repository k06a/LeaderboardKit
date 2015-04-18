//
//  LeaderboardKit.m
//  LeaderboardKit
//
//  Created by Anton Bukov on 17.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <Social/Social.h>
#import <Accounts/Accounts.h>
#import <CloudKit/CloudKit.h>
#import "LeaderboardKit.h"

NSString *LKLeaderboardChangedNotification = @"LKLeaderboardChangedNotification";

@interface LeaderboardKit ()

@property (nonatomic, strong) NSMutableArray *accounts;
@property (nonatomic, strong) NSMutableDictionary *cloudLeaderboards;
@property (nonatomic, strong) NSMutableDictionary *commonLeaderboards;
@property (nonatomic, strong) NSMutableArray *whenInitializedBlocks;

@property (nonatomic, strong) CKContainer *container;
@property (nonatomic, strong) CKDatabase *database;
@property (nonatomic, strong) CKRecordID *userID;
@property (nonatomic, strong) CKRecord *userRecord;

@end

@implementation LeaderboardKit

#pragma mark - Properties

- (CKContainer *)container
{
    if (_container == nil)
        _container = [CKContainer defaultContainer];
    return _container;
}

- (CKDatabase *)database
{
    if (_database == nil)
        _database = [self.container publicCloudDatabase];
    return _database;
}

- (CKRecordID *)userID
{
    if (_userID == nil) {
        _userID = (id)[NSNull null];
        [self.container fetchUserRecordIDWithCompletionHandler:^(CKRecordID *recordID, NSError *error) {
            if (error) {
                NSLog(@"- (CKRecordID *)userID = %@", error);
                _userID = nil;
                return;
            }
            _userID = recordID;
            [self userRecord];
        }];
    }
    return (_userID != (id)[NSNull null]) ? _userID : nil;
}

- (CKRecord *)userRecord
{
    if (_userRecord == nil) {
        if (self.userID == nil)
            return nil;
        _userRecord = (id)[NSNull null];
        [self.database fetchRecordWithID:self.userID completionHandler:^(CKRecord *record, NSError *error) {
            if (error) {
                NSLog(@"- (CKRecord *)userRecord = %@", error);
                _userRecord = nil;
                [self userRecord];
                return;
            }
            _userRecord = record;
            
            if ([_userRecord[@"LKGameCenter_id"] length]) {
                id<LKAccount> account = [[LKGameCenter alloc] init];
                [self addAccount:account];
            }
            if ([_userRecord[@"LKTwitter_id"] length]) {
                id<LKAccount> account = [[LKTwitter alloc] init];
                [self addAccount:account];
            }
            if ([_userRecord[@"LKFacebook_id"] length]) {
                id<LKAccount> account = [[LKFacebook alloc] init];
                [self addAccount:account];
            }
            if ([_userRecord[@"LKVKontakte_id"] length]) {
                id<LKAccount> account = [[LKVKontakte alloc] init];
                [self addAccount:account];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                for (void(^block)() in self.whenInitializedBlocks)
                    block();
                self.whenInitializedBlocks = nil;
            });
        }];
    }
    return (_userRecord != (id)[NSNull null]) ? _userRecord : nil;
}

#pragma mark - Main

+ (instancetype)shared
{
    static LeaderboardKit *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[LeaderboardKit alloc] init];
        [shared whenInitialized:^{
            [shared checkFriendsChangedRecursively];
            [shared checkLeaderboardsRecursively];
        }];
    });
    return shared;
}

- (NSMutableArray *)whenInitializedBlocks
{
    if (_whenInitializedBlocks == nil)
        _whenInitializedBlocks = [NSMutableArray array];
    return _whenInitializedBlocks;
}

- (void)whenInitialized:(void(^)())block
{
    if (self.isInitialized)
        block();
    else
        [self.whenInitializedBlocks addObject:block];
}

- (BOOL)isInitialized
{
    return (self.userID != nil) && (self.userRecord != nil);
}

- (instancetype)init
{
    if (self = [super init]) {
        [self userID];
    }
    return self;
}

- (void)checkFriendsChangedRecursively
{
    if (!self.isInitialized || [self idsPredicates].count == 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self checkFriendsChangedRecursively];
        });
        return;
    }
    
    BOOL friends_changed = ^{
        for (NSString *key in self.userRecord.changedKeys)
            if ([key rangeOfString:@"_friend_ids"].location != NSNotFound)
                return YES;
        return NO;
    }();
    BOOL user_id_changed = ^{
        for (NSString *name in self.commonLeaderboards.allKeys) {
            NSString *score_key = [NSString stringWithFormat:@"LK_score_%@",name];
            CKReference *scoreRef = self.userRecord[score_key];
            if (scoreRef.recordID == nil)
                continue;

            [self.database fetchRecordWithID:scoreRef.recordID completionHandler:^(CKRecord *scoreRecord, NSError *error) {
                if (scoreRecord == nil || error)
                    return;
                for (id<LKAccount> account in self.accounts) {
                    NSString *kid = [NSString stringWithFormat:@"%@_id", [account class]];
                    scoreRecord[@"prev_score"] = scoreRecord[@"score"];
                    scoreRecord[kid] = [account localPlayer].account_id;
                }
                [self.database saveRecord:scoreRecord completionHandler:nil];
            }];
        }
        
        for (id<LKAccount> account in self.accounts) {
            NSString *kid = [NSString stringWithFormat:@"%@_id", [account class]];
            if ([self.userRecord.changedKeys containsObject:kid])
                return YES;
        }
        return NO;
    }();
    
    if (friends_changed || user_id_changed) {
        [self.database saveRecord:self.userRecord completionHandler:^(CKRecord *record, NSError *error) {
            if (error) {
                NSLog(@"User record saving error: %@", error);
                return;
            }
            NSLog(@"User record saving success");
        }];
    }
    
    if (friends_changed) {
        LKPlayerScore *localScore = ^LKPlayerScore *{
            for (NSString *name in self.commonLeaderboards.allKeys) {
                LKLeaderboard *leaderboard = self.commonLeaderboards[name] ;
                if (leaderboard.localPlayerScore)
                    return leaderboard.localPlayerScore;
            }
            return nil;
        }();
        if (localScore) {
            [self subscribeToLeaderboardsScore:localScore.score success:nil failure:nil];
        }
    }
    
    if (user_id_changed) {
        [self updateLeaderboards];
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self checkFriendsChangedRecursively];
    });
}

- (void)checkLeaderboardsRecursively
{
    if (!self.isInitialized) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self checkLeaderboardsRecursively];
        });
        return;
    }
    
    [self updateLeaderboards];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60*10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self checkLeaderboardsRecursively];
    });
}

#pragma mark - Accounts

- (NSMutableArray *)accounts
{
    if (_accounts == nil)
        _accounts = [NSMutableArray array];
    return _accounts;
}

- (void)addAccount:(id<LKAccount>)account
{
    [(id)self.accounts addObject:account];
}

- (void)removeAccount:(id<LKAccount>)account
{
    [(id)self.accounts removeObject:account];
}

- (id<LKAccount>)accountWithPredicate:(BOOL(^)(id<LKAccount> account))predicate
{
    for (id<LKAccount> account in self.accounts)
        if (predicate(account))
            return account;
    return nil;
}

- (id<LKAccount>)accountWithClass:(Class)class
{
    return [self accountWithPredicate:^BOOL(id<LKAccount> account) {
        return [account isKindOfClass:class];
    }];
}

#pragma mark - Leaderboards

- (NSMutableDictionary *)cloudLeaderboards
{
    if (_cloudLeaderboards == nil)
        _cloudLeaderboards = [NSMutableDictionary dictionary];
    return _cloudLeaderboards;
}

- (LKLeaderboard *)cloudLeaderboardForName:(NSString *)name
{
    return self.cloudLeaderboards[name];
}

- (void)setCloudLeaderboard:(LKLeaderboard *)cloudLeaderboard forName:(NSString *)name
{
    ((id)self.cloudLeaderboards)[name] = cloudLeaderboard;
    [self calculateCommonLeaderboard];
}

- (NSDictionary *)commonLeaderboards
{
    if (_commonLeaderboards == nil)
        _commonLeaderboards = [NSMutableDictionary dictionary];
    return _commonLeaderboards;
}

- (LKLeaderboard *)commonLeaderboardForName:(NSString *)name
{
    return self.commonLeaderboards[name];
}

- (void)setCommonLeaderboard:(LKLeaderboard *)commonLeaderboard forName:(NSString *)name
{
    ((id)self.commonLeaderboards)[name] = commonLeaderboard;
}

- (void)calculateCommonLeaderboard
{
    for (NSString *name in self.cloudLeaderboards) {
        LKLeaderboard *cloudLeaderboard = self.cloudLeaderboards[name];
        NSMutableArray *scores = [NSMutableArray arrayWithArray:cloudLeaderboard.sortedScores];
        for (id<LKAccount> acc in self.accounts) {
            if ([acc conformsToProtocol:@protocol(LKAccountWithLeaderboards)]) {
                id<LKAccountWithLeaderboards> account = (id)acc;
                LKLeaderboard *board = [account leaderboards][name];
                NSString *key = [NSString stringWithFormat:@"%@_id",[acc class]];
                
                if (cloudLeaderboard.sortedScores.count > 0 && [board.localPlayerScore.score compare:cloudLeaderboard.localPlayerScore.score?:@0] == NSOrderedDescending)
                {
                    [self reportScore:board.localPlayerScore.score forName:name];
                }
                
                for (LKPlayerScore *score in board.sortedScores) {
                    BOOL needToAdd = ^{
                        for (LKPlayerScore *cloudScore in scores)
                            if ([score.player.account_id isEqualToString:cloudScore.player.record[key]])
                                return NO;
                        return YES;
                    }();
                    if (needToAdd)
                        [scores addObject:score];
                }
            }
        }
        LKLeaderboard *leaderboard = [[LKLeaderboard alloc] init];
        [leaderboard setScores:scores];
        if (![leaderboard.sortedScores isEqualToArray:[self.commonLeaderboards[name] sortedScores]]) {
            [self setCommonLeaderboard:leaderboard forName:name];
            [[NSNotificationCenter defaultCenter] postNotificationName:LKLeaderboardChangedNotification object:name];
        }
    }
}

- (void)setupLeaderboardNames:(NSArray *)leaderboardNames
{
    for (NSString *name in leaderboardNames) {
        [self setCloudLeaderboard:[[LKLeaderboard alloc] init] forName:name];
        [self setCommonLeaderboard:[[LKLeaderboard alloc] init] forName:name];
    }
}

- (void)updateLeaderboard:(NSString *)leaderboardName
{
    LKLeaderboard *leaderboard = [self cloudLeaderboardForName:leaderboardName];
    
    NSString *recordType = [NSString stringWithFormat:@"LeaderboardKit_%@",leaderboardName];
    for (NSPredicate *predicate in [self idsPredicates]) {
        CKQuery *query = [[CKQuery alloc] initWithRecordType:recordType predicate:predicate];
        query.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"score" ascending:NO]];
        [self.database performQuery:query inZoneWithID:nil completionHandler:^(NSArray *results, NSError *error) {
            NSMutableArray *scores = [NSMutableArray array];
            for (CKRecord *record in results) {
                LKPlayerScore *any = [leaderboard.sortedScores filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(LKPlayerScore *ps, NSDictionary *bindings) {
                    return [ps.player.recordID isEqual:record.recordID];
                }]].firstObject;
                if (any) {
                    any.score = @(MAX(any.score.longLongValue,[record[@"score"] longLongValue]));
                    continue;
                }
                
                LKPlayer *player = [[LKPlayer alloc] init];
                player.fullName = record[@"name"];
                player.recordID = record.recordID;
                player.record = record;
                LKPlayerScore *playerScore = [[LKPlayerScore alloc] init];
                playerScore.player = player;
                playerScore.score = record[@"score"];
                [scores addObject:playerScore];
            }
            [leaderboard setScores:[scores arrayByAddingObjectsFromArray:leaderboard.sortedScores]];
            [self calculateCommonLeaderboard];
        }];
    }
}

- (void)updateLeaderboards
{
    for (NSString *leaderboardName in self.cloudLeaderboards.keyEnumerator)
        [self updateLeaderboard:leaderboardName];
    
    for (id<LKAccount> acc in self.accounts) {
        if ([acc conformsToProtocol:@protocol(LKAccountWithLeaderboards)]) {
            id<LKAccountWithLeaderboards> account = (id)acc;
            [account requestLeaderboardsSuccess:nil failure:nil];
        }
    }
}

- (void)reportScore:(NSNumber *)score forName:(NSString *)name
{
    NSString *score_key = [NSString stringWithFormat:@"LK_score_%@",name];
    CKReference *scoreRef = self.userRecord[score_key];
    if (scoreRef.recordID == nil) {
        NSString *recordType = [NSString stringWithFormat:@"LeaderboardKit_%@",name];
        CKRecord *record = [[CKRecord alloc] initWithRecordType:recordType];
        [self reportScore:score forName:name record:record completion:^{
            if (self.userRecord[score_key] == nil)
                self.userRecord[score_key] = [[CKReference alloc] initWithRecordID:record.recordID action:(CKReferenceActionNone)];
        }];
        return;
    }
    
    [self.database fetchRecordWithID:scoreRef.recordID completionHandler:^(CKRecord *record, NSError *error) {
        if (error) {
            NSLog(@"Error: %@", error);
            [self reportScore:score forName:name];
            return;
        }
        [self reportScore:score forName:name record:record completion:nil];
    }];
}

- (void)reportScore:(NSNumber *)score forName:(NSString *)name record:(CKRecord *)record completion:(void(^)())completion
{
    if (record == nil)
        return;
    
    if ([record[@"score"] isKindOfClass:[NSNumber class]]
        && [score compare:record[@"score"]] != NSOrderedDescending)
    {
        return;
    }
    
    id<LKAccount> account = ^{
        if ([self.accounts.firstObject isKindOfClass:[LKGameCenter class]])
            return self.accounts.lastObject;
        return self.accounts.firstObject;
    }();
    record[@"name"] = [account localPlayer].visibleName;
    record[@"prev_score"] = record[@"score"] ?: 0;
    record[@"score"] = score;
    for (id<LKAccount> account in self.accounts) {
        NSString *key = [NSString stringWithFormat:@"%@_id", [account class]];
        record[key] = [account localPlayer].account_id;
    }
    
    [self.database saveRecord:record completionHandler:^(CKRecord *record, NSError *error) {
        if (error) {
            NSLog(@"Score saving error: %@", error);
            [self reportScore:score forName:name record:record completion:completion];
            return;
        }
        
        [self updateLeaderboard:name];
        if (completion)
            completion();
    }];
    
    for (id<LKAccount> acc in self.accounts) {
        if ([acc conformsToProtocol:@protocol(LKAccountWithLeaderboards)]) {
            id<LKAccountWithLeaderboards> account = (id)acc;
            [account reportScore:score forName:name];
        }
    }
    
    // Update cloud and local leaderboards
    for (NSDictionary *leaderboards in @[self.cloudLeaderboards,self.commonLeaderboards]) {
        LKLeaderboard *leaderboard = leaderboards[name];
        leaderboard.localPlayerScore.score = score;
        [leaderboard setScores:leaderboard.sortedScores];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:LKLeaderboardChangedNotification object:name];
    
    [self subscribeToLeaderboardsScore:score success:nil failure:nil];
}

- (void)subscribeToLeaderboardsScore:(NSNumber *)score
                             success:(void(^)())success
                             failure:(void(^)(NSError *))failure
{
    for (NSString *leaderboardName in self.cloudLeaderboards) {
        [self subscribeToLeaderboard:leaderboardName withScore:score success:nil failure:nil];
    }
}

- (void)subscribeToLeaderboard:(NSString *)leaderboardName
                     withScore:(NSNumber *)myScore
                       success:(void(^)())success
                       failure:(void(^)(NSError *))failure
{
    NSString *recordType = [NSString stringWithFormat:@"LeaderboardKit_%@",leaderboardName];
    if (self.accounts.count == 0)
        return;
    
    CKNotificationInfo *notificationInfo = [CKNotificationInfo new];
    notificationInfo.alertLocalizationKey = [NSString stringWithFormat:@"LK_NOTIFICATION_%@",leaderboardName];
    notificationInfo.alertLocalizationArgs = @[@"name",@"score"];
    notificationInfo.soundName = @"Party.aiff";
    notificationInfo.shouldBadge = YES;

    NSPredicate *scorePredicate = [NSPredicate predicateWithFormat:@"(score > %@) AND (prev_score <= %@)", myScore, myScore];
    
    NSMutableArray *subs = [NSMutableArray array];
    for (NSPredicate *idsPredicate in [self idsPredicates]) {
        NSPredicate *predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:@[scorePredicate,idsPredicate]];
        
        CKSubscription *sub = [[CKSubscription alloc] initWithRecordType:recordType predicate:predicate options:(CKSubscriptionOptionsFiresOnRecordUpdate|CKSubscriptionOptionsFiresOnRecordCreation)];
        sub.notificationInfo = notificationInfo;
        [subs addObject:sub];
    }
    
    void(^saveSubscriptionBlock)() = ^{
        for (CKSubscription *sub in subs) {
            [self.database saveSubscription:sub completionHandler:^(CKSubscription *subscription, NSError *error)
            {
                if (error) {
                    NSLog(@"CloudKit subscription saving error: %@", error.localizedDescription);
                    if (failure)
                        failure(error);
                    return;
                }
                
                NSLog(@"CloudKit subscription saving success!");
                if (success)
                    success();
            }];
            
        }
    };
    
    [self.database fetchAllSubscriptionsWithCompletionHandler:^(NSArray *subscriptions, NSError *error) {
        if (subscriptions.count == 0) {
            saveSubscriptionBlock();
        }
        
        __block NSInteger subscriptionCount = subscriptions.count;
        for (CKSubscription *sub in subscriptions) {
            if ([sub.recordType isEqualToString:recordType]) {
                [self.database deleteSubscriptionWithID:sub.subscriptionID completionHandler:^(NSString *subscriptionID, NSError *error) {
                    if (--subscriptionCount == 0) {
                        saveSubscriptionBlock();
                    }
                }];
            } else
                subscriptionCount--;
        }
    }];
}

- (NSArray *)idsPredicates
{
    NSMutableArray *idsPredicates = [NSMutableArray array];
    for (id<LKAccount> account in self.accounts) {
        NSString *key = [NSString stringWithFormat:@"%@_id",[account class]];
        NSArray *ids = [account friend_ids];
        while (ids.count) {
            NSInteger count = MIN(ids.count, 240);
            NSArray *subids = [ids subarrayWithRange:NSMakeRange(0, count)];
            ids = [ids subarrayWithRange:NSMakeRange(count, ids.count - count)];
            
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@",key,subids];
            [idsPredicates addObject:predicate];
        }
    }
    if (idsPredicates.count == 0)
        return nil;
    return idsPredicates;
}

@end
