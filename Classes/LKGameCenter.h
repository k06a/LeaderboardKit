//
//  LKGameCenterAccount.h
//  LeaderboardKit
//
//  Created by Anton Bukov on 19.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LKAccount.h"

extern NSString *(^LKGameCenterIdentifierToNameTranform)(NSString *);
extern NSString *(^LKGameCenterNameToIdentifierTranform)(NSString *);

@interface LKGameCenter : NSObject <LKAccountWithLeaderboards>

@end
