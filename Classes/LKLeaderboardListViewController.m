//
//  LKLeaderboardsViewController.m
//  Pods
//
//  Created by Антон Буков on 22.03.15.
//
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
    
    NSInteger myIndex = [leaderboard.sortedScores indexOfObjectPassingTest:^BOOL(LKPlayerScore *ps, NSUInteger idx, BOOL *stop) {
        return [ps.player.recordId isEqual:[LeaderboardKit shared].userRecord.recordID];
    }];
    
    cell.textLabel.text = key;
    if (myIndex == NSNotFound)
        cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"LK_UI_UNRANKED", @""),@(leaderboard.sortedScores.count)];
    else
        cell.detailTextLabel.text = [NSString stringWithFormat:NSLocalizedString(@"LK_UI_RANKED", @""),@(myIndex+1),@(leaderboard.sortedScores.count)];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *keys = [[LeaderboardKit shared].commonLeaderboards.allKeys sortedArrayUsingSelector:@selector(compare:)];
    NSString *key = keys[indexPath.row];
    LKLeaderboard *leaderboard = [LeaderboardKit shared].commonLeaderboards[key];
    
    LKLeaderboardViewController *controller = [[LKLeaderboardViewController alloc] init];
    controller.leaderboard = leaderboard;
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
}

@end
