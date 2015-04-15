//
//  LKTwitterAccount.m
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import <SAMCache/SAMCache.h>
#import "LeaderboardKit.h"
#import "LKTwitter.h"

@interface LKTwitter () <UIActionSheetDelegate>

@property (nonatomic, strong) ACAccountStore *accountStore;
@property (nonatomic, strong) ACAccountType *accountType;
@property (nonatomic, strong) ACAccount *account;
@property (nonatomic, strong) void(^authSuccess)();
@property (nonatomic, strong) void(^authFailure)(NSError *);

@property (nonatomic, strong) NSArray *friend_ids;
@property (nonatomic, strong) LKPlayer *localPlayer;
@property (nonatomic, strong) LKLeaderboard *leaderboard;

@end

@implementation LKTwitter

- (ACAccountStore *)accountStore
{
    if (_accountStore == nil)
        _accountStore = [[ACAccountStore alloc] init];
    return _accountStore;
}

- (ACAccountType *)accountType
{
    if (_accountType == nil)
        _accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    return _accountType;
}

- (void)setAccount:(ACAccount *)account
{
    _account = account;
    self.localPlayer = ^{
        LKPlayer *p = [[LKPlayer alloc] init];
        p.account_id = [[[account valueForKey:@"properties"] valueForKey:@"user_id"] description];
        p.fullName = account.userFullName;
        p.screenName = [@"@" stringByAppendingString:account.username];
        p.recordID = [LeaderboardKit shared].userRecord.recordID;
        p.accountType = [[self class] description];
        return p;
    }();
    
    if (![[LeaderboardKit shared].userRecord[@"LKTwitter_id"] isEqualToString:self.localPlayer.account_id])
        [LeaderboardKit shared].userRecord[@"LKTwitter_id"] = self.localPlayer.account_id;
    if (![[LeaderboardKit shared].userRecord[@"LKTwitter_full_name"] isEqualToString:self.localPlayer.fullName])
        [LeaderboardKit shared].userRecord[@"LKTwitter_full_name"] = self.localPlayer.fullName;
    if (![[LeaderboardKit shared].userRecord[@"LKTwitter_screen_name"] isEqualToString:self.localPlayer.screenName])
        [LeaderboardKit shared].userRecord[@"LKTwitter_screen_name"] = self.localPlayer.screenName;
}

- (BOOL)isAuthorized
{
    return (self.account != nil);
}

- (instancetype)init
{
    if (self = [super init]) {
        NSString *account_id = [[LeaderboardKit shared].userRecord[@"LKTwitter_id"] description];
        for (ACAccount *account in [self.accountStore accountsWithAccountType:self.accountType]) {
            if ([account_id isEqualToString:[[[account valueForKey:@"properties"] valueForKey:@"user_id"] description]])
                self.account = account;
        }
        self.friend_ids = [LeaderboardKit shared].userRecord[@"LKTwitter_friend_ids"];
    }
    return self;
}

- (void)logoutAccount
{
    [LeaderboardKit shared].userRecord[@"LKTwitter_id"] = nil;
    [LeaderboardKit shared].userRecord[@"LKTwitter_friend_ids"] = nil;
    [LeaderboardKit shared].userRecord[@"LKTwitter_full_name"] = nil;
    [LeaderboardKit shared].userRecord[@"LKTwitter_screen_name"] = nil;
    [[LeaderboardKit shared] removeAccount:self];
}

- (void)requestAuthWithViewController:(UIViewController *)controller
                              success:(void(^)())success
                              failure:(void(^)(NSError *error))failure
{
    self.authSuccess = success;
    self.authFailure = failure;
    
    [self.accountStore requestAccessToAccountsWithType:self.accountType options:nil completion:^(BOOL granted, NSError *error)
     {
         if (!granted || error) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (failure)
                     failure(error);
             });
             return;
         }
         
         dispatch_async(dispatch_get_main_queue(), ^{
             UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Select account" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:nil];
             for (ACAccount *account in [self.accountStore accountsWithAccountType:self.accountType]) {
                 NSString *title = [NSString stringWithFormat:@"@%@", account.username];
                 [actionSheet addButtonWithTitle:title];
             }
             [actionSheet showInView:controller.view];
         });
     }];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.authFailure)
                self.authFailure(nil);
        });
        return;
    }
    
    NSInteger accountIndex = buttonIndex - 1;
    self.account = [self.accountStore accountsWithAccountType:self.accountType][accountIndex];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self requestFriendsSuccess:self.authSuccess failure:self.authFailure];
    });
}

- (void)requestFriendsSuccess:(void(^)())success
                      failure:(void(^)(NSError *error))failure
{
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:@"https://api.twitter.com/1.1/friends/ids.json?"] parameters:@{@"screen_name":self.account.username,@"cursor":@-1}];
    request.account = self.account;
    
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error)
    {
        if (error || responseData == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (failure)
                    failure(error);
            });
            return;
        }
        
        NSError *err = nil;
        id json = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&err];
        if (err || json == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (failure)
                    failure(err);
            });
            return;
        }
        
        NSMutableArray *ids = [NSMutableArray array];
        for (NSNumber *id in json[@"ids"])
            [ids addObject:id.stringValue];
        
        self.friend_ids = ids;
        [LeaderboardKit shared].userRecord[@"LKTwitter_friend_ids"] = ids;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success)
                success();
        });
    }];
}

- (UIImage *)cachedPhotoForAccountId:(NSString *)account_id
{
    NSString *key = [NSString stringWithFormat:@"LKTwitter_%@",account_id];
    return [[SAMCache sharedCache] imageForKey:key];
}

- (void)requestPhotoForAccountId:(NSString *)account_id
                         success:(void(^)(UIImage *image))success
                         failure:(void(^)(NSError *error))failure
{
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:@"https://api.twitter.com/1.1/users/lookup.json?"] parameters:@{@"user_id":account_id,@"include_entities":@NO}];
    request.account = self.account;
    
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error)
    {
        if (error || responseData == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (failure)
                    failure(error);
            });
            return;
        }
        
        NSError *err = nil;
        id json = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:&err];
        if (err || json == nil || ![json isKindOfClass:[NSDictionary class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (failure)
                    failure(err);
            });
            return;
        }

        NSString *photoUrl = json[@"profile_image_url"];
        [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:photoUrl]] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError)
        {
            if (connectionError) {
                if (failure)
                    failure(connectionError);
                return;
            }
            UIImage *image = [UIImage imageWithData:data];
            NSString *key = [NSString stringWithFormat:@"LKTwitter_%@",account_id];
            [[SAMCache sharedCache] setImage:image forKey:key];
            if (success)
                success(image);
        }];
    }];
}

@end
