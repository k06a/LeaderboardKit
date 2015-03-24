//
//  LKLeaderboardViewController.m
//  LeaderboardKit
//
//  Created by Anton Bukov on 24.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import "LeaderboardKit.h"
#import "LKScoreTableViewCell.h"
#import "LKLeaderboardViewController.h"

@interface LKLeaderboardViewController ()

@property (nonatomic, readonly) LKLeaderboard *leaderboard;

@end

@implementation LKLeaderboardViewController

- (LKLeaderboard *)leaderboard
{
    return [LeaderboardKit shared].commonLeaderboards[self.leaderboardName];
}

#pragma mark - Table View

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.leaderboard.sortedScores.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    LKScoreTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell_score"];
    if (cell == nil) {
        cell = [[LKScoreTableViewCell alloc] initWithStyle:(UITableViewCellStyleSubtitle) reuseIdentifier:@"cell_score"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.imageView.image = [[UIImage imageNamed:@"profile"] imageWithRenderingMode:(UIImageRenderingModeAlwaysTemplate)];
        cell.imageView.tintColor = [UIColor grayColor];
        cell.detailTextLabel.textColor = [UIColor grayColor];
        cell.indentationLevel = 1;
        cell.indentationWidth = 40;
    }
    
    LKPlayerScore *score = self.leaderboard.sortedScores[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@",score.player.fullName];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@",score.score];
    cell.rankLabel.text = [NSString stringWithFormat:@"%@",@(indexPath.row + 1)];
    
    BOOL isMe = ^{
        for (id<LKAccount> account in [LeaderboardKit shared].accounts) {
            if ([[account localPlayer].account_id isEqualToString:score.player.account_id])
                return YES;
        }
        return NO;
    }();
    cell.textLabel.textColor = isMe ? self.view.tintColor : [UIColor blackColor];
    cell.rankLabel.textColor = isMe ? self.view.tintColor : [UIColor blackColor];
    
    return cell;
}

#pragma mark - View

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = self.leaderboardName;
    
    self.tableView.rowHeight = 60;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    __weak typeof(self) weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:LKLeaderboardChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note)
    {
        if ([weakSelf.leaderboardName isEqualToString:note.object])
            [weakSelf.tableView reloadData];
    }];
}

@end
