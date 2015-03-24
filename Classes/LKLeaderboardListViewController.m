//
//  LKLeaderboardsViewController.m
//  LeaderboardKit
//
//  Created by Anton Bukov on 24.03.15.
//  Copyright (c) 2015 Codeless Solutions. All rights reserved.
//

#import "LeaderboardKit.h"
#import "LKLeaderboardViewController.h"
#import "LKLeaderboardListViewController.h"

@implementation LKLeaderboardListViewController

#pragma mark - Table View

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [LeaderboardKit shared].commonLeaderboards.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell_leaderboard"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:(UITableViewCellStyleSubtitle) reuseIdentifier:@"cell_leaderboard"];
        cell.imageView.image = [[UIImage imageNamed:@"leaderboard"] imageWithRenderingMode:(UIImageRenderingModeAlwaysTemplate)];
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }
    
    NSArray *keys = [[LeaderboardKit shared].commonLeaderboards.allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSString *key = keys[indexPath.row];
    LKLeaderboard *leaderboard = [LeaderboardKit shared].commonLeaderboards[key];
    
    NSInteger myIndex = leaderboard.sortedScores ? [leaderboard.sortedScores indexOfObjectPassingTest:^BOOL(LKPlayerScore *ps, NSUInteger idx, BOOL *stop) {
        for (id<LKAccount> account in [LeaderboardKit shared].accounts) {
            if ([[account localPlayer].account_id isEqualToString:ps.player.account_id])
                return YES;
        }
        return [ps.player.recordID isEqual:[LeaderboardKit shared].userRecord.recordID];
    }] : NSNotFound;
    
    cell.textLabel.text = key;
    if (myIndex == NSNotFound)
        cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"LK_UI_UNRANKED", @""),@(leaderboard.sortedScores.count)];
    else
        cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"LK_UI_RANKED", @""),@(myIndex+1),@(leaderboard.sortedScores.count-1)];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *keys = [[LeaderboardKit shared].commonLeaderboards.allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSString *key = keys[indexPath.row];
    
    LKLeaderboardViewController *controller = [[LKLeaderboardViewController alloc] init];
    controller.leaderboardName = key;
    [self.navigationController pushViewController:controller animated:YES];
}

#pragma mark - View

- (void)cancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.title = NSLocalizedString(@"LK_UI_LEADERBOARDS_TITLE", @"");
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:(UIBarButtonSystemItemDone) target:self action:@selector(cancel:)];
    
    self.tableView.rowHeight = 60;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    
    [[LeaderboardKit shared] whenInitialized:^{
        [self.tableView reloadData];
    }];
    
    __weak typeof(self) weakSelf = self;
    [[NSNotificationCenter defaultCenter] addObserverForName:LKLeaderboardChangedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note)
    {
        [weakSelf.tableView reloadData];
    }];
}

@end
