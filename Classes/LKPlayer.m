//
//  LKPlayer.m
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <CloudKit/CloudKit.h>
#import "LKPlayer.h"

@implementation LKPlayer

- (BOOL)isEqualToPlayer:(LKPlayer *)player
{
    return [self.recordId isEqual:[player recordId]]
        || [self.account_id isEqual:[player account_id]];
}

- (BOOL)isEqual:(id)object
{
    return [self isEqualToPlayer:object];
}

@end

//

@implementation LKPlayerScore

@end
