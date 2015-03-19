//
//  LKTwitterSource.m
//  GameOfTwo
//
//  Created by Антон Буков on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <Social/Social.h>
#import "LKTwitterAccount.h"

NSString *LKAccountIdentifierTwitter = @"LKAccountIdentifierTwitter";

@interface LKTwitterAccount () <UIActionSheetDelegate>

@property (nonatomic, strong) ACAccountStore *accountStore;
@property (nonatomic, strong) ACAccountType *accountType;
@property (nonatomic, strong) ACAccount *account;
@property (nonatomic, strong) void(^authSuccess)();
@property (nonatomic, strong) void(^authFailure)(NSError *);

@end

@implementation LKTwitterAccount

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
    
    self.userRecord[@"twitter_id"] = self.account_id;
    self.userRecord[@"twitter_full_name"] = self.fullName;
    self.userRecord[@"twitter_screen_name"] = self.screenName;
}

- (BOOL)isAuthorized
{
    return (self.account != nil);
}

- (NSString *)account_id
{
    return [[self.account valueForKey:@"properties"] valueForKey:@"user_id"];
}

- (NSString *)fullName
{
    return self.account.userFullName;
}

- (NSString *)screenName
{
    return self.account.username;
}

- (instancetype)init
{
    return nil;
}

- (instancetype)initWithUserRecord:(CKRecord *)userRecord
{
    if (self = [super init]) {
        self.userRecord = userRecord;
        int64_t account_id = [userRecord[@"twitter_id"] longLongValue];
        for (ACAccount *account in [self.accountStore accountsWithAccountType:self.accountType]) {
            if (account_id == [[[account valueForKey:@"properties"] valueForKey:@"user_id"] longLongValue])
                self.account = account;
        }
        
        self.friend_ids = self.userRecord[@"twitter_friend_ids"];
        
        [self requestFriendIdsSuccess:nil failure:nil];
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
    [self requestFriendIdsSuccess:nil failure:nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.authSuccess)
            self.authSuccess();
    });
}

- (void)requestFriendIdsSuccess:(void(^)(NSArray *ids))success
                        failure:(void(^)(NSError *error))failure
{
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:[NSURL URLWithString:@"https://api.twitter.com/1.1/friends/ids.json?"] parameters:@{@"screen_name":self.account.username,@"cursor":@-1}];
    request.account = self.account;
    
    [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error)
    {
        if (error || responseData == nil) {
            NSLog(@"Error: %@", error.localizedDescription);
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
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success)
                success(ids);
            self.friend_ids = ids;
            self.userRecord[@"twitter_friend_ids"] = ids;
        });
    }];
}

@end
