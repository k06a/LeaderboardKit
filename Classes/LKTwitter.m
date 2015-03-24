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
        p.account_id = [[account valueForKey:@"properties"] valueForKey:@"user_id"];
        p.fullName = account.userFullName;
        p.screenName = account.username;
        p.recordID = [LeaderboardKit shared].userRecord.recordID;
        p.accountType = [[self class] description];
        return p;
    }();
    
    [LeaderboardKit shared].userRecord[@"LKTwitter_id"] = self.localPlayer.account_id;
    [LeaderboardKit shared].userRecord[@"LKTwitter_full_name"] = self.localPlayer.fullName;
    [LeaderboardKit shared].userRecord[@"LKTwitter_screen_name"] = self.localPlayer.screenName;
}

- (BOOL)isAuthorized
{
    return (self.account != nil);
}

- (instancetype)init
{
    if (self = [super init]) {
        int64_t account_id = [[LeaderboardKit shared].userRecord[@"LKTwitter_id"] longLongValue];
        for (ACAccount *account in [self.accountStore accountsWithAccountType:self.accountType]) {
            if (account_id == [[[account valueForKey:@"properties"] valueForKey:@"user_id"] longLongValue])
                self.account = account;
        }
        self.friend_ids = [LeaderboardKit shared].userRecord[@"LKTwitter_friend_ids"];
        [self requestFriendsSuccess:nil failure:nil];
    }
    return self;
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
    
    NSInteger accountIndex = buttonIndex - actionSheet.firstOtherButtonIndex;
    self.account = [self.accountStore accountsWithAccountType:self.accountType][accountIndex];
    [self requestFriendsSuccess:nil failure:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.authSuccess)
            self.authSuccess();
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
    return [[SAMCache sharedCache] imageForKey:account_id];
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
        if (err || json == nil) {
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
            [[SAMCache sharedCache] setImage:image forKey:account_id];
            if (success)
                success(image);
        }];
    }];
}

@end
