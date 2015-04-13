//
//  LKGameCenterAccount.m
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <GameKit/GameKit.h>
#import <SAMCache/SAMCache.h>
#import "LeaderboardKit.h"
#import "LKGameCenter.h"

NSString *(^LKGameCenterIdentifierToNameTranform)(NSString *) = ^NSString *(NSString *identifier){
    return identifier;
};
NSString *(^LKGameCenterNameToIdentifierTranform)(NSString *) = ^NSString *(NSString *name){
    return name;
};

@interface LKGameCenter ()

@property (nonatomic, strong) LKPlayer *localPlayer;
@property (nonatomic, strong) NSArray *friend_ids;
@property (nonatomic, strong) NSMutableDictionary *leaderboards;

@property (nonatomic, strong) GKLocalPlayer *account;

@end

@implementation LKGameCenter

- (NSMutableDictionary *)leaderboards
{
    if (_leaderboards == nil)
        _leaderboards = [NSMutableDictionary dictionary];
    return _leaderboards;
}

- (void)setAccount:(GKLocalPlayer *)account
{
    _account = account;
    self.localPlayer = ^{
        LKPlayer *p = [[LKPlayer alloc] init];
        p.account_id = account.playerID;
        p.fullName = account.displayName;
        p.screenName = account.alias;
        p.recordID = [LeaderboardKit shared].userRecord.recordID;
        p.accountType = [[self class] description];
        return p;
    }();
    
    if (self.account.playerID == nil)
        return;
    
    if (![[LeaderboardKit shared].userRecord[@"LKGameCenter_id"] isEqualToString:self.localPlayer.account_id])
        [LeaderboardKit shared].userRecord[@"LKGameCenter_id"] = self.localPlayer.account_id;
    if (![[LeaderboardKit shared].userRecord[@"LKGameCenter_full_name"] isEqualToString:self.localPlayer.fullName])
        [LeaderboardKit shared].userRecord[@"LKGameCenter_full_name"] = self.localPlayer.fullName;
    if (![[LeaderboardKit shared].userRecord[@"LKGameCenter_screen_name"] isEqualToString:self.localPlayer.screenName])
        [LeaderboardKit shared].userRecord[@"LKGameCenter_screen_name"] = self.localPlayer.screenName;
}

- (BOOL)isAuthorized
{
    return (self.account != nil) && self.account.isAuthenticated;
}

- (instancetype)init
{
    if (self = [super init]) {
        self.friend_ids = [LeaderboardKit shared].userRecord[@"LKGameCenter_friend_ids"];
        [self requestFriendsSuccess:nil failure:nil];
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
        
        if (!weakSelf.account.isAuthenticated) {
            NSLog(@"GameCenter user auth error: %@", error);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (failure)
                    failure(error);
            });
            return;
        }
        
        weakSelf.account = weakSelf.account;
        [weakSelf requestFriendsSuccess:nil failure:nil];
        [weakSelf requestLeaderboardsSuccess:nil failure:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success)
                success(error);
        });
    };
}

- (void)requestFriendsSuccess:(void(^)())success
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
        
        self.friend_ids = ids;
        [LeaderboardKit shared].userRecord[@"LKGameCenter_friend_ids"] = ids;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success)
                success();
        });
    }];
}

- (void)requestLeaderboardsSuccess:(void(^)())success
                           failure:(void(^)(NSError *error))failure
{
    [GKLeaderboard loadLeaderboardsWithCompletionHandler:^(NSArray *leaderboards, NSError *error)
    {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (failure)
                    failure(error);
            });
            return;
        }
        
        __block NSInteger count = leaderboards.count;
        __block NSError *anyError = nil;
        
        void(^completionBlock)(NSError *) = ^(NSError *err){
            if (err)
                anyError = err;
            
            if (--count == 0) {
                if (anyError) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (failure)
                            failure(anyError);
                    });
                    return;
                }
                
                [[LeaderboardKit shared] calculateCommonLeaderboard];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (success)
                        success();
                });
            }
        };
        
        for (GKLeaderboard *leaderboard in leaderboards) {
            [leaderboard loadScoresWithCompletionHandler:^(NSArray *leaderboardScores, NSError *error)
            {
                if (error) {
                    completionBlock(error);
                    return;
                }
                
                NSMutableArray *scores = [NSMutableArray array];
                for (GKScore *score in leaderboard.scores) {
                    LKPlayerScore *ps = [[LKPlayerScore alloc] init];
                    ps.score = @(score.value);
                    ps.player = [[LKPlayer alloc] init];
                    ps.player.account_id = score.player.playerID;
                    ps.player.fullName = score.player.displayName;
                    ps.player.screenName = score.player.alias;
                    ps.player.accountType = [[self class] description];
                    [scores addObject:ps];
                }
                LKLeaderboard *lb = [[LKLeaderboard alloc] init];
                [lb setScores:scores];
                self.leaderboards[LKGameCenterIdentifierToNameTranform(leaderboard.identifier)] = lb;
                completionBlock(nil);
            }];
        }
    }];
}

- (void)reportScore:(NSNumber *)scoreValue forName:(NSString *)name
{
    NSString *identifier = LKGameCenterNameToIdentifierTranform(name);
    GKScore *score = [[GKScore alloc] initWithLeaderboardIdentifier:identifier];

    score.value = scoreValue.longLongValue;
    [GKScore reportScores:@[score] withCompletionHandler:^(NSError *error) {
        if (error) {
            NSLog(@"GameCenter score report error: %@", error);
            return;
        }
        NSLog(@"GameCenter score report success");
    }];
    
    LKLeaderboard *leaderboard = self.leaderboards[name];
    LKPlayerScore *ps = [leaderboard findScoreWithAccountId:self.localPlayer.account_id];
    ps.score = scoreValue;
    [leaderboard setScores:leaderboard.sortedScores];
}

- (UIImage *)cachedPhotoForAccountId:(NSString *)account_id
{
    NSString *key = [NSString stringWithFormat:@"LKGameCenter_%@",account_id];
    return [[SAMCache sharedCache] imageForKey:key];
}

- (void)requestPhotoForAccountId:(NSString *)account_id
                         success:(void(^)(UIImage *image))success
                         failure:(void(^)(NSError *error))failure
{
    [GKPlayer loadPlayersForIdentifiers:@[account_id] withCompletionHandler:^(NSArray *players, NSError *error) {
        GKPlayer *player = players.firstObject;
        [player loadPhotoForSize:(GKPhotoSizeNormal) withCompletionHandler:^(UIImage *photo, NSError *error) {
            if (photo) { // it can be non-nil and error if cached by GameKit
                NSString *key = [NSString stringWithFormat:@"LKGameCenter_%@",account_id];
                [[SAMCache sharedCache] setImage:photo forKey:key];
                if (success)
                    success(photo);
                return;
            }
            
            if (failure)
                failure(error);
        }];
    }];
}

@end
