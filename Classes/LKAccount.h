//
//  LKSource.h
//  GameOfTwo
//
//  Created by Антон Буков on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <CloudKit/CloudKit.h>
#import <Foundation/Foundation.h>

@protocol LKAccount <NSObject>

@property (nonatomic, readonly) BOOL isAuthorized;

@property (nonatomic, strong) CKRecord *userRecord;
@property (nonatomic, strong) NSString *account_id;
@property (nonatomic, strong) NSString *fullName;
@property (nonatomic, strong) NSString *screenName;
@property (nonatomic, strong) NSArray *friend_ids;

- (instancetype)init __attribute__ ((deprecated));
- (instancetype)initWithUserRecord:(CKRecord *)userRecord;

- (void)requestAuthWithViewController:(UIViewController *)controller
                              success:(void(^)())success
                              failure:(void(^)(NSError *error))failure;

- (void)requestFriendIdsSuccess:(void(^)(NSArray *ids))success
                        failure:(void(^)(NSError *error))failure;

@end