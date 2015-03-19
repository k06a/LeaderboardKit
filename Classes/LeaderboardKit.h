//
//  ABLeaderboardKit.h
//  GameOfTwo
//
//  Created by Антон Буков on 17.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>
#import "LKAccount.h"
#import "LKGameCenterAccount.h"
#import "LKTwitterAccount.h"

@interface LeaderboardKit : NSObject

+ (instancetype)shared;

- (void)whenInitialized:(void(^)())block;
@property (nonatomic, readonly) BOOL isInitialized;
@property (nonatomic, strong) CKRecord *userRecord;

- (NSDictionary *)accounts;
- (id<LKAccount>)accountForIdentifier:(NSString *)identifier;
- (void)setAccount:(id<LKAccount>)account forIdentifier:(NSString *)identifier;

@end
