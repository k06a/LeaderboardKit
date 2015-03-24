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
            
            for (void(^block)() in self.whenInitializedBlocks)
                block();
            self.whenInitializedBlocks = nil;
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
        if ([UIDevice currentDevice].systemVersion.doubleValue < 8.0)
            return;
        
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
    if (!self.isInitialized || [self idsOrPredicate] == nil) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
    
    if (friends_changed) {
        for (NSString *leaderboardName in @[@"3x3",@"4x4",@"5x5"]) {
            NSInteger myPoints = [[NSUserDefaults standardUserDefaults] integerForKey:[@"max_" stringByAppendingString:leaderboardName]];
            [self subscribeToLeaderboard:leaderboardName withScore:@(myPoints) success:nil failure:nil];
            [self.database saveRecord:self.userRecord completionHandler:^(CKRecord *record, NSError *error) {
                if (error) {
                    NSLog(@"User record saving error: %@", error);
                    return;
                }
                NSLog(@"User record saving success");
            }];
        }
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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

@synthesize cloudLeaderboards = _cloudLeaderboards;

- (NSMutableDictionary *)cloudLeaderboards
{
    if (_cloudLeaderboards == nil)
        _cloudLeaderboards = [NSMutableDictionary dictionary];
    return _cloudLeaderboards;
}

- (void)setCloudLeaderboards:(NSMutableDictionary *)cloudLeaderboards
{
    _cloudLeaderboards = cloudLeaderboards;
    [self calculateCommonLeaderboard];
}

- (LKLeaderboard *)cloudLeaderboardForName:(NSString *)name
{
    return self.cloudLeaderboards[name];
}

- (void)setCloudLeaderboard:(LKLeaderboard *)cloudLeaderboard forName:(NSString *)name
{
    ((id)self.cloudLeaderboards)[name] = cloudLeaderboard;
}

@synthesize commonLeaderboards = _commonLeaderboards;

- (NSDictionary *)commonLeaderboards
{
    if (_commonLeaderboards == nil)
        _commonLeaderboards = [NSMutableDictionary dictionary];
    return _commonLeaderboards;
}

- (void)setCommonLeaderboards:(NSMutableDictionary *)commonLeaderboards
{
    _commonLeaderboards = commonLeaderboards;
    [self calculateCommonLeaderboard];
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
        [self setCommonLeaderboard:leaderboard forName:name];
    }
}

- (void)setupLeaderboardNames:(NSArray *)leaderboardNames
{
    for (NSString *name in leaderboardNames)
        [self setCloudLeaderboard:[[LKLeaderboard alloc] init] forName:name];
}

- (void)updateLeaderboard:(NSString *)leaderboardName
{
    NSString *recordType = [NSString stringWithFormat:@"LeaderboardKit_%@",leaderboardName];
    NSPredicate *predicate = [self idsOrPredicate];
    if (predicate == nil)
        return;
    CKQuery *query = [[CKQuery alloc] initWithRecordType:recordType predicate:predicate];
    query.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"score" ascending:NO]];
    [self.database performQuery:query inZoneWithID:nil completionHandler:^(NSArray *results, NSError *error) {
        NSMutableArray *scores = [NSMutableArray array];
        for (CKRecord *record in results) {
            LKPlayer *player = [[LKPlayer alloc] init];
            player.fullName = record[@"name"];
            player.recordId = record.recordID;
            player.record = record;
            LKPlayerScore *playerScore = [[LKPlayerScore alloc] init];
            playerScore.player = player;
            playerScore.score = record[@"score"];
            [scores addObject:playerScore];
        }
        LKLeaderboard *leaderboard = [self cloudLeaderboardForName:leaderboardName];
        [leaderboard setScores:scores];
    }];
}

- (void)updateLeaderboards
{
    for (NSString *leaderboardName in self.cloudLeaderboards.keyEnumerator)
        [self updateLeaderboard:leaderboardName];
}

- (void)reportScore:(NSNumber *)score forName:(NSString *)name
{
    NSString *score_key = [NSString stringWithFormat:@"LK_score_%@",name];
    CKReference *scoreRef = self.userRecord[score_key];
    
    NSString *recordType = [NSString stringWithFormat:@"LeaderboardKit_%@",name];
    CKRecord *record = ^{
        if (scoreRef.recordID == nil)
            return [[CKRecord alloc] initWithRecordType:recordType];
        return [[CKRecord alloc] initWithRecordType:recordType recordID:scoreRef.recordID];
    }();
    
    id<LKAccount> account = self.accounts.firstObject;
    if ([[account localPlayer] fullName] && ![[account localPlayer] screenName])
        record[@"name"] = [[account localPlayer] fullName];
    else if (![[account localPlayer] fullName] && [[account localPlayer] screenName])
        record[@"name"] = [[account localPlayer] screenName];
    else
        record[@"name"] = [NSString stringWithFormat:@"%@ (%@)",[[account localPlayer] fullName],[[account localPlayer] screenName]];
    record[@"prev_score"] = record[@"score"];
    record[@"score"] = score;
    for (id<LKAccount> account in self.accounts) {
        NSString *key = [NSString stringWithFormat:@"%@_id", [account class]];
        record[key] = [account localPlayer].account_id;
    }
    
    [self.database saveRecord:record completionHandler:^(CKRecord *record, NSError *error) {
        if (error) {
            [self reportScore:score forName:name];
            return;
        }
        if (self.userRecord[score_key] == nil)
            self.userRecord[score_key] = [[CKReference alloc] initWithRecordID:record.recordID action:(CKReferenceActionNone)];
        
        [self updateLeaderboard:name];
    }];
    
    for (id<LKAccount> acc in self.accounts) {
        if ([acc conformsToProtocol:@protocol(LKAccountWithLeaderboards)]) {
            id<LKAccountWithLeaderboards> account = (id)acc;
            [account reportScore:score forName:name];
        }
    }
}

- (void)subscribeToLeaderboard:(NSString *)leaderboardName
                     withScore:(NSNumber *)myScore
                       success:(void(^)())success
                       failure:(void(^)(NSError *))failure
{
    if (self.accounts.count == 0)
        return;
    
    NSPredicate *scorePredicate = [NSPredicate predicateWithFormat:@"(score > %@) AND (prev_score <= %@)", myScore, myScore];
    NSPredicate *predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:@[scorePredicate,self.idsOrPredicate]];
    
    CKNotificationInfo *notificationInfo = [CKNotificationInfo new];
    notificationInfo.alertLocalizationKey = [NSString stringWithFormat:@"LK_NOTIFICATION_%@",leaderboardName];
    notificationInfo.alertLocalizationArgs = @[@"name",@"score"];
    notificationInfo.soundName = @"Party.aiff";
    notificationInfo.shouldBadge = YES;
    
    NSString *recordType = [NSString stringWithFormat:@"LeaderboardKit_%@",leaderboardName];
    CKSubscription *subs = [[CKSubscription alloc] initWithRecordType:recordType predicate:predicate options:(CKSubscriptionOptionsFiresOnRecordUpdate|CKSubscriptionOptionsFiresOnRecordCreation)];
    subs.notificationInfo = notificationInfo;
    
    void(^saveSubscriptionBlock)() = ^{
        [self.database saveSubscription:subs completionHandler:^(CKSubscription *subscription, NSError *error)
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
    };
    
    [self.database fetchAllSubscriptionsWithCompletionHandler:^(NSArray *subscriptions, NSError *error) {
        if (subscriptions.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                saveSubscriptionBlock();
            });
        }
        
        __block NSInteger subscriptionCount = subscriptions.count;
        for (CKSubscription *sub in subscriptions) {
            if ([sub.recordType isEqualToString:recordType]) {
                [self.database deleteSubscriptionWithID:sub.subscriptionID completionHandler:^(NSString *subscriptionID, NSError *error) {
                    if (--subscriptionCount == 0) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            saveSubscriptionBlock();
                        });
                    }
                }];
            } else
                subscriptionCount--;
        }
    }];
}

- (NSPredicate *)idsOrPredicate
{
    NSMutableArray *idsPredicates = [NSMutableArray array];
    for (id<LKAccount> account in self.accounts) {
        NSString *key = [NSString stringWithFormat:@"%@_id",[account class]];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@",key,[account friend_ids]];
        [idsPredicates addObject:predicate];
    }
    if (idsPredicates.count == 0)
        return nil;
    if (idsPredicates.count == 1)
        return idsPredicates.firstObject;
    return [[NSCompoundPredicate alloc] initWithType:NSOrPredicateType subpredicates:idsPredicates];
}

@end
