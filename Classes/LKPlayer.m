//
//  LKPlayer.m
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <CloudKit/CloudKit.h>
#import "LeaderboardKit.h"
#import "LKPlayer.h"

@implementation LKPlayer

- (BOOL)isLocalPlayer
{
    for (id<LKAccount> account in [LeaderboardKit shared].accounts)
        if ([[account localPlayer].account_id isEqualToString:[self idForAccountClass:[account class]]])
            return YES;
    return NO;
}

- (NSString *)idForAccountClass:(Class)accountClass
{
    NSString *key = [NSString stringWithFormat:@"%@_id", accountClass];
    if (self.record)
        return self.record[key];
    if ([self.accountType isEqualToString:[accountClass description]])
        return self.account_id;
    return nil;
}

- (UIImage *)cachedImage
{
    // To become LKGameCenter last in array :)
    NSArray *sortedAccounts = [[LeaderboardKit shared].accounts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id<LKAccount> acc, NSDictionary *bindings) {
        return ![acc isKindOfClass:[LKGameCenter class]];
    }]];
    sortedAccounts = [sortedAccounts arrayByAddingObject:[[LeaderboardKit shared] accountWithClass:[LKGameCenter class]]];
    
    for (id<LKAccount> account in sortedAccounts) {
        NSString *account_id = [self idForAccountClass:[account class]];
        if (account_id) {
            UIImage *photo = [account cachedPhotoForAccountId:account_id];
            if (photo)
                return photo;
        }
    }
    return nil;
}

- (void)requestPhoto:(void(^)(UIImage *))success
{
    // To become LKGameCenter last in array :)
    NSArray *sortedAccounts = [[LeaderboardKit shared].accounts filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id<LKAccount> acc, NSDictionary *bindings) {
        return ![acc isKindOfClass:[LKGameCenter class]];
    }]];
    sortedAccounts = [sortedAccounts arrayByAddingObject:[[LeaderboardKit shared] accountWithClass:[LKGameCenter class]]];
    
    for (id<LKAccount> account in sortedAccounts) {
        NSString *account_id = [self idForAccountClass:[account class]];
        if (account_id)
            [account requestPhotoForAccountId:account_id success:success failure:nil];
    }
}

- (NSString *)visibleName
{
    if (self.fullName.length > 0 && self.screenName.length > 0)
        return [NSString stringWithFormat:@"%@ (%@)", self.fullName, self.screenName];
    return (self.fullName.length > 0) ? self.fullName : self.screenName;
}

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
