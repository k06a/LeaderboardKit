//
//  ABLeaderboardKit.m
//  GameOfTwo
//
//  Created by Антон Буков on 17.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <Social/Social.h>
#import <Accounts/Accounts.h>
#import <CloudKit/CloudKit.h>
#import "LeaderboardKit.h"

@interface LeaderboardKit ()

@property (nonatomic, strong) NSMutableDictionary *accounts;
@property (nonatomic, strong) NSMutableArray *whenInitializedBlocks;

@property (nonatomic, strong) CKContainer *container;
@property (nonatomic, strong) CKDatabase *database;
@property (nonatomic, strong) CKRecordID *userID;

@end

@implementation LeaderboardKit

+ (instancetype)shared
{
    if ([UIDevice currentDevice].systemVersion.doubleValue < 8.0)
        return nil;
    
    static LeaderboardKit *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[LeaderboardKit alloc] init];
        shared.whenInitializedBlocks = [NSMutableArray array];
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
            
            if ([_userRecord[@"twitter_id"] longLongValue]) {
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

/*
- (void)subscribeToLeaderboard:(NSString *)leaderboardName
                     withScore:(NSNumber *)myScore
                       success:(void(^)())success
                       failure:(void(^)(NSError *))failure
{
    NSArray *twitter_ids = self.userRecord[@"twitter_friend_ids"];
    if (twitter_ids.count) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(score > %@) AND (prev_score < %@) AND (twitter_id IN %@)", myScore, myScore, twitter_ids];
        NSLog(@"myScore = %@, ids = %@ .. %@", myScore, twitter_ids.firstObject, twitter_ids.lastObject);
        
        CKNotificationInfo *notificationInfo = [CKNotificationInfo new];
        notificationInfo.alertLocalizationKey = [NSString stringWithFormat:@"TWITTER_NOTE_%@",leaderboardName];
        notificationInfo.alertLocalizationArgs = @[@"full_name",@"score"];
        notificationInfo.soundName = @"Party.aiff";
        notificationInfo.shouldBadge = YES;
        
        CKSubscription *subs = [[CKSubscription alloc] initWithRecordType:[NSString stringWithFormat:@"Highscore_%@",leaderboardName] predicate:predicate options:(CKSubscriptionOptionsFiresOnRecordCreation)];
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
                [self.database deleteSubscriptionWithID:sub.subscriptionID completionHandler:^(NSString *subscriptionID, NSError *error) {
                    if (--subscriptionCount == 0)
                        saveSubscriptionBlock();
                }];
            }
        }];
    }
    
}*/

@end
