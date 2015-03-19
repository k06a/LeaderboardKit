//
//  LKGameCenterAccount.m
//  GameOfTwo
//
//  Created by Антон Буков on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <GameKit/GameKit.h>
#import "LKGameCenterAccount.h"

NSString *LKAccountIdentifierGameCenter = @"LKAccountIdentifierGameCenter";

@interface LKGameCenterAccount ()

@property (nonatomic, strong) GKLocalPlayer *account;

@end

@implementation LKGameCenterAccount

- (void)setAccount:(GKLocalPlayer *)account
{
    _account = account;
    self.userRecord[@"gamecenter_id"] = self.account_id;
    self.userRecord[@"gamecenter_full_name"] = self.fullName;
    self.userRecord[@"gamecenter_screen_name"] = self.screenName;
}

- (BOOL)isAuthorized
{
    return (self.account != nil) && self.account.isAuthenticated;
}

- (NSString *)account_id
{
    return self.account.playerID;
}

- (NSString *)fullName
{
    return self.account.displayName;
}

- (NSString *)screenName
{
    return self.account.alias;
}

- (instancetype)init
{
    return nil;
}

- (instancetype)initWithUserRecord:(CKRecord *)userRecord
{
    if (self = [super init]) {
        self.userRecord = userRecord;
        
        self.friend_ids = self.userRecord[@"gamecenter_friend_ids"];
        
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
            if (![weakSelf.account.playerID isEqualToString:weakSelf.userRecord[@"gamecenter_id"]]) {
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
            self.userRecord[@"gamecenter_friend_ids"] = ids;
        });
    }];
}

@end
