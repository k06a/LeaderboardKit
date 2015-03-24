//
//  LKPlayer.h
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CKRecordID;
@class CKRecord;

@interface LKPlayer : NSObject

@property (nonatomic, strong) NSString *account_id;
@property (nonatomic, strong) NSString *fullName;
@property (nonatomic, strong) NSString *screenName;
@property (nonatomic, strong) CKRecordID *recordID;
@property (nonatomic, strong) CKRecord *record;
@property (nonatomic, strong) NSString *accountType;

- (BOOL)isEqualToPlayer:(LKPlayer *)player;

@end

//

@interface LKPlayerScore : NSObject

@property (nonatomic, strong) NSNumber *score;
@property (nonatomic, strong) LKPlayer *player;

@end
