//
//  LKAccount.h
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <CloudKit/CloudKit.h>
#import <Foundation/Foundation.h>
#import "LKLeaderboard.h"

@protocol LKAccount <NSObject>

@property (nonatomic, readonly) BOOL isAuthorized;
@property (nonatomic, readonly) CKRecord *userRecord;
@property (nonatomic, readonly) NSArray *friend_ids;
@property (nonatomic, readonly) id<LKPlayer> localPlayer;

- (instancetype)init __attribute__ ((deprecated));
- (instancetype)initWithUserRecord:(CKRecord *)userRecord;

- (void)requestAuthWithViewController:(UIViewController *)controller
                              success:(void(^)())success
                              failure:(void(^)(NSError *error))failure;

- (void)requestFriendIdsSuccess:(void(^)(NSArray *ids))success
                        failure:(void(^)(NSError *error))failure;

@end
