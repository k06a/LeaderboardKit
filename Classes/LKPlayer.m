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
    return [self.recordID isEqual:[player recordID]]
        || [self.account_id isEqual:[player account_id]];
}

- (BOOL)isEqual:(id)object
{
    return [self isEqualToPlayer:object];
}

@end

//

@implementation LKPlayerScore

- (BOOL)isEqual:(id)object
{
    return [self.player isEqual:[object player]]
        && [self.score isEqual:[object score]];
}

@end
