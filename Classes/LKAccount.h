//
//  LKAccount.h
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol LKAccount <NSObject>

@property (nonatomic, readonly) BOOL isAuthorized;
@property (nonatomic, readonly) LKPlayer *localPlayer;
@property (nonatomic, readonly) NSArray *friend_ids;

- (void)requestAuthWithViewController:(UIViewController *)controller
                              success:(void(^)())success
                              failure:(void(^)(NSError *error))failure;

- (void)requestFriendsSuccess:(void(^)())success
                      failure:(void(^)(NSError *error))failure;

@end

//

@protocol LKAccountWithLeaderboards <LKAccount>

@property (nonatomic, readonly) NSDictionary *leaderboards;

- (void)requestLeaderboardsSuccess:(void(^)())success
                           failure:(void(^)(NSError *error))failure;

- (void)reportScore:(NSNumber *)score forName:(NSString *)name;

@end
