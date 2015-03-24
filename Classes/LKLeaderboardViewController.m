//
//  LKLeaderboardViewController.m
//  Pods
//
//  Created by Антон Буков on 24.03.15.
//
//

#import "LeaderboardKit.h"
#import "LKLeaderboardViewController.h"

@interface LKLeaderboardViewController ()

@end

@implementation LKLeaderboardViewController

#pragma mark - Table View

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.leaderboard.sortedScores.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell_score"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:(UITableViewCellStyleSubtitle) reuseIdentifier:@"cell_score"];
        cell.imageView.image = [[UIImage imageNamed:@"profile"] imageWithRenderingMode:(UIImageRenderingModeAlwaysTemplate)];
        cell.imageView.tintColor = [UIColor grayColor];
        cell.detailTextLabel.textColor = [UIColor grayColor];
    }
    
    LKPlayerScore *score = self.leaderboard.sortedScores[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@",score.player.fullName];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@",score.score];
    
    return cell;
}

#pragma mark - View

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = self.leaderboardName;
    
    self.tableView.rowHeight = 60;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

@end
