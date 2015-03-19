//
//  LKPlayer.h
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol LKPlayer <NSObject>

@property (nonatomic, readonly) NSString *account_id;
@property (nonatomic, readonly) NSString *fullName;
@property (nonatomic, readonly) NSString *screenName;
@property (nonatomic, readonly) NSString *accountType;

@end

//

@interface LKPlayerScore : NSObject

@property (nonatomic, strong) NSNumber *score;
@property (nonatomic, strong) id<LKPlayer> player;

@end

//

@interface LKBasicPlayer : NSObject <LKPlayer>

@property (nonatomic, strong) NSString *account_id;
@property (nonatomic, strong) NSString *fullName;
@property (nonatomic, strong) NSString *screenName;
@property (nonatomic, strong) NSString *accountType;

@end

//

@interface LKBlockPlayer : NSObject <LKPlayer>

- (instancetype)initWithAccountType:(NSString *)accountType
                          accountId:(NSString *(^)())accountIdBlock
                           fullName:(NSString *(^)())fullNameBlock
                         screenName:(NSString *(^)())screenNameBlock;

@end