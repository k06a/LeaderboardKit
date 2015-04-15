//
//  LKVKontakte.m
//  LeaderboardKit
//
//  Created by Anton Bukov on 13.04.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <VK-ios-sdk/VKSdk.h>
#import <SAMCache/SAMCache.h>
#import "LeaderboardKit.h"
#import "LKVKontakte.h"

@interface LKVKontakte () <VKSdkDelegate>

@property (nonatomic, strong) VKAccessToken *account;
@property (nonatomic, strong) void(^authSuccess)();
@property (nonatomic, strong) void(^authFailure)(NSError *);

@property (nonatomic, strong) NSArray *friend_ids;
@property (nonatomic, strong) LKPlayer *localPlayer;
@property (nonatomic, strong) LKLeaderboard *leaderboard;

@end

@implementation LKVKontakte

- (void)setAccount:(VKAccessToken *)account
{
    _account = account;
    
    VKRequest *request = [[VKApi users] get:@{VK_API_USER_IDS:@[account.userId],VK_API_FIELDS:@[@"first_name",@"last_name",@"nickname"]}];
    
    [request executeWithResultBlock:^(VKResponse *response) {
        self.localPlayer = ^{
            LKPlayer *p = [[LKPlayer alloc] init];
            p.account_id = account.userId;
            p.fullName = [NSString stringWithFormat:@"%@ %@",
                          response.json[0][@"first_name"],
                          response.json[0][@"last_name"]];
            p.screenName = response.json[0][@"nickname"];
            p.recordID = [LeaderboardKit shared].userRecord.recordID;
            p.accountType = [[self class] description];
            return p;
        }();
        
        if (![[LeaderboardKit shared].userRecord[@"LKVKontakte_id"] isEqualToString:self.localPlayer.account_id])
            [LeaderboardKit shared].userRecord[@"LKVKontakte_id"] = self.localPlayer.account_id;
        if (![[LeaderboardKit shared].userRecord[@"LKVKontakte_full_name"] isEqualToString:self.localPlayer.fullName])
            [LeaderboardKit shared].userRecord[@"LKVKontakte_full_name"] = self.localPlayer.fullName;
        if (![[LeaderboardKit shared].userRecord[@"LKVKontakte_screen_name"] isEqualToString:self.localPlayer.screenName])
            [LeaderboardKit shared].userRecord[@"LKVKontakte_screen_name"] = self.localPlayer.screenName;
    } errorBlock:^(NSError *error) {
        NSLog(@"VK setAccount Error: %@", error);
        [self setAccount:account];
    }];
}

- (BOOL)isAuthorized
{
    return (self.account != nil);
}

- (instancetype)init
{
    if (self = [super init]) {
        // !!! Do not forget to add VKontakteAppID to Info.plist !!!
        [VKSdk initializeWithDelegate:self andAppId:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"VKontakteAppID"]];
        if ([VKSdk wakeUpSession]) {
            self.account = [VKSdk getAccessToken];
            [self requestFriendsSuccess:self.authSuccess failure:self.authFailure];
        }
        self.friend_ids = [LeaderboardKit shared].userRecord[@"LKVKontakte_friend_ids"];
    }
    return self;
}

- (void)vkSdkReceivedNewToken:(VKAccessToken *)newToken
{
    [self requestFriendsSuccess:self.authSuccess failure:self.authFailure];
}

- (void)vkSdkUserDeniedAccess:(VKError *)authorizationError
{
    if (self.authFailure)
        self.authFailure((id)authorizationError);
}

-(void)vkSdkNeedCaptchaEnter:(VKError *)captchaError
{
    VKCaptchaViewController *vc = [VKCaptchaViewController captchaControllerWithError:captchaError];
    [vc presentIn:[UIApplication sharedApplication].keyWindow.rootViewController];
}

- (void)logoutAccount
{
    [VKSdk forceLogout];
    [LeaderboardKit shared].userRecord[@"LKVKontakte_id"] = nil;
    [LeaderboardKit shared].userRecord[@"LKVKontakte_friend_ids"] = nil;
    [LeaderboardKit shared].userRecord[@"LKVKontakte_full_name"] = nil;
    [LeaderboardKit shared].userRecord[@"LKVKontakte_screen_name"] = nil;
    [[LeaderboardKit shared] removeAccount:self];
}

- (void)requestAuthWithViewController:(UIViewController *)controller
                              success:(void(^)())success
                              failure:(void(^)(NSError *error))failure
{
    self.authSuccess = success;
    self.authFailure = failure;
    
    if ([VKSdk wakeUpSession]) {
        [self requestFriendsSuccess:self.authSuccess failure:self.authFailure];
    } else {
        [VKSdk authorize:@[VK_PER_FRIENDS] revokeAccess:YES];
    }
}

- (void)requestFriendsSuccess:(void(^)())success
                      failure:(void(^)(NSError *error))failure
{
    VKRequest *request = [VKRequest requestWithMethod:@"friends.get" andParameters:nil andHttpMethod:@"GET"];
    [request executeWithResultBlock:^(VKResponse *response) {
        NSMutableArray *ids = [NSMutableArray array];
        for (id friend in response.json[@"items"])
            [ids addObject:[friend description]];
        self.friend_ids = ids;
        [LeaderboardKit shared].userRecord[@"LKVKontakte_friend_ids"] = ids;
        if (success)
            success();
    } errorBlock:^(NSError *error) {
        if (failure)
            failure(error);
    }];
}

- (UIImage *)cachedPhotoForAccountId:(NSString *)account_id
{
    NSString *key = [NSString stringWithFormat:@"LKVKontakte_%@",account_id];
    return [[SAMCache sharedCache] imageForKey:key];
}

- (void)requestPhotoForAccountId:(NSString *)account_id
                         success:(void(^)(UIImage *image))success
                         failure:(void(^)(NSError *error))failure
{
    VKRequest *request = [VKRequest requestWithMethod:@"users.get" andParameters:@{@"user_ids":account_id,@"fields":@"photo_100"} andHttpMethod:@"GET"];
    [request executeWithResultBlock:^(VKResponse *response) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:response.json[0][@"photo_100"]]];
            UIImage *image = [UIImage imageWithData:data];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString *key = [NSString stringWithFormat:@"LKVKontakte_%@",account_id];
                [[SAMCache sharedCache] setImage:image forKey:key];
            });
        });
    } errorBlock:^(NSError *error) {
        if (failure)
            failure(error);
    }];
    
    /*
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeFacebook requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:[NSString stringWithFormat:@"https://graph.facebook.com/v1.0/%@/picture",account_id]] parameters:@{@"include_entities":@NO}];
    //request.account = self.account;
    
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
         
         NSString *key = [NSString stringWithFormat:@"LKVKontakte_%@",account_id];
         [[SAMCache sharedCache] setImage:image forKey:key];
         dispatch_async(dispatch_get_main_queue(), ^{
             if (success)
                 success(image);
         });
     }];*/
}

@end
