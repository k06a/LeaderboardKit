//
//  LKFacebook.m
//  LeaderboardKit
//
//  Created by Anton Bukov on 12.04.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import <SAMCache/SAMCache.h>
#import "LeaderboardKit.h"
#import "LKFacebook.h"

@interface LKFacebook () <UIActionSheetDelegate>

@property (nonatomic, strong) ACAccountStore *accountStore;
@property (nonatomic, strong) ACAccountType *accountType;
@property (nonatomic, strong) ACAccount *account;
@property (nonatomic, strong) void(^authSuccess)();
@property (nonatomic, strong) void(^authFailure)(NSError *);

@property (nonatomic, strong) NSArray *friend_ids;
@property (nonatomic, strong) LKPlayer *localPlayer;
@property (nonatomic, strong) LKLeaderboard *leaderboard;

@end

@implementation LKFacebook

- (ACAccountStore *)accountStore
{
    if (_accountStore == nil)
        _accountStore = [[ACAccountStore alloc] init];
    return _accountStore;
}

- (ACAccountType *)accountType
{
    if (_accountType == nil)
        _accountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierFacebook];
    return _accountType;
}

- (void)setAccount:(ACAccount *)account
{
    _account = account;
    self.localPlayer = ^{
        LKPlayer *p = [[LKPlayer alloc] init];
        p.account_id = [[[account valueForKey:@"properties"] valueForKey:@"uid"] description];
        p.fullName = account.userFullName;
        p.screenName = account.username;
        p.recordID = [LeaderboardKit shared].userRecord.recordID;
        p.accountType = [[self class] description];
        return p;
    }();
    
    if (![[LeaderboardKit shared].userRecord[@"LKFacebook_id"] isEqualToString:self.localPlayer.account_id])
        [LeaderboardKit shared].userRecord[@"LKFacebook_id"] = self.localPlayer.account_id;
    if (![[LeaderboardKit shared].userRecord[@"LKFacebook_full_name"] isEqualToString:self.localPlayer.fullName])
        [LeaderboardKit shared].userRecord[@"LKFacebook_full_name"] = self.localPlayer.fullName;
    if (![[LeaderboardKit shared].userRecord[@"LKFacebook_screen_name"] isEqualToString:self.localPlayer.screenName])
        [LeaderboardKit shared].userRecord[@"LKFacebook_screen_name"] = self.localPlayer.screenName;
}

- (BOOL)isAuthorized
{
    return (self.account != nil);
}

- (instancetype)init
{
    if (self = [super init]) {
        NSString *account_id = [[LeaderboardKit shared].userRecord[@"LKFacebook_id"] description];
        for (ACAccount *account in [self.accountStore accountsWithAccountType:self.accountType]) {
            if ([account_id isEqualToString:[[[account valueForKey:@"properties"] valueForKey:@"uid"] description]])
                self.account = account;
        }
        self.friend_ids = [LeaderboardKit shared].userRecord[@"LKFacebook_friend_ids"];
    }
    return self;
}

- (void)requestAuthWithViewController:(UIViewController *)controller
                              success:(void(^)())success
                              failure:(void(^)(NSError *error))failure
{
    self.authSuccess = success;
    self.authFailure = failure;
    
    NSDictionary *options = @{
        // !!! Do not forget to add FacebookAppID to Info.plist !!!
        ACFacebookAppIdKey:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"FacebookAppID"],
        ACFacebookPermissionsKey:@[@"email",@"user_friends"]
    };
    
    [self.accountStore requestAccessToAccountsWithType:self.accountType options:options completion:^(BOOL granted, NSError *error)
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
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:@"https://graph.facebook.com/v1.0/me/friends"] parameters:@{@"limit":@500,@"fields":@"id"}];
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
         for (id friend in json[@"data"])
             [ids addObject:[friend[@"id"] description]];
         
         self.friend_ids = ids;
         [LeaderboardKit shared].userRecord[@"LKFacebook_friend_ids"] = ids;
         dispatch_async(dispatch_get_main_queue(), ^{
             if (success)
                 success();
         });
     }];
}

- (UIImage *)cachedPhotoForAccountId:(NSString *)account_id
{
    NSString *key = [NSString stringWithFormat:@"LKFacebook_%@",account_id];
    return [[SAMCache sharedCache] imageForKey:key];
}

- (void)requestPhotoForAccountId:(NSString *)account_id
                         success:(void(^)(UIImage *image))success
                         failure:(void(^)(NSError *error))failure
{
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/v1.0/%@/picture",account_id]] parameters:@{@"include_entities":@NO}];
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
         
         UIImage *image = [UIImage imageWithData:responseData];
         if (image == nil) {
             dispatch_async(dispatch_get_main_queue(), ^{
                 if (failure)
                     failure(nil);
             });
             return;
         }
         
         NSString *key = [NSString stringWithFormat:@"LKFacebook_%@",account_id];
         [[SAMCache sharedCache] setImage:image forKey:key];
         dispatch_async(dispatch_get_main_queue(), ^{
             if (success)
                 success(image);
         });
     }];
}

@end
