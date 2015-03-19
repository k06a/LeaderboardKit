//
//  LKPlayer.m
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import "LKPlayer.h"

@implementation LKPlayerScore

@end

//

@implementation LKBasicPlayer

@end

//

@interface LKBlockPlayer ()

@property (nonatomic, strong) NSString *accountType;
@property (nonatomic, strong) NSString *(^accountIdBlock)();
@property (nonatomic, strong) NSString *(^fullNameBlock)();
@property (nonatomic, strong) NSString *(^screenNameBlock)();

@end

@implementation LKBlockPlayer

- (instancetype)initWithAccountType:(NSString *)accountType
                          accountId:(NSString *(^)())accountIdBlock
                           fullName:(NSString *(^)())fullNameBlock
                         screenName:(NSString *(^)())screenNameBlock
{
    if (self = [super init]) {
        self.accountType = accountType;
        self.accountIdBlock = accountIdBlock;
        self.fullNameBlock = fullNameBlock;
        self.screenNameBlock = screenNameBlock;
    }
    return self;
}

- (NSString *)account_id
{
    return self.accountIdBlock ? self.accountIdBlock() : nil;
}

- (NSString *)fullName
{
    return self.fullNameBlock ? self.fullNameBlock() : nil;
}

- (NSString *)screenName
{
    return self.screenNameBlock ? self.screenNameBlock() : nil;
}

@end
