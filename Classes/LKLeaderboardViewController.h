//
//  LKLeaderboardViewController.h
//  Pods
//
//  Created by Антон Буков on 24.03.15.
//
//

#import <UIKit/UIKit.h>

@interface LKLeaderboardViewController : UITableViewController

@property (nonatomic, strong) LKLeaderboard *leaderboard;
@property (nonatomic, strong) NSString *leaderboardName;

@end
