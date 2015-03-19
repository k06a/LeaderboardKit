//
//  LKGameCenterAccount.m
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <GameKit/GameKit.h>
#import "LKGameCenterAccount.h"

NSString *LKAccountIdentifierGameCenter = @"LKAccountIdentifierGameCenter";

@interface LKGameCenterAccount ()

@property (nonatomic, strong) GKLocalPlayer *account;

@property (nonatomic, strong) CKRecord *userRecord;
@property (nonatomic, strong) NSArray *friend_ids;
@property (nonatomic, strong) LKBlockPlayer *localPlayer;
@property (nonatomic, strong) LKArrayLeaderBoard *leaderboard;

@end

@implementation LKGameCenterAccount

- (void)setAccount:(GKLocalPlayer *)account
{
    _account = account;
    self.userRecord[@"LKGameCenterAccount_id"] = self.localPlayer.account_id;
    self.userRecord[@"LKGameCenterAccount_full_name"] = self.localPlayer.fullName;
    self.userRecord[@"LKGameCenterAccount_screen_name"] = self.localPlayer.screenName;
}

- (BOOL)isAuthorized
{
    return (self.account != nil) && self.account.isAuthenticated;
}

- (LKBlockPlayer *)localPlayer
{
    if (_localPlayer == nil) {
        _localPlayer = [[LKBlockPlayer alloc] initWithAccountType:LKAccountIdentifierGameCenter accountId:^NSString *{
            return self.account.playerID;
        } fullName:^NSString *{
            return self.account.displayName;
        } screenName:^NSString *{
            return self.account.alias;
        }];
    }
    return _localPlayer;
}

- (LKArrayLeaderBoard *)leaderboard
{
    if (_leaderboard == nil) {
        _leaderboard = [[LKArrayLeaderBoard alloc] init];
    }
    return _leaderboard;
}

- (instancetype)init
{
    return nil;
}

- (instancetype)initWithUserRecord:(CKRecord *)userRecord
{
    if (self = [super init]) {
        self.userRecord = userRecord;
        self.friend_ids = self.userRecord[@"LKGameCenterAccount_friend_ids"];
        [self requestFriendIdsSuccess:nil failure:nil];
    }
    return self;
}

- (void)requestAuthWithViewController:(UIViewController *)controller
                              success:(void(^)())success
                              failure:(void(^)(NSError *error))failure
{
    self.account = [GKLocalPlayer localPlayer];
    __weak typeof(self) weakSelf = self;
    self.account.authenticateHandler = ^(UIViewController *viewController, NSError *error){
        if (viewController) {
            [controller presentViewController:viewController animated:YES completion:nil];
            return;
        }
        
        if (weakSelf.account.isAuthenticated) {
            if (![weakSelf.account.playerID isEqualToString:weakSelf.userRecord[@"LKGameCenterAccount_id"]]) {
                weakSelf.account = weakSelf.account;
                [weakSelf requestFriendIdsSuccess:nil failure:nil];
            }
            return;
        }
        
        weakSelf.account = nil;
    };
}

- (void)requestFriendIdsSuccess:(void(^)(NSArray *ids))success
                        failure:(void(^)(NSError *error))failure
{
    [self.account loadFriendPlayersWithCompletionHandler:^(NSArray *friendPlayers, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (failure)
                    failure(error);
            });
            return;
        }
        
        NSMutableArray *ids = [NSMutableArray array];
        for (GKPlayer *player in friendPlayers)
            [ids addObject:player.playerID];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success)
                success(ids);
            self.friend_ids = ids;
            self.userRecord[@"LKGameCenterAccount_friend_ids"] = ids;
        });
    }];
}

@end
