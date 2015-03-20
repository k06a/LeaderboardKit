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

@property (nonatomic, strong) NSMutableDictionary *accounts;
@property (nonatomic, strong) NSMutableDictionary *leaderboards;
@property (nonatomic, strong) NSMutableArray *whenInitializedBlocks;

@property (nonatomic, strong) CKContainer *container;
@property (nonatomic, strong) CKDatabase *database;
@property (nonatomic, strong) CKRecordID *userID;

@end

@implementation LeaderboardKit

- (void)checkFriendsChangedRecursively
{
    if (!self.isInitialized) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self checkFriendsChangedRecursively];
        });
    }
    
    BOOL friends_changed = NO;
    for (NSString *key in self.userRecord.changedKeys) {
        if ([key rangeOfString:@"_friend_ids"].location != NSNotFound) {
            friends_changed = YES;
            break;
        }
    }
    
    if (friends_changed) {
        for (NSString *leaderboardName in @[@"3x3",@"4x4",@"5x5"]) {
            NSInteger myPoints = [[NSUserDefaults standardUserDefaults] integerForKey:[@"max_" stringByAppendingString:leaderboardName]];
            [self subscribeToLeaderboard:leaderboardName withScore:@(myPoints) success:nil failure:nil];
        }
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60*5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self checkFriendsChangedRecursively];
    });
}

+ (instancetype)shared
{
    if ([UIDevice currentDevice].systemVersion.doubleValue < 8.0)
        return nil;
    
    static LeaderboardKit *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[LeaderboardKit alloc] init];
        [shared whenInitialized:^{
            [shared checkFriendsChangedRecursively];
            [shared updateLeaderboards];
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

- (NSMutableDictionary *)accounts
{
    if (_accounts == nil)
        _accounts = [NSMutableDictionary dictionary];
    return _accounts;
}

- (id<LKAccount>)accountForIdentifier:(NSString *)identifier
{
    return self.accounts[identifier];
}

- (void)setAccount:(id<LKAccount>)account forIdentifier:(NSString *)identifier
{
    ((id)self.accounts)[identifier] = account;
}

- (NSDictionary *)leaderboards
{
    if (_leaderboards == nil)
        _leaderboards = [NSMutableDictionary dictionary];
    return _leaderboards;
}

- (id<LKLeaderboard>)leaderboardForName:(NSString *)name
{
    return self.leaderboards[name];
}

- (void)setLeaderboard:(id<LKLeaderboard>)leaderboard forName:(NSString *)name
{
    ((id)self.leaderboards)[name] = leaderboard;
}

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
            
            if ([_userRecord[@"LKGameCenterAccount_id"] length]) {
                id<LKAccount> account = [[LKGameCenterAccount alloc] initWithUserRecord:_userRecord];
                [self setAccount:account forIdentifier:LKAccountIdentifierGameCenter];
            }
            if ([_userRecord[@"LKTwitterAccount_id"] length]) {
                id<LKAccount> account = [[LKTwitterAccount alloc] initWithUserRecord:_userRecord];
                [self setAccount:account forIdentifier:LKAccountIdentifierTwitter];
            }
            
            for (void(^block)() in self.whenInitializedBlocks)
                block();
            self.whenInitializedBlocks = nil;
        }];
    }
    return (_userRecord != (id)[NSNull null]) ? _userRecord : nil;
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

- (void)subscribeToLeaderboard:(NSString *)leaderboardName
                     withScore:(NSNumber *)myScore
                       success:(void(^)())success
                       failure:(void(^)(NSError *))failure
{
    if (self.accounts.count == 0)
        return;
    
    NSCompoundPredicate *idsPredicate = ^{
        NSMutableArray *idsPredicates = [NSMutableArray array];
        for (id<LKAccount> account in self.accounts) {
            NSString *key = [NSString stringWithFormat:@"%@_id",[account class]];
            NSPredicate *predicate = [NSPredicate predicateWithFormat:@"%K IN %@",key,[account friend_ids]];
            [idsPredicates addObject:predicate];
        }
        return [[NSCompoundPredicate alloc] initWithType:NSOrPredicateType subpredicates:idsPredicates];
    }();
    NSPredicate *scorePredicate = [NSPredicate predicateWithFormat:@"(score > %@) AND (prev_score < %@)", myScore, myScore];
    NSPredicate *predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:@[scorePredicate,idsPredicate]];
    
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
                 NSLog(@"Error: %@", error.localizedDescription);
                 if (failure)
                     failure(error);
                 return;
             }
             NSLog(@"Success!");
             if (success)
                 success();
         }];
    };
    
    [self.database fetchAllSubscriptionsWithCompletionHandler:^(NSArray *subscriptions, NSError *error) {
        if (subscriptions.count == 0)
            saveSubscriptionBlock();
        
        __block NSInteger subscriptionCount = subscriptions.count;
        for (CKSubscription *sub in subscriptions) {
            if ([sub.recordType isEqualToString:recordType]) {
                [self.database deleteSubscriptionWithID:sub.subscriptionID completionHandler:^(NSString *subscriptionID, NSError *error) {
                    if (--subscriptionCount == 0)
                        saveSubscriptionBlock();
                }];
            } else
                subscriptionCount--;
        }
    }];
}

- (void)setupLeaderboardNames:(NSArray *)leaderboardNames
{
    for (NSString *leaderboardName in leaderboardNames)
        [self setLeaderboard:[[LKArrayLeaderBoard alloc] init] forName:leaderboardName];
}

- (void)updateLeaderboard:(NSString *)leaderboardName
{
    NSString *recordType = [NSString stringWithFormat:@"LeaderboardKit_%@",leaderboardName];
    CKQuery *query = [[CKQuery alloc] initWithRecordType:recordType predicate:[NSPredicate predicateWithFormat:@"%K IN ",recordType]];
    query.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"score" ascending:NO]];
    [self.database performQuery:query inZoneWithID:nil completionHandler:^(NSArray *results, NSError *error) {
        NSMutableArray *scores = [NSMutableArray array];
        for (CKRecord *record in results) {
            LKBasicPlayer *player = [[LKBasicPlayer alloc] init];
            player.fullName = record[@"name"];
            LKPlayerScore *playerScore = [[LKPlayerScore alloc] init];
            playerScore.player = player;
            playerScore.score = record[@"score"];
            [scores addObject:playerScore];
        }
        LKArrayLeaderBoard *leaderboard = [self leaderboardForName:leaderboardName];
        [leaderboard setScores:scores];
    }];
}

- (void)updateLeaderboards
{
    for (NSString *leaderboardName in self.leaderboards.keyEnumerator)
        [self updateLeaderboard:leaderboardName];
}

- (void)updateScore:(NSNumber *)score forName:(NSString *)name
{
    NSString *score_key = [NSString stringWithFormat:@"score_%@",name];
    CKReference *scoreRef = self.userRecord[score_key];
    
    NSString *recordType = [NSString stringWithFormat:@"LeaderboardKit_%@",name];
    CKRecord *record = ^{
        if (scoreRef.recordID == nil)
            return [[CKRecord alloc] initWithRecordType:recordType];
        return [[CKRecord alloc] initWithRecordType:recordType recordID:scoreRef.recordID];
    }();
    
    id<LKAccount> account = self.accounts.allValues.firstObject;
    record[@"name"] = [[account localPlayer] fullName] ?: [[account localPlayer] screenName];
    record[@"prev_score"] = record[@"score"];
    record[@"score"] = score;
    
    [self.database saveRecord:record completionHandler:^(CKRecord *record, NSError *error) {
        if (error) {
            [self updateScore:score forName:name];
            return;
        }
        if (self.userRecord[score_key] == nil)
            self.userRecord[score_key] = [[CKReference alloc] initWithRecordID:record.recordID action:(CKReferenceActionNone)];
    }];
}

@end
